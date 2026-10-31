package com.example.hiz_olcer

import android.app.Activity
import android.content.Intent
import android.media.Image
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

private const val CHANNEL_NAME = "hiz_olcer/local_video"
private const val PICK_VIDEO_REQUEST = 7301
private const val MAX_FRAME_DIMENSION = 640

class MainActivity : FlutterActivity() {
    private lateinit var localVideo: LocalVideoChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        localVideo = LocalVideoChannel(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler(localVideo)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (::localVideo.isInitialized && localVideo.onActivityResult(requestCode, resultCode, data)) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        if (::localVideo.isInitialized) localVideo.dispose()
        super.onDestroy()
    }
}

private class LocalVideoChannel(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val sessions = mutableMapOf<String, AndroidVideoDecoder>()
    private var pendingPicker: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickVideo" -> pickVideo(result)
            "openVideo" -> runWorker(result) {
                val reference = call.argument<String>("reference")
                    ?: throw IllegalArgumentException("Missing video reference")
                val displayName = call.argument<String>("displayName")
                    ?: throw IllegalArgumentException("Missing video name")
                val sessionId = UUID.randomUUID().toString()
                val decoder = AndroidVideoDecoder(activity, Uri.parse(reference), displayName)
                sessions[sessionId] = decoder
                decoder.metadata(sessionId)
            }
            "nextFrame" -> runWorker(result) { session(call).nextFrame() }
            "closeVideo" -> runWorker(result) {
                val id = call.argument<String>("sessionId")
                    ?: throw IllegalArgumentException("Missing session ID")
                sessions.remove(id)?.close()
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun pickVideo(result: MethodChannel.Result) {
        if (pendingPicker != null) {
            result.error("picker_busy", "A video picker is already open", null)
            return
        }
        pendingPicker = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, PICK_VIDEO_REQUEST)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_VIDEO_REQUEST) return false
        val result = pendingPicker ?: return true
        pendingPicker = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return true
        }
        val uri = data.data!!
        val takeFlags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
        try {
            activity.contentResolver.takePersistableUriPermission(uri, takeFlags)
        } catch (_: SecurityException) {
            // Some providers grant only process-lifetime access. Opening the
            // decoder below still validates whether the URI is readable.
        }
        result.success(
            mapOf(
                "reference" to uri.toString(),
                "displayName" to displayName(uri),
            ),
        )
        return true
    }

    private fun displayName(uri: Uri): String {
        activity.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val value = cursor.getString(0)
                if (!value.isNullOrBlank()) return value
            }
        }
        return "secilen-video"
    }

    private fun session(call: MethodCall): AndroidVideoDecoder {
        val id = call.argument<String>("sessionId")
            ?: throw IllegalArgumentException("Missing session ID")
        return sessions[id] ?: throw IllegalStateException("Unknown or closed video session")
    }

    private fun runWorker(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (error: Throwable) {
                main.post {
                    result.error(
                        "local_video_error",
                        error.message ?: error.javaClass.simpleName,
                        null,
                    )
                }
            }
        }
    }

    fun dispose() {
        pendingPicker?.error("activity_closed", "Video picker was closed", null)
        pendingPicker = null
        worker.execute {
            sessions.values.forEach { it.close() }
            sessions.clear()
        }
        worker.shutdown()
    }
}

private class AndroidVideoDecoder(
    activity: Activity,
    uri: Uri,
    private val displayName: String,
) {
    private val extractor = MediaExtractor()
    private val codec: MediaCodec
    private val format: MediaFormat
    private val originalWidth: Int
    private val originalHeight: Int
    private val rotationDegrees: Int
    private val durationUs: Long
    private var inputEnded = false
    private var outputEnded = false
    private var closed = false
    private var lastTimestampUs = -1L
    private val info = MediaCodec.BufferInfo()

    init {
        extractor.setDataSource(activity, uri, null)
        var trackIndex = -1
        var selected: MediaFormat? = null
        for (index in 0 until extractor.trackCount) {
            val candidate = extractor.getTrackFormat(index)
            val mime = candidate.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("video/") == true) {
                trackIndex = index
                selected = candidate
                break
            }
        }
        require(trackIndex >= 0 && selected != null) { "Selected file has no video track" }
        format = selected
        originalWidth = format.getInteger(MediaFormat.KEY_WIDTH)
        originalHeight = format.getInteger(MediaFormat.KEY_HEIGHT)
        rotationDegrees = if (format.containsKey(MediaFormat.KEY_ROTATION)) {
            normalizeRotation(format.getInteger(MediaFormat.KEY_ROTATION))
        } else {
            0
        }
        durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
            format.getLong(MediaFormat.KEY_DURATION).coerceAtLeast(0)
        } else {
            0
        }
        extractor.selectTrack(trackIndex)
        format.setInteger(
            MediaFormat.KEY_COLOR_FORMAT,
            android.media.MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
        )
        val mime = checkNotNull(format.getString(MediaFormat.KEY_MIME))
        codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()
    }

    fun metadata(sessionId: String): Map<String, Any> {
        val rotated = rotationDegrees == 90 || rotationDegrees == 270
        return mapOf(
            "sessionId" to sessionId,
            "displayName" to displayName,
            "width" to if (rotated) originalHeight else originalWidth,
            "height" to if (rotated) originalWidth else originalHeight,
            "durationUs" to durationUs,
        )
    }

    fun nextFrame(): Map<String, Any>? {
        check(!closed) { "Video decoder is closed" }
        if (outputEnded) return null
        while (true) {
            feedInput()
            when (val outputIndex = codec.dequeueOutputBuffer(info, 20_000)) {
                MediaCodec.INFO_TRY_AGAIN_LATER,
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED,
                MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED,
                -> continue
                else -> if (outputIndex >= 0) {
                    val end = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    if (end) outputEnded = true
                    if (info.size <= 0) {
                        codec.releaseOutputBuffer(outputIndex, false)
                        if (end) return null
                        continue
                    }
                    val timestampUs = info.presentationTimeUs
                    val image = codec.getOutputImage(outputIndex)
                    if (image == null) {
                        codec.releaseOutputBuffer(outputIndex, false)
                        throw IllegalStateException("Decoder did not expose an RGB-convertible frame")
                    }
                    val rgb = image.use { convertToUprightRgb(it, rotationDegrees) }
                    codec.releaseOutputBuffer(outputIndex, false)
                    if (timestampUs <= lastTimestampUs) {
                        throw IllegalStateException("Video presentation timestamps are not increasing")
                    }
                    lastTimestampUs = timestampUs
                    return mapOf(
                        "width" to rgb.width,
                        "height" to rgb.height,
                        "timestampUs" to timestampUs,
                        "rgb" to rgb.bytes,
                    )
                }
            }
        }
    }

    private fun feedInput() {
        if (inputEnded) return
        val inputIndex = codec.dequeueInputBuffer(0)
        if (inputIndex < 0) return
        val input = checkNotNull(codec.getInputBuffer(inputIndex))
        input.clear()
        val size = extractor.readSampleData(input, 0)
        if (size < 0) {
            codec.queueInputBuffer(
                inputIndex,
                0,
                0,
                0,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
            )
            inputEnded = true
        } else {
            codec.queueInputBuffer(inputIndex, 0, size, extractor.sampleTime, 0)
            extractor.advance()
        }
    }

    fun close() {
        if (closed) return
        closed = true
        try {
            codec.stop()
        } finally {
            codec.release()
            extractor.release()
        }
    }
}

private data class RgbFrame(val bytes: ByteArray, val width: Int, val height: Int)

private fun convertToUprightRgb(image: Image, rotationDegrees: Int): RgbFrame {
    require(image.format == android.graphics.ImageFormat.YUV_420_888) {
        "Unsupported decoded pixel format ${image.format}"
    }
    val crop = image.cropRect
    val sourceWidth = crop.width()
    val sourceHeight = crop.height()
    val scale = minOf(1.0, MAX_FRAME_DIMENSION.toDouble() / max(sourceWidth, sourceHeight))
    val width = max(1, (sourceWidth * scale).roundToInt())
    val height = max(1, (sourceHeight * scale).roundToInt())
    val rgb = ByteArray(width * height * 3)
    val yPlane = image.planes[0]
    val uPlane = image.planes[1]
    val vPlane = image.planes[2]
    val yBase = yPlane.buffer.position()
    val uBase = uPlane.buffer.position()
    val vBase = vPlane.buffer.position()
    for (y in 0 until height) {
        val sourceY = crop.top + (y.toLong() * sourceHeight / height).toInt()
        for (x in 0 until width) {
            val sourceX = crop.left + (x.toLong() * sourceWidth / width).toInt()
            val yIndex = yBase + sourceY * yPlane.rowStride + sourceX * yPlane.pixelStride
            val chromaX = sourceX / 2
            val chromaY = sourceY / 2
            val uIndex = uBase + chromaY * uPlane.rowStride + chromaX * uPlane.pixelStride
            val vIndex = vBase + chromaY * vPlane.rowStride + chromaX * vPlane.pixelStride
            val yValue = yPlane.buffer.get(yIndex).toInt() and 0xff
            val uValue = uPlane.buffer.get(uIndex).toInt() and 0xff
            val vValue = vPlane.buffer.get(vIndex).toInt() and 0xff
            val c = (yValue - 16).coerceAtLeast(0)
            val d = uValue - 128
            val e = vValue - 128
            val offset = (y * width + x) * 3
            rgb[offset] = ((298 * c + 409 * e + 128) shr 8).coerceIn(0, 255).toByte()
            rgb[offset + 1] = ((298 * c - 100 * d - 208 * e + 128) shr 8)
                .coerceIn(0, 255).toByte()
            rgb[offset + 2] = ((298 * c + 516 * d + 128) shr 8).coerceIn(0, 255).toByte()
        }
    }
    return rotateRgb(rgb, width, height, rotationDegrees)
}

private fun rotateRgb(bytes: ByteArray, width: Int, height: Int, rotation: Int): RgbFrame {
    if (rotation == 0) return RgbFrame(bytes, width, height)
    val outputWidth = if (rotation == 90 || rotation == 270) height else width
    val outputHeight = if (rotation == 90 || rotation == 270) width else height
    val output = ByteArray(bytes.size)
    for (y in 0 until height) {
        for (x in 0 until width) {
            val (targetX, targetY) = when (rotation) {
                90 -> height - 1 - y to x
                180 -> width - 1 - x to height - 1 - y
                270 -> y to width - 1 - x
                else -> throw IllegalArgumentException("Unsupported video rotation")
            }
            val sourceOffset = (y * width + x) * 3
            val targetOffset = (targetY * outputWidth + targetX) * 3
            output[targetOffset] = bytes[sourceOffset]
            output[targetOffset + 1] = bytes[sourceOffset + 1]
            output[targetOffset + 2] = bytes[sourceOffset + 2]
        }
    }
    return RgbFrame(output, outputWidth, outputHeight)
}

private fun normalizeRotation(value: Int): Int {
    val normalized = ((value % 360) + 360) % 360
    require(normalized == 0 || normalized == 90 || normalized == 180 || normalized == 270) {
        "Unsupported video rotation $value"
    }
    return normalized
}
