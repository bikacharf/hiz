import 'package:flutter_test/flutter_test.dart';
import 'package:hiz_olcer/domain/measurement.dart';
import 'package:hiz_olcer/tracking/single_target_iou_tracker.dart';

void main() {
  test('keeps identity through overlap and a short missed-frame gap', () {
    final tracker = ConservativeSingleTargetTracker();
    final first = _detection(0, x: .1);
    final acquired = tracker.update(
      capture: first.capture,
      detections: [first],
    );
    final trackId = acquired.activeTrackId;
    expect(acquired.state, VideoTrackState.acquired);

    final gapCapture = _capture(1);
    expect(
      tracker.update(capture: gapCapture, detections: []).state,
      VideoTrackState.occluded,
    );
    final returned = _detection(2, x: .12);
    final tracked = tracker.update(
      capture: returned.capture,
      detections: [returned],
    );
    expect(tracked.state, VideoTrackState.tracked);
    expect(tracked.activeTrackId, trackId);

    final tracks = tracker.finish();
    expect(tracks, hasLength(1));
    expect(tracks.single.observedFrames, 2);
    expect(tracks.single.firstTimestampUs, 0);
    expect(tracks.single.lastTimestampUs, 2);
  });

  test('never chooses among ambiguous spatial matches', () {
    final tracker = ConservativeSingleTargetTracker(maximumMissedFrames: 0);
    final first = _detection(0, x: .1);
    tracker.update(capture: first.capture, detections: [first]);
    final capture = _capture(1);
    final result = tracker.update(
      capture: capture,
      detections: [_detection(1, x: .11), _detection(1, x: .12)],
    );
    expect(result.state, VideoTrackState.lost);
    expect(result.observed, isNull);
    expect(result.endedTrackId, isNotNull);
  });

  test('class and capture geometry changes end identity', () {
    for (final changed in [
      _detection(1, kind: TargetClass.bicycle),
      _detection(1, lensId: 'other-lens'),
    ]) {
      final tracker = ConservativeSingleTargetTracker();
      final first = _detection(0);
      final acquired = tracker.update(
        capture: first.capture,
        detections: [first],
      );
      final result = tracker.update(
        capture: changed.capture,
        detections: [changed],
      );
      expect(result.activeTrackId, isNull);
      expect(result.endedTrackId, acquired.activeTrackId);
      expect(
        result.state,
        changed.target.kind == TargetClass.bicycle
            ? VideoTrackState.classChanged
            : VideoTrackState.captureGeometryChanged,
      );
    }
  });

  test('rejects mismatched frame metadata and updates after finish', () {
    final tracker = ConservativeSingleTargetTracker();
    expect(
      () => tracker.update(capture: _capture(1), detections: [_detection(2)]),
      throwsArgumentError,
    );
    tracker.finish();
    expect(
      () => tracker.update(capture: _capture(3), detections: []),
      throwsArgumentError,
    );
  });
}

CaptureMetadata _capture(int timestampUs, {String lensId = 'video'}) =>
    CaptureMetadata(
      timestampUs: timestampUs,
      lensId: lensId,
      zoom: 1,
      width: 640,
      height: 480,
    );

DetectionObservation _detection(
  int timestampUs, {
  double x = .1,
  TargetClass kind = TargetClass.person,
  String lensId = 'video',
}) => DetectionObservation(
  capture: _capture(timestampUs, lensId: lensId),
  target: Target(kind),
  box: NormalizedBox(x, .1, .3, .5),
  score: .8,
  modelVersion: 'test',
);
