import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiz_olcer/detection/efficientdet_lite0.dart';
import 'package:hiz_olcer/domain/measurement.dart';

void main() {
  group('RGB preprocessing', () {
    test('letterboxes a wide frame without stretching it', () {
      final frame = _frame(width: 4, height: 2, timestampUs: 100);
      final prepared = letterboxRgb(frame);

      expect(prepared.bytes, hasLength(320 * 320 * 3));
      expect(prepared.scale, 80);
      expect(prepared.padX, 0);
      expect(prepared.padY, 80);
      expect(prepared.bytes.take(80 * 320 * 3), everyElement(0));

      final box = prepared.sourceBox(const [0.25, 0, 0.75, 1]);
      expect(box, isNotNull);
      expect(box!.x, closeTo(0, 1e-9));
      expect(box.y, closeTo(0, 1e-9));
      expect(box.width, closeTo(1, 1e-9));
      expect(box.height, closeTo(1, 1e-9));
    });

    test('clips padding-only boxes instead of inventing source geometry', () {
      final prepared = letterboxRgb(
        _frame(width: 4, height: 2, timestampUs: 100),
      );
      expect(prepared.sourceBox(const [0, 0, 0.2, 1]), isNull);
    });

    test('rejects incomplete or rotated decoded frames', () {
      expect(
        () => DecodedRgbFrame(
          rgb: Uint8List(2),
          capture: _capture(width: 2, height: 2, timestampUs: 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => DecodedRgbFrame(
          rgb: Uint8List(12),
          capture: _capture(width: 2, height: 2, timestampUs: 1),
          rotationDegrees: 90,
        ),
        throwsArgumentError,
      );
    });
  });

  group('output parsing', () {
    test(
      'maps only supported coarse COCO classes and preserves source PTS',
      () {
        final capture = _capture(width: 4, height: 2, timestampUs: 987654);
        final transform = letterboxRgb(
          DecodedRgbFrame(rgb: Uint8List(24), capture: capture),
        );
        final raw = _raw(
          count: 8,
          classes: const [0, 1, 2, 3, 5, 7, 36, 4],
          scores: const [.9, .9, .9, .9, .9, .9, .9, .9],
        );

        final result = parseEfficientDetOutput(
          raw,
          transform: transform,
          capture: capture,
          minimumScore: .35,
        );

        expect(result.map((item) => item.target.kind), [
          TargetClass.person,
          TargetClass.bicycle,
          TargetClass.vehicle,
          TargetClass.vehicle,
          TargetClass.vehicle,
          TargetClass.vehicle,
          TargetClass.ball,
        ]);
        expect(
          result.every((item) => item.capture.timestampUs == 987654),
          isTrue,
        );
        expect(result.every((item) => item.target.ballType == null), isTrue);
        expect(
          result.every(
            (item) => item.modelVersion == efficientDetLite0ModelVersion,
          ),
          isTrue,
        );
      },
    );

    test('filters low scores and returns an explicit empty list', () {
      final capture = _capture(width: 2, height: 2, timestampUs: 4);
      final transform = letterboxRgb(
        DecodedRgbFrame(rgb: Uint8List(12), capture: capture),
      );
      final result = parseEfficientDetOutput(
        _raw(count: 1, classes: const [0], scores: const [.2]),
        transform: transform,
        capture: capture,
        minimumScore: .35,
      );
      expect(result, isEmpty);
    });

    test('fails closed on malformed count, class, score and boxes', () {
      final capture = _capture(width: 2, height: 2, timestampUs: 4);
      final transform = letterboxRgb(
        DecodedRgbFrame(rgb: Uint8List(12), capture: capture),
      );
      List<DetectionObservation> parse(EfficientDetRawOutput raw) =>
          parseEfficientDetOutput(
            raw,
            transform: transform,
            capture: capture,
            minimumScore: .35,
          );

      expect(() => parse(_raw(count: 26)), throwsFormatException);
      expect(
        () => parse(_raw(count: 1, classes: const [.5])),
        throwsFormatException,
      );
      expect(
        () => parse(_raw(count: 1, scores: const [double.nan])),
        throwsFormatException,
      );
      expect(
        () => parse(
          _raw(
            count: 1,
            boxes: const [
              <double>[.5, .5, .4, .6],
            ],
          ),
        ),
        throwsFormatException,
      );
    });
  });

  group('adapter boundary', () {
    test(
      'uses the model runtime and returns a typed detection frame',
      () async {
        final runtime = _FakeRuntime(
          _raw(count: 1, classes: const [1], scores: const [.8]),
        );
        final adapter = EfficientDetLite0Adapter(runtime);
        final source = _frame(width: 4, height: 2, timestampUs: 333);

        final result = await adapter.detect(source);

        expect(runtime.calls, 1);
        expect(runtime.lastInput, hasLength(320 * 320 * 3));
        expect(result.capture, same(source.capture));
        expect(result.detections.single.target.kind, TargetClass.bicycle);
        adapter.close();
        expect(runtime.closed, isTrue);
      },
    );

    test('rejects ambiguous or changed tensor contracts before inference', () {
      final runtime = _FakeRuntime(_raw(count: 0))
        ..outputSpecs = const [
          DetectorTensorSpec('renamed-output', [
            1,
            25,
            4,
          ], DetectorTensorType.float32),
        ];
      expect(() => EfficientDetLite0Adapter(runtime), throwsFormatException);
      expect(runtime.calls, 0);
    });

    test('does not share the synthetic fixture adapter identity', () {
      final runtime = _FakeRuntime(_raw(count: 0));
      final adapter = EfficientDetLite0Adapter(runtime);
      expect(adapter.runtimeType.toString(), isNot('OfflineHarness'));
      expect(efficientDetLite0ModelVersion, contains('sha256:'));
    });
  });
}

CaptureMetadata _capture({
  required int width,
  required int height,
  required int timestampUs,
}) => CaptureMetadata(
  timestampUs: timestampUs,
  lensId: 'fixture-lens',
  zoom: 1,
  width: width,
  height: height,
);

DecodedRgbFrame _frame({
  required int width,
  required int height,
  required int timestampUs,
}) {
  final bytes = Uint8List(width * height * 3);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = (i % 251) + 1;
  }
  return DecodedRgbFrame(
    rgb: bytes,
    capture: _capture(width: width, height: height, timestampUs: timestampUs),
  );
}

EfficientDetRawOutput _raw({
  required double count,
  List<double> classes = const [],
  List<double> scores = const [],
  List<List<double>> boxes = const [],
}) {
  final allBoxes = List.generate(
    25,
    (index) => index < boxes.length
        ? List<double>.from(boxes[index])
        : <double>[.25, .1, .75, .9],
  );
  final allClasses = List<double>.filled(25, 0);
  final allScores = List<double>.filled(25, 0);
  allClasses.setRange(0, classes.length, classes);
  allScores.setRange(0, scores.length, scores);
  return EfficientDetRawOutput(
    boxes: allBoxes,
    classes: allClasses,
    scores: allScores,
    count: count,
  );
}

class _FakeRuntime implements EfficientDetRuntime {
  _FakeRuntime(this.result);

  final EfficientDetRawOutput result;
  var calls = 0;
  var closed = false;
  Uint8List? lastInput;

  @override
  DetectorTensorSpec input = const DetectorTensorSpec(
    'serving_default_images:0',
    [1, 320, 320, 3],
    DetectorTensorType.uint8,
  );

  List<DetectorTensorSpec> outputSpecs = const [
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
  List<DetectorTensorSpec> get outputs => outputSpecs;

  @override
  Future<EfficientDetRawOutput> run(Uint8List inputRgb) async {
    calls++;
    lastInput = inputRgb;
    return result;
  }

  @override
  void close() => closed = true;
}
