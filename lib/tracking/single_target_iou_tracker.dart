import 'dart:math' as math;

import '../domain/measurement.dart';

enum VideoTrackState {
  waiting,
  acquired,
  tracked,
  occluded,
  lost,
  ambiguous,
  classChanged,
  captureGeometryChanged,
  endOfVideo,
}

class VideoTrackUpdate {
  VideoTrackUpdate({
    required this.state,
    required this.activeTrackId,
    required this.endedTrackId,
    required this.observed,
    required this.missedFrames,
  });

  final VideoTrackState state;
  final String? activeTrackId;
  final String? endedTrackId;
  final DetectionObservation? observed;
  final int missedFrames;
}

class VideoTrackSummary {
  VideoTrackSummary({
    required this.trackId,
    required this.targetClass,
    required this.firstTimestampUs,
    required this.lastTimestampUs,
    required this.observedFrames,
    required this.ending,
  }) {
    require(trackId.isNotEmpty, 'Track ID required');
    require(observedFrames > 0, 'Track must contain an observation');
    require(lastTimestampUs >= firstTimestampUs, 'Invalid track timestamps');
  }

  final String trackId;
  final TargetClass targetClass;
  final int firstTimestampUs;
  final int lastTimestampUs;
  final int observedFrames;
  final VideoTrackState ending;

  int get observedDurationUs => lastTimestampUs - firstTimestampUs;
}

/// Conservative single-target spatial association for decoded video frames.
///
/// This tracker has no motion prediction, appearance model, re-identification,
/// target selection, metric scale, or speed output. Ambiguous matches never win
/// by score or list order.
class ConservativeSingleTargetTracker {
  ConservativeSingleTargetTracker({
    this.minimumIou = .2,
    this.maximumMissedFrames = 2,
  }) {
    require(
      minimumIou.isFinite &&
          minimumIou > 0 &&
          minimumIou <= 1 &&
          maximumMissedFrames >= 0,
      'Invalid tracker policy',
    );
  }

  final double minimumIou;
  final int maximumMissedFrames;
  final List<VideoTrackSummary> _completed = [];
  final List<DetectionObservation> _observations = [];

  String? _trackId;
  DetectionObservation? _last;
  CaptureMetadata? _previousCapture;
  var _serial = 0;
  var _missedFrames = 0;
  var _finished = false;

  List<VideoTrackSummary> get completedTracks => List.unmodifiable(_completed);

  VideoTrackUpdate update({
    required CaptureMetadata capture,
    required List<DetectionObservation> detections,
  }) {
    require(!_finished, 'Tracker is already finished');
    for (final detection in detections) {
      require(
        _sameCapture(detection.capture, capture),
        'Detection capture metadata must match its frame',
      );
    }

    String? endedTrackId;
    DetectionObservation? observed;
    late VideoTrackState state;
    final geometryChanged =
        _previousCapture != null &&
        (_previousCapture!.lensId != capture.lensId ||
            _previousCapture!.zoom != capture.zoom ||
            _previousCapture!.width != capture.width ||
            _previousCapture!.height != capture.height);

    if (geometryChanged) {
      endedTrackId = _end(VideoTrackState.captureGeometryChanged);
      state = VideoTrackState.captureGeometryChanged;
    } else if (_trackId == null) {
      if (detections.length == 1) {
        observed = detections.single;
        _trackId = 'video-track-${++_serial}';
        state = VideoTrackState.acquired;
      } else {
        state = detections.isEmpty
            ? VideoTrackState.waiting
            : VideoTrackState.ambiguous;
      }
    } else {
      final matches = detections
          .where((detection) => _iou(_last!.box, detection.box) >= minimumIou)
          .toList(growable: false);
      if (matches.length > 1) {
        state = VideoTrackState.ambiguous;
      } else if (matches.length == 1 &&
          matches.single.target.kind != _last!.target.kind) {
        endedTrackId = _end(VideoTrackState.classChanged);
        state = VideoTrackState.classChanged;
      } else if (matches.length == 1) {
        observed = matches.single;
        state = VideoTrackState.tracked;
      } else {
        state = VideoTrackState.occluded;
      }

      if (observed == null && _trackId != null) {
        _missedFrames++;
        if (_missedFrames > maximumMissedFrames) {
          endedTrackId = _end(VideoTrackState.lost);
          state = VideoTrackState.lost;
        }
      }
    }

    if (observed != null) {
      _observations.add(observed);
      _last = observed;
      _missedFrames = 0;
    }
    _previousCapture = capture;
    return VideoTrackUpdate(
      state: state,
      activeTrackId: _trackId,
      endedTrackId: endedTrackId,
      observed: observed,
      missedFrames: _missedFrames,
    );
  }

  List<VideoTrackSummary> finish() {
    if (!_finished) {
      _end(VideoTrackState.endOfVideo);
      _finished = true;
    }
    return completedTracks;
  }

  String? _end(VideoTrackState ending) {
    final endedTrackId = _trackId;
    if (endedTrackId != null) {
      final first = _observations.first;
      final last = _observations.last;
      _completed.add(
        VideoTrackSummary(
          trackId: endedTrackId,
          targetClass: first.target.kind,
          firstTimestampUs: first.capture.timestampUs,
          lastTimestampUs: last.capture.timestampUs,
          observedFrames: _observations.length,
          ending: ending,
        ),
      );
    }
    _trackId = null;
    _last = null;
    _observations.clear();
    _missedFrames = 0;
    return endedTrackId;
  }
}

bool _sameCapture(CaptureMetadata a, CaptureMetadata b) =>
    a.timestampUs == b.timestampUs &&
    a.lensId == b.lensId &&
    a.zoom == b.zoom &&
    a.width == b.width &&
    a.height == b.height;

double _iou(NormalizedBox a, NormalizedBox b) {
  final width = math.max(
    0.0,
    math.min(a.x + a.width, b.x + b.width) - math.max(a.x, b.x),
  );
  final height = math.max(
    0.0,
    math.min(a.y + a.height, b.y + b.height) - math.max(a.y, b.y),
  );
  final intersection = width * height;
  return intersection /
      (a.width * a.height + b.width * b.height - intersection);
}
