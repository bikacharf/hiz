import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiz_olcer/detection/efficientdet_lite0.dart';
import 'package:hiz_olcer/domain/measurement.dart';
import 'package:hiz_olcer/video/local_video_analysis.dart';
import 'package:hiz_olcer/video/local_video_source.dart';

void main() {
  test(
    'analyzer uses decoded source PTS, counts detections, and closes',
    () async {
      final session = _FakeSession([_frame(1000), _frame(2600)]);
      final runtime = _FakeRuntime([_raw(classIndex: 0), _raw(classIndex: 1)]);
      final summary = await LocalVideoAnalyzer(
        runtimeFactory: () async => runtime,
        maximumFrames: 3,
      ).analyze(session);

      expect(summary.decodedFrames, 2);
      expect(summary.framesWithDetections, 2);
      expect(summary.detectionCounts[TargetClass.person], 1);
      expect(summary.detectionCounts[TargetClass.bicycle], 1);
      expect(summary.truncated, isFalse);
      expect(runtime.closed, isTrue);
      expect(session.closed, isTrue);
    },
  );

  test('analyzer closes native and model resources after failure', () async {
    final session = _FakeSession([_frame(1000)]);
    final runtime = _FakeRuntime([_raw(classIndex: .5)]);
    final analyzer = LocalVideoAnalyzer(runtimeFactory: () async => runtime);
    await expectLater(analyzer.analyze(session), throwsFormatException);
    expect(runtime.closed, isTrue);
    expect(session.closed, isTrue);
  });
}

DecodedRgbFrame _frame(int timestampUs) => DecodedRgbFrame(
  rgb: Uint8List(12),
  capture: CaptureMetadata(
    timestampUs: timestampUs,
    lensId: 'local-video:test',
    zoom: 1,
    width: 2,
    height: 2,
  ),
);

EfficientDetRawOutput _raw({required double classIndex}) {
  final boxes = List.generate(
    25,
    (_) => <double>[.1, .1, .9, .9],
    growable: false,
  );
  final classes = List<double>.filled(25, 0)..[0] = classIndex;
  final scores = List<double>.filled(25, 0)..[0] = .8;
  return EfficientDetRawOutput(
    boxes: boxes,
    classes: classes,
    scores: scores,
    count: 1,
  );
}

class _FakeSession implements LocalVideoSession {
  _FakeSession(this.frames);

  final List<DecodedRgbFrame> frames;
  var index = 0;
  var closed = false;

  @override
  final metadata = LocalVideoMetadata(
    sessionId: 'test',
    displayName: 'fixture.mp4',
    width: 2,
    height: 2,
    durationUs: 3000,
  );

  @override
  Future<DecodedRgbFrame?> nextFrame() async =>
      index < frames.length ? frames[index++] : null;

  @override
  Future<void> close() async => closed = true;
}

class _FakeRuntime implements EfficientDetRuntime {
  _FakeRuntime(this.outputs);

  final List<EfficientDetRawOutput> outputs;
  var index = 0;
  var closed = false;

  @override
  DetectorTensorSpec get input => const DetectorTensorSpec(
    'serving_default_images:0',
    [1, 320, 320, 3],
    DetectorTensorType.uint8,
  );

  @override
  List<DetectorTensorSpec> get outputs => const [
    DetectorTensorSpec('StatefulPartitionedCall:3', [
      1,
      25,
      4,
    ], DetectorTensorType.float32),
    DetectorTensorSpec('StatefulPartitionedCall:2', [
      1,
      25,
    ], DetectorTensorType.float32),
    DetectorTensorSpec('StatefulPartitionedCall:1', [
      1,
      25,
    ], DetectorTensorType.float32),
    DetectorTensorSpec('StatefulPartitionedCall:0', [
      1,
    ], DetectorTensorType.float32),
  ];

  @override
  Future<EfficientDetRawOutput> run(Uint8List inputRgb) async {
    return outputs[index++];
  }

  @override
  void close() => closed = true;
}
