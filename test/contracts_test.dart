import 'package:flutter_test/flutter_test.dart';
import 'package:hiz/domain/contracts.dart';

QualitySignals signals({
  double pixels = 80,
  int duration = 1000000,
  bool supported = true,
  bool lens = true,
  bool blur = true,
  bool occlusion = true,
  bool angle = true,
  bool stable = true,
}) => QualitySignals(
  targetPixels: pixels,
  durationUs: duration,
  modelSupported: supported,
  lensUnchanged: lens,
  blurAcceptable: blur,
  occlusionAcceptable: occlusion,
  angleAcceptable: angle,
  cameraStable: stable,
);

CaptureMetadata capture(int time, {double zoom = 1}) => CaptureMetadata(
  timestampUs: time,
  lensId: 'synthetic',
  zoom: zoom,
  width: 640,
  height: 480,
);

void main() {
  test('capture rejects invalid geometry, timing and nonfinite zoom', () {
    expect(() => capture(-1), throwsArgumentError);
    expect(() => capture(0, zoom: double.nan), throwsArgumentError);
    expect(
      () => CaptureMetadata(
        timestampUs: 0,
        lensId: '',
        zoom: 1,
        width: 0,
        height: 480,
      ),
      throwsArgumentError,
    );
  });
  test('target subtype and box bounds are enforced', () {
    expect(() => Target(TargetClass.ball), throwsArgumentError);
    expect(
      () => Target(TargetClass.person, ballSubtype: BallSubtype.tennis),
      throwsArgumentError,
    );
    expect(() => NormalizedBox(.9, 0, .2, 1), throwsArgumentError);
    expect(() => NormalizedBox(double.nan, 0, 1, 1), throwsArgumentError);
    expect(
      Target(TargetClass.ball, ballSubtype: BallSubtype.tennis).ballSubtype,
      BallSubtype.tennis,
    );
  });
  test('observation scores, tracking and evidence preserve provenance', () {
    DetectionObservation detection(double score) => DetectionObservation(
      capture: capture(0),
      target: Target(TargetClass.vehicle),
      box: NormalizedBox(0, 0, 1, 1),
      score: score,
      modelVersion: 'synthetic',
    );
    expect(() => detection(double.nan), throwsArgumentError);
    expect(() => detection(1.1), throwsArgumentError);
    expect(
      () => TrackingObservation(
        trackId: '',
        detection: detection(.5),
        missedFrames: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => EvidenceRecord(
        id: 'test',
        capture: capture(0),
        stage: 'test',
        buildVersion: 'test',
        values: {'x': double.nan},
      ),
      throwsArgumentError,
    );
    final track = TrackingObservation(
      trackId: 'synthetic',
      detection: detection(.5),
      missedFrames: 1,
    );
    expect(track.detection.capture.timestampUs, 0);
    expect(track.missedFrames, 1);
  });
  test(
    'quality thresholds accept boundary and reject each inadequate signal',
    () {
      final gate = QualityGate();
      expect(gate.evaluate(signals()).band, QualityBand.acceptable);
      final cases = <String, QualitySignals>{
        'targetTooSmall': signals(pixels: 79.9),
        'trackTooShort': signals(duration: 999999),
        'unsupportedModel': signals(supported: false),
        'lensOrZoomChanged': signals(lens: false),
        'blur': signals(blur: false),
        'occlusion': signals(occlusion: false),
        'viewAngle': signals(angle: false),
        'cameraMotion': signals(stable: false),
      };
      for (final entry in cases.entries) {
        final result = gate.evaluate(entry.value);
        expect(result.band, QualityBand.unavailable);
        expect(result.failures, [entry.key]);
      }
      expect(
        gate.evaluate(signals(pixels: 0, duration: 0)).failures,
        containsAll(['targetTooSmall', 'trackTooShort']),
      );
      expect(() => signals(pixels: double.infinity), throwsArgumentError);
    },
  );
  test('candidate requires provenance and increasing capture timestamps; no M0 speed', () {
    final evidence = EvidenceRecord(
      id: 'synthetic',
      capture: capture(0),
      stage: 'test',
      buildVersion: 'test',
      values: {'pixelDisplacement': 1},
    );
    MeasurementCandidate candidate(int end, {double zoom = 1}) =>
        MeasurementCandidate(
          trackId: 'synthetic',
          target: Target(TargetClass.person),
          start: capture(0),
          end: capture(end, zoom: zoom),
          scale: ScaleHypothesis(
            method: 'synthetic-only',
            metersPerPixel: 1,
            uncertainty: 1,
            assumptions: ['synthetic fixture'],
          ),
          quality: QualityGate().evaluate(signals()),
          signals: signals(),
          modelVersion: 'none-test',
          buildVersion: 'test',
          evidence: [evidence],
          limitations: ['not validated'],
        );
    expect(() => candidate(0), throwsArgumentError);
    expect(() => candidate(1, zoom: 2), throwsArgumentError);
    expect(candidate(1).estimatedMetersPerSecond, isNull);
    expect(() => evidence.values['x'] = 2, throwsUnsupportedError);
    expect(
      () => ScaleHypothesis(
        method: '',
        metersPerPixel: 1,
        uncertainty: 0,
        assumptions: [],
      ),
      throwsArgumentError,
    );
  });
}
