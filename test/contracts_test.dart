import 'package:flutter_test/flutter_test.dart';
import 'package:hiz_olcer/domain/contracts.dart';

void main() {
  test('detection requires finite score and explicit model provenance', () {
    final frame = CaptureMetadata(
      timestampUs: 0,
      lensId: 'synthetic',
      zoom: 1,
      width: 640,
      height: 480,
    );
    DetectionObservation observation(double score, String model) =>
        DetectionObservation(
          capture: frame,
          target: Target(TargetClass.vehicle),
          box: NormalizedBox(0, 0, 1, 1),
          score: score,
          modelVersion: model,
        );
    expect(() => observation(double.nan, 'test-only'), throwsArgumentError);
    expect(() => observation(1.1, 'test-only'), throwsArgumentError);
    expect(() => observation(.5, ''), throwsArgumentError);
  });
  test(
    'scale hypotheses reject missing assumptions and invalid uncertainty',
    () {
      expect(
        () => ScaleHypothesis(
          method: 'synthetic-only',
          metersPerPixel: 1,
          uncertainty: double.infinity,
          assumptions: ['test only'],
        ),
        throwsArgumentError,
      );
      expect(
        () => ScaleHypothesis(
          method: 'synthetic-only',
          metersPerPixel: 1,
          uncertainty: 0,
          assumptions: [],
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'native frame and motion contracts preserve explicit unknown signals',
    () {
      final metadata = CaptureMetadata(
        timestampUs: 0,
        lensId: 'synthetic',
        zoom: 1,
        width: 640,
        height: 480,
      );
      expect(
        () => CapturedFrame(metadata: metadata, nativeBufferId: ''),
        throwsArgumentError,
      );
      expect(
        CameraMotionObservation(
          capture: metadata,
          method: 'test-only',
        ).normalizedMotion,
        isNull,
      );
      expect(
        () => CameraMotionObservation(
          capture: metadata,
          method: 'test-only',
          normalizedMotion: double.nan,
        ),
        throwsArgumentError,
      );
    },
  );
}
