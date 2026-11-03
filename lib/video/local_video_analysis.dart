import '../detection/efficientdet_lite0.dart';
import '../domain/measurement.dart';
import '../tracking/single_target_iou_tracker.dart';
import 'local_video_source.dart';

class LocalVideoAnalysisSummary {
  LocalVideoAnalysisSummary({
    required this.video,
    required this.decodedFrames,
    required this.framesWithDetections,
    required Map<TargetClass, int> detectionCounts,
    required List<VideoTrackSummary> tracks,
    required this.framesWithTrackObservation,
    required this.ambiguousFrames,
    required this.truncated,
  }) : detectionCounts = Map.unmodifiable(detectionCounts),
       tracks = List.unmodifiable(tracks);

  final LocalVideoMetadata video;
  final int decodedFrames;
  final int framesWithDetections;
  final Map<TargetClass, int> detectionCounts;
  final List<VideoTrackSummary> tracks;
  final int framesWithTrackObservation;
  final int ambiguousFrames;
  final bool truncated;

  VideoTrackSummary? get longestTrack => tracks.isEmpty
      ? null
      : tracks.reduce(
          (current, candidate) =>
              candidate.observedFrames > current.observedFrames
              ? candidate
              : current,
        );
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
    var framesWithTrackObservation = 0;
    var ambiguousFrames = 0;
    var reachedEnd = false;
    final counts = <TargetClass, int>{};
    final tracker = ConservativeSingleTargetTracker();
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
        final tracking = tracker.update(
          capture: frame.capture,
          detections: result.detections,
        );
        if (tracking.observed != null) framesWithTrackObservation++;
        if (tracking.state == VideoTrackState.ambiguous) ambiguousFrames++;
        for (final detection in result.detections) {
          counts.update(
            detection.target.kind,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
      return LocalVideoAnalysisSummary(
        video: session.metadata,
        decodedFrames: decodedFrames,
        framesWithDetections: framesWithDetections,
        detectionCounts: counts,
        tracks: tracker.finish(),
        framesWithTrackObservation: framesWithTrackObservation,
        ambiguousFrames: ambiguousFrames,
        truncated: !reachedEnd,
      );
    } finally {
      runtime?.close();
      await session.close();
    }
  }
}
