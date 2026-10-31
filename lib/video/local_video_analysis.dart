import '../detection/efficientdet_lite0.dart';
import '../domain/measurement.dart';
import 'local_video_source.dart';

class LocalVideoAnalysisSummary {
  LocalVideoAnalysisSummary({
    required this.video,
    required this.decodedFrames,
    required this.framesWithDetections,
    required Map<TargetClass, int> detectionCounts,
    required this.truncated,
  }) : detectionCounts = Map.unmodifiable(detectionCounts);

  final LocalVideoMetadata video;
  final int decodedFrames;
  final int framesWithDetections;
  final Map<TargetClass, int> detectionCounts;
  final bool truncated;
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
        truncated: !reachedEnd,
      );
    } finally {
      runtime?.close();
      await session.close();
    }
  }
}
