import Flutter
import UIKit
import AVFoundation
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    LocalVideoPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "LocalVideoPlugin")
    )
  }
}

private final class LocalVideoPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private let queue = DispatchQueue(label: "hiz_olcer.local_video")
  private var sessions: [String: AppleVideoDecoder] = [:]
  private var pickerResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = LocalVideoPlugin()
    let channel = FlutterMethodChannel(
      name: "hiz_olcer/local_video",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.publish(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickVideo":
      pickVideo(result: result)
    case "openVideo":
      perform(result: result) {
        let arguments = try self.arguments(call)
        let reference = try self.string(arguments, "reference")
        let displayName = try self.string(arguments, "displayName")
        guard let url = URL(string: reference), url.isFileURL else {
          throw LocalVideoError.message("Invalid local video URL")
        }
        let id = UUID().uuidString
        let decoder = try AppleVideoDecoder(url: url, displayName: displayName)
        self.sessions[id] = decoder
        return decoder.metadata(sessionId: id)
      }
    case "nextFrame":
      perform(result: result) {
        let decoder = try self.session(call)
        guard let frame = try decoder.nextFrame() else { return nil }
        return [
          "width": frame.width,
          "height": frame.height,
          "timestampUs": frame.timestampUs,
          "rgb": FlutterStandardTypedData(bytes: frame.bytes),
        ]
      }
    case "closeVideo":
      perform(result: result) {
        let arguments = try self.arguments(call)
        let id = try self.string(arguments, "sessionId")
        self.sessions.removeValue(forKey: id)?.close()
        return nil
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickVideo(result: @escaping FlutterResult) {
    guard pickerResult == nil else {
      result(FlutterError(code: "picker_busy", message: "A video picker is already open", details: nil))
      return
    }
    guard let presenter = topViewController() else {
      result(FlutterError(code: "picker_unavailable", message: "No view can present the picker", details: nil))
      return
    }
    pickerResult = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie], asCopy: true)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let result = pickerResult
    pickerResult = nil
    guard let url = urls.first else {
      result?(nil)
      return
    }
    result?([
      "reference": url.absoluteString,
      "displayName": url.lastPathComponent.isEmpty ? "secilen-video" : url.lastPathComponent,
    ])
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pickerResult
    pickerResult = nil
    result?(nil)
  }

  private func perform(result: @escaping FlutterResult, operation: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try operation()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "local_video_error", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func arguments(_ call: FlutterMethodCall) throws -> [String: Any] {
    guard let arguments = call.arguments as? [String: Any] else {
      throw LocalVideoError.message("Missing method arguments")
    }
    return arguments
  }

  private func string(_ arguments: [String: Any], _ key: String) throws -> String {
    guard let value = arguments[key] as? String, !value.isEmpty else {
      throw LocalVideoError.message("Missing \(key)")
    }
    return value
  }

  private func session(_ call: FlutterMethodCall) throws -> AppleVideoDecoder {
    let arguments = try arguments(call)
    let id = try string(arguments, "sessionId")
    guard let decoder = sessions[id] else {
      throw LocalVideoError.message("Unknown or closed video session")
    }
    return decoder
  }

  private func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?.rootViewController
    var current = root
    while let presented = current?.presentedViewController { current = presented }
    return current
  }
}

private enum LocalVideoError: LocalizedError {
  case message(String)

  var errorDescription: String? {
    switch self { case .message(let value): return value }
  }
}

private final class AppleVideoDecoder {
  private let reader: AVAssetReader
  private let output: AVAssetReaderTrackOutput
  private let displayName: String
  private let sourceWidth: Int
  private let sourceHeight: Int
  private let rotation: Int
  private let durationUs: Int64
  private var lastTimestampUs: Int64 = -1
  private var closed = false

  init(url: URL, displayName: String) throws {
    let asset = AVURLAsset(url: url)
    guard let track = asset.tracks(withMediaType: .video).first else {
      throw LocalVideoError.message("Selected file has no video track")
    }
    self.displayName = displayName
    sourceWidth = Int(abs(track.naturalSize.width).rounded())
    sourceHeight = Int(abs(track.naturalSize.height).rounded())
    guard sourceWidth > 0, sourceHeight > 0 else {
      throw LocalVideoError.message("Video has invalid dimensions")
    }
    rotation = try AppleVideoDecoder.rotationDegrees(track.preferredTransform)
    let duration = asset.duration
    durationUs = duration.isNumeric
      ? max(0, CMTimeConvertScale(duration, timescale: 1_000_000, method: .roundHalfAwayFromZero).value)
      : 0
    reader = try AVAssetReader(asset: asset)
    output = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      ]
    )
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else {
      throw LocalVideoError.message("Video track cannot be decoded")
    }
    reader.add(output)
    guard reader.startReading() else {
      throw reader.error ?? LocalVideoError.message("Video decoder could not start")
    }
  }

  func metadata(sessionId: String) -> [String: Any] {
    let rotated = rotation == 90 || rotation == 270
    return [
      "sessionId": sessionId,
      "displayName": displayName,
      "width": rotated ? sourceHeight : sourceWidth,
      "height": rotated ? sourceWidth : sourceHeight,
      "durationUs": durationUs,
    ]
  }

  func nextFrame() throws -> AppleRgbFrame? {
    guard !closed else { throw LocalVideoError.message("Video decoder is closed") }
    guard let sample = output.copyNextSampleBuffer() else {
      if reader.status == .completed { return nil }
      throw reader.error ?? LocalVideoError.message("Video decoding ended unexpectedly")
    }
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
      throw LocalVideoError.message("Decoded sample has no pixel buffer")
    }
    let pts = CMSampleBufferGetPresentationTimeStamp(sample)
    guard pts.isNumeric else { throw LocalVideoError.message("Video frame has invalid PTS") }
    let timestampUs = CMTimeConvertScale(
      pts,
      timescale: 1_000_000,
      method: .roundHalfAwayFromZero
    ).value
    guard timestampUs >= 0, timestampUs > lastTimestampUs else {
      throw LocalVideoError.message("Video presentation timestamps are not increasing")
    }
    lastTimestampUs = timestampUs
    return try convertPixelBuffer(pixelBuffer, rotation: rotation, timestampUs: timestampUs)
  }

  func close() {
    if closed { return }
    closed = true
    reader.cancelReading()
  }

  private static func rotationDegrees(_ transform: CGAffineTransform) throws -> Int {
    let determinant = transform.a * transform.d - transform.b * transform.c
    guard determinant > 0 else {
      throw LocalVideoError.message("Mirrored video orientation is unsupported")
    }
    var degrees = Int((atan2(transform.b, transform.a) * 180 / .pi).rounded())
    degrees = (degrees % 360 + 360) % 360
    guard [0, 90, 180, 270].contains(degrees) else {
      throw LocalVideoError.message("Unsupported video rotation \(degrees)")
    }
    return degrees
  }
}

private struct AppleRgbFrame {
  let bytes: Data
  let width: Int
  let height: Int
  let timestampUs: Int64
}

private func convertPixelBuffer(
  _ pixelBuffer: CVPixelBuffer,
  rotation: Int,
  timestampUs: Int64
) throws -> AppleRgbFrame {
  guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
    throw LocalVideoError.message("Unsupported decoded pixel format")
  }
  CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
  defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
  guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
    throw LocalVideoError.message("Decoded pixel buffer is inaccessible")
  }
  let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
  let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
  let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
  let scale = min(1.0, 640.0 / Double(max(sourceWidth, sourceHeight)))
  let width = max(1, Int((Double(sourceWidth) * scale).rounded()))
  let height = max(1, Int((Double(sourceHeight) * scale).rounded()))
  var bytes = Data(count: width * height * 3)
  bytes.withUnsafeMutableBytes { destination in
    let source = base.assumingMemoryBound(to: UInt8.self)
    let target = destination.bindMemory(to: UInt8.self).baseAddress!
    for y in 0..<height {
      let sourceY = y * sourceHeight / height
      for x in 0..<width {
        let sourceX = x * sourceWidth / width
        let sourceOffset = sourceY * stride + sourceX * 4
        let targetOffset = (y * width + x) * 3
        target[targetOffset] = source[sourceOffset + 2]
        target[targetOffset + 1] = source[sourceOffset + 1]
        target[targetOffset + 2] = source[sourceOffset]
      }
    }
  }
  let rotated = rotateRgbData(bytes, width: width, height: height, rotation: rotation)
  return AppleRgbFrame(
    bytes: rotated.0,
    width: rotated.1,
    height: rotated.2,
    timestampUs: timestampUs
  )
}

private func rotateRgbData(
  _ bytes: Data,
  width: Int,
  height: Int,
  rotation: Int
) -> (Data, Int, Int) {
  if rotation == 0 { return (bytes, width, height) }
  let outputWidth = rotation == 90 || rotation == 270 ? height : width
  let outputHeight = rotation == 90 || rotation == 270 ? width : height
  var output = Data(count: bytes.count)
  bytes.withUnsafeBytes { sourceRaw in
    output.withUnsafeMutableBytes { targetRaw in
      let source = sourceRaw.bindMemory(to: UInt8.self).baseAddress!
      let target = targetRaw.bindMemory(to: UInt8.self).baseAddress!
      for y in 0..<height {
        for x in 0..<width {
          let targetPoint: (Int, Int)
          switch rotation {
          case 90: targetPoint = (height - 1 - y, x)
          case 180: targetPoint = (width - 1 - x, height - 1 - y)
          case 270: targetPoint = (y, width - 1 - x)
          default: preconditionFailure("Rotation was validated")
          }
          let sourceOffset = (y * width + x) * 3
          let targetOffset = (targetPoint.1 * outputWidth + targetPoint.0) * 3
          target[targetOffset] = source[sourceOffset]
          target[targetOffset + 1] = source[sourceOffset + 1]
          target[targetOffset + 2] = source[sourceOffset + 2]
        }
      }
    }
  }
  return (output, outputWidth, outputHeight)
}
