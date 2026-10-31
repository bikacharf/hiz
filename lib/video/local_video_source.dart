import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../detection/efficientdet_lite0.dart';
import '../domain/measurement.dart';

const localVideoChannelName = 'hiz_olcer/local_video';

class LocalVideoSelection {
  LocalVideoSelection({required this.reference, required this.displayName}) {
    require(reference.isNotEmpty && displayName.isNotEmpty, 'Invalid video');
  }

  final String reference;
  final String displayName;
}

class LocalVideoMetadata {
  LocalVideoMetadata({
    required this.sessionId,
    required this.displayName,
    required this.width,
    required this.height,
    required this.durationUs,
  }) {
    require(
      sessionId.isNotEmpty &&
          displayName.isNotEmpty &&
          width > 0 &&
          height > 0 &&
          durationUs >= 0,
      'Invalid local video metadata',
    );
  }

  final String sessionId;
  final String displayName;
  final int width;
  final int height;
  final int durationUs;
}

abstract interface class LocalVideoSource {
  Future<LocalVideoSelection?> pickVideo();
  Future<LocalVideoSession> open(LocalVideoSelection selection);
}

abstract interface class LocalVideoSession {
  LocalVideoMetadata get metadata;
  Future<DecodedRgbFrame?> nextFrame();
  Future<void> close();
}

class MethodChannelLocalVideoSource implements LocalVideoSource {
  MethodChannelLocalVideoSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(localVideoChannelName);

  final MethodChannel _channel;

  @override
  Future<LocalVideoSelection?> pickVideo() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('pickVideo');
    if (raw == null) return null;
    return LocalVideoSelection(
      reference: _string(raw, 'reference'),
      displayName: _string(raw, 'displayName'),
    );
  }

  @override
  Future<LocalVideoSession> open(LocalVideoSelection selection) async {
    final raw = await _channel.invokeMapMethod<String, Object?>('openVideo', {
      'reference': selection.reference,
      'displayName': selection.displayName,
    });
    if (raw == null) {
      throw const FormatException('Native video decoder returned no metadata');
    }
    final metadata = LocalVideoMetadata(
      sessionId: _string(raw, 'sessionId'),
      displayName: selection.displayName,
      width: _integer(raw, 'width'),
      height: _integer(raw, 'height'),
      durationUs: _integer(raw, 'durationUs'),
    );
    return _MethodChannelLocalVideoSession(_channel, metadata);
  }
}

class _MethodChannelLocalVideoSession implements LocalVideoSession {
  _MethodChannelLocalVideoSession(this._channel, this.metadata);

  final MethodChannel _channel;
  @override
  final LocalVideoMetadata metadata;
  var _closed = false;
  int? _lastTimestampUs;

  @override
  Future<DecodedRgbFrame?> nextFrame() async {
    if (_closed) throw StateError('Local video session is closed');
    final raw = await _channel.invokeMapMethod<String, Object?>('nextFrame', {
      'sessionId': metadata.sessionId,
    });
    if (raw == null) return null;
    final width = _integer(raw, 'width');
    final height = _integer(raw, 'height');
    final timestampUs = _integer(raw, 'timestampUs');
    final bytes = raw['rgb'];
    if (bytes is! Uint8List || bytes.length != width * height * 3) {
      throw const FormatException('Native video frame has invalid RGB bytes');
    }
    if (_lastTimestampUs != null && timestampUs <= _lastTimestampUs!) {
      throw const FormatException(
        'Video presentation timestamps must increase',
      );
    }
    _lastTimestampUs = timestampUs;
    return DecodedRgbFrame(
      rgb: bytes,
      capture: CaptureMetadata(
        timestampUs: timestampUs,
        lensId: 'local-video:${metadata.sessionId}',
        zoom: 1,
        width: width,
        height: height,
      ),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _channel.invokeMethod<void>('closeVideo', {
      'sessionId': metadata.sessionId,
    });
  }
}

String _string(Map<String, Object?> raw, String key) {
  final value = raw[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing or invalid $key');
  }
  return value;
}

int _integer(Map<String, Object?> raw, String key) {
  final value = raw[key];
  if (value is! int) throw FormatException('Missing or invalid $key');
  return value;
}
