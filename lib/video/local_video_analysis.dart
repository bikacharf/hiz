import 'dart:typed_data';

import '../detection/efficientdet_lite0.dart';
import '../domain/measurement.dart';
import '../tracking/single_target_iou_tracker.dart';
import 'local_video_source.dart';

class LocalVideoAnalysisSummary {
  LocalVideoAnalysisSummary._({
    required this.video,
    required this.decodedFrames,
    required this.framesWithDetections,
    required Map<TargetClass, int> detectionCounts,
    required List<VideoTrackSummary> tracks,
    required this.framesWithTrackObservation,
    required this.ambiguousFrames,
    required this.truncated,
    required this.selectionPrompt,
    required List<_AnalyzedVideoFrame> analyzedFrames,
  }) : detectionCounts = Map.unmodifiable(detectionCounts),
       tracks = List.unmodifiable(tracks),
       _analyzedFrames = List.unmodifiable(analyzedFrames);

  final LocalVideoMetadata video;
  final int decodedFrames;
  final int framesWithDetections;
  final Map<TargetClass, int> detectionCounts;
  final List<VideoTrackSummary> tracks;
  final int framesWithTrackObservation;
  final int ambiguousFrames;
  final bool truncated;
  final LocalVideoSelectionPrompt? selectionPrompt;
  final List<_AnalyzedVideoFrame> _analyzedFrames;

  VideoTrackSummary? get longestTrack => tracks.isEmpty
      ? null
      : tracks.reduce(
          (current, candidate) =>
              candidate.observedFrames > current.observedFrames
              ? candidate
              : current,
        );

  LocalVideoAnalysisSummary selectCandidate(int candidateIndex) {
    final prompt = selectionPrompt;
    if (prompt == null) {
      throw StateError('No target selection is pending');
    }
    require(
      candidateIndex >= 0 && candidateIndex < prompt.candidates.length,
      'Invalid target selection',
    );
    final tracking = _trackFrames(
      _analyzedFrames,
      selectionFrameIndex: prompt.frameIndex,
      selectedDetection: prompt.candidates[candidateIndex],
    );
    return LocalVideoAnalysisSummary._(
      video: video,
      decodedFrames: decodedFrames,
      framesWithDetections: framesWithDetections,
      detectionCounts: detectionCounts,
      tracks: tracking.tracks,
      framesWithTrackObservation: tracking.framesWithTrackObservation,
      ambiguousFrames: tracking.ambiguousFrames,
      truncated: truncated,
      selectionPrompt: null,
      analyzedFrames: _analyzedFrames,
    );
  }
}

class LocalVideoSelectionPrompt {
  LocalVideoSelectionPrompt({
    required this.frameIndex,
    required this.capture,
    required Uint8List rgb,
    required List<DetectionObservation> candidates,
  }) : rgb = Uint8List.fromList(rgb),
       candidates = List.unmodifiable(candidates) {
    require(
      frameIndex >= 0 &&
          rgb.length == capture.width * capture.height * 3 &&
          candidates.length > 1 &&
          candidates.every(
            (candidate) =>
                candidate.capture.timestampUs == capture.timestampUs &&
                candidate.capture.lensId == capture.lensId &&
                candidate.capture.zoom == capture.zoom &&
                candidate.capture.width == capture.width &&
                candidate.capture.height == capture.height,
          ),
      'Invalid target selection prompt',
    );
  }

  final int frameIndex;
  final CaptureMetadata capture;
  final Uint8List rgb;
  final List<DetectionObservation> candidates;
}

class _AnalyzedVideoFrame {
  _AnalyzedVideoFrame(this.capture, List<DetectionObservation> detections)
    : detections = List.unmodifiable(detections);

  final CaptureMetadata capture;
  final List<DetectionObservation> detections;
}

class _TrackingSummary {
  _TrackingSummary({
    required this.tracks,
    required this.framesWithTrackObservation,
    required this.ambiguousFrames,
  });

  final List<VideoTrackSummary> tracks;
  final int framesWithTrackObservation;
  final int ambiguousFrames;
}

class LocalVideoAnalyzer {
  LocalVideoAnalyzer({required this.runtimeFactory, this.maximumFrames = 120}) {
    require(maximumFrames > 0, 'maximumFrames must be positive');
  }

  final Future<EfficientDetRuntime> Function() runtimeFactory;
  final int maximumFrames;

  Future<LocalVideoAnalysisSummary> analyze(LocalVideoSession session) async {
    EfficientDetRuntime? runtime;
    var decodedFrames = 0;
    var framesWithDetections = 0;
    var reachedEnd = false;
    final counts = <TargetClass, int>{};
    final analyzedFrames = <_AnalyzedVideoFrame>[];
    LocalVideoSelectionPrompt? selectionPrompt;
    try {
      runtime = await runtimeFactory();
      final detector = EfficientDetLite0Adapter(runtime);
      while (decodedFrames < maximumFrames) {
        final frame = await session.nextFrame();
        if (frame == null) {
          reachedEnd = true;
          break;
        }
        final result = await detector.detect(frame);
        decodedFrames++;
        if (result.detections.isNotEmpty) framesWithDetections++;
        analyzedFrames.add(
          _AnalyzedVideoFrame(frame.capture, result.detections),
        );
        if (selectionPrompt == null && result.detections.length > 1) {
          selectionPrompt = LocalVideoSelectionPrompt(
            frameIndex: analyzedFrames.length - 1,
            capture: frame.capture,
            rgb: frame.rgb,
            candidates: result.detections,
          );
        }
        for (final detection in result.detections) {
          counts.update(
            detection.target.kind,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
      final tracking = _trackFrames(analyzedFrames);
      return LocalVideoAnalysisSummary._(
        video: session.metadata,
        decodedFrames: decodedFrames,
        framesWithDetections: framesWithDetections,
        detectionCounts: counts,
        tracks: tracking.tracks,
        framesWithTrackObservation: tracking.framesWithTrackObservation,
        ambiguousFrames: tracking.ambiguousFrames,
        truncated: !reachedEnd,
        selectionPrompt: tracking.tracks.isEmpty ? selectionPrompt : null,
        analyzedFrames: analyzedFrames,
      );
    } finally {
      runtime?.close();
      await session.close();
    }
  }
}

_TrackingSummary _trackFrames(
  List<_AnalyzedVideoFrame> frames, {
  int? selectionFrameIndex,
  DetectionObservation? selectedDetection,
}) {
  final tracker = ConservativeSingleTargetTracker(
    automaticAcquisition: selectionFrameIndex == null,
  );
  var observedFrames = 0;
  var ambiguousFrames = 0;
  final start = selectionFrameIndex ?? 0;
  for (var index = start; index < frames.length; index++) {
    final frame = frames[index];
    final update = tracker.update(
      capture: frame.capture,
      detections: frame.detections,
      selectedDetection: index == selectionFrameIndex
          ? selectedDetection
          : null,
    );
    if (update.observed != null) observedFrames++;
    if (update.state == VideoTrackState.ambiguous) ambiguousFrames++;
  }
  return _TrackingSummary(
    tracks: tracker.finish(),
    framesWithTrackObservation: observedFrames,
    ambiguousFrames: ambiguousFrames,
  );
}
