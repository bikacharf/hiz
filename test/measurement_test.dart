import 'package:flutter_test/flutter_test.dart';
import 'package:hiz_olcer/domain/measurement.dart';

CaptureMetadata frame(int t, {double zoom = 1}) => CaptureMetadata(
  timestampUs: t,
  lensId: 'synthetic',
  zoom: zoom,
  width: 640,
  height: 480,
);
DetectionObservation observation(int t, {double zoom = 1}) =>
    DetectionObservation(
      capture: frame(t, zoom: zoom),
      target: Target(TargetClass.person),
      box: NormalizedBox(.1, .1, .5, .5),
      score: .8,
      modelVersion: 'synthetic-test-only',
    );
TrackingObservation track(List<DetectionObservation> observations) =>
    TrackingObservation(
      trackId: 'test',
      observations: observations,
      missedFrames: 0,
    );

void main() {
  test('ball subtype is mandatory and exclusive', () {
    expect(() => Target(TargetClass.ball), throwsArgumentError);
    expect(
      () => Target(TargetClass.person, ballType: BallType.tennis),
      throwsArgumentError,
    );
    expect(
      Target(TargetClass.ball, ballType: BallType.tennis).ballType,
      BallType.tennis,
    );
  });
  test('invalid capture and boxes are rejected', () {
    expect(() => frame(-1), throwsArgumentError);
    expect(() => frame(1, zoom: double.nan), throwsArgumentError);
    expect(() => NormalizedBox(.9, 0, .2, .1), throwsArgumentError);
    expect(() => NormalizedBox(0, 0, double.infinity, 1), throwsArgumentError);
  });
  test('track requires monotonic metadata and stable optics', () {
    expect(() => track([observation(2), observation(1)]), throwsArgumentError);
    expect(() => track([observation(1), observation(1)]), throwsArgumentError);
    expect(
      () => track([observation(1), observation(2, zoom: 2)]),
      throwsArgumentError,
    );
  });
  test('every unknown or failed gate blocks quality', () {
    final gates = {for (final gate in QualityGate.values) gate: true};
    expect(QualitySignals(gates).band, QualityBand.sufficient);
    for (final gate in QualityGate.values) {
      expect(QualitySignals({...gates, gate: false}).failures, contains(gate));
      expect(
        QualitySignals({...gates, gate: null}).band,
        QualityBand.unavailable,
      );
      expect(
        QualitySignals({...gates}..remove(gate)).band,
        QualityBand.unavailable,
      );
    }
  });
  test('insufficient evidence cannot carry numeric speed', () {
    final t = track([observation(1), observation(2)]);
    expect(
      () => MeasurementCandidate(
        track: t,
        quality: QualitySignals({}),
        buildVersion: 'test',
        limitations: ['synthetic'],
        metersPerSecond: 1,
      ),
      throwsArgumentError,
    );
    final unavailable = MeasurementCandidate(
      track: t,
      quality: QualitySignals({}),
      buildVersion: 'test',
      limitations: ['method not implemented'],
    );
    expect(unavailable.metersPerSecond, isNull);
  });
  test('invalid observable quality metrics are rejected', () {
    expect(() => QualityMetrics(blur: double.nan), throwsArgumentError);
    expect(() => QualityMetrics(occlusion: 1.1), throwsArgumentError);
    expect(() => QualityMetrics(trackDurationUs: -1), throwsArgumentError);
    expect(() => QualityMetrics(targetPixels: 0), throwsArgumentError);
  });
  test('observations and quality evidence cannot be mutated by callers', () {
    final input = [observation(1)];
    final result = track(input);
    input.clear();
    expect(result.observations, hasLength(1));
    expect(() => result.observations.clear(), throwsUnsupportedError);
  });
}
