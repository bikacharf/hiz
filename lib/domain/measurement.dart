enum TargetClass { person, bicycle, vehicle, ball }

enum BallType { football, basketball, tennis }

enum QualityBand { unavailable, low, sufficient }

void require(bool condition, String message) {
  if (!condition) throw ArgumentError(message);
}

class Target {
  Target(this.kind, {this.ballType}) {
    require(
      (kind == TargetClass.ball) == (ballType != null),
      'Only balls require a subtype',
    );
  }
  final TargetClass kind;
  final BallType? ballType;
}

class CaptureMetadata {
  CaptureMetadata({
    required this.timestampUs,
    required this.lensId,
    required this.zoom,
    required this.width,
    required this.height,
  }) {
    require(
      timestampUs >= 0 &&
          lensId.isNotEmpty &&
          zoom.isFinite &&
          zoom > 0 &&
          width > 0 &&
          height > 0,
      'Invalid capture metadata',
    );
  }

  /// Monotonic capture metadata time; never UI frame time.
  final int timestampUs;
  final String lensId;
  final double zoom;
  final int width;
  final int height;
}

class NormalizedBox {
  NormalizedBox(this.x, this.y, this.width, this.height) {
    require(
      [x, y, width, height].every((v) => v.isFinite) &&
          x >= 0 &&
          y >= 0 &&
          width > 0 &&
          height > 0 &&
          x + width <= 1 &&
          y + height <= 1,
      'Box must be inside the normalized image',
    );
  }
  final double x, y, width, height;
}

class DetectionObservation {
  DetectionObservation({
    required this.capture,
    required this.target,
    required this.box,
    required this.score,
    required this.modelVersion,
  }) {
    require(
      score.isFinite && score >= 0 && score <= 1 && modelVersion.isNotEmpty,
      'Invalid detection provenance',
    );
  }
  final CaptureMetadata capture;
  final Target target;
  final NormalizedBox box;
  final double score;
  final String modelVersion;
}

class TrackingObservation {
  TrackingObservation({
    required this.trackId,
    required List<DetectionObservation> observations,
    required this.missedFrames,
  }) : observations = List.unmodifiable(observations) {
    require(
      trackId.isNotEmpty && observations.isNotEmpty && missedFrames >= 0,
      'Invalid track',
    );
    for (var i = 1; i < observations.length; i++) {
      require(
        observations[i].target.kind == observations[0].target.kind &&
            observations[i].target.ballType == observations[0].target.ballType,
        'Target class must remain stable within a track',
      );
      require(
        observations[i].capture.timestampUs >
            observations[i - 1].capture.timestampUs,
        'Capture timestamps must increase',
      );
      require(
        observations[i].capture.lensId == observations[0].capture.lensId &&
            observations[i].capture.zoom == observations[0].capture.zoom,
        'Lens or zoom change requires a new track',
      );
    }
  }
  final String trackId;
  final List<DetectionObservation> observations;
  final int missedFrames;
}

enum QualityGate {
  targetSize,
  blur,
  occlusion,
  viewAngle,
  cameraMotion,
  trackDuration,
  modelSupport,
}

/// Observable evidence, not inferred accuracy. Unknown values remain null.
class QualityMetrics {
  QualityMetrics({
    this.targetPixels,
    this.trackDurationUs,
    this.blur,
    this.occlusion,
    this.cameraMotion,
    this.viewAngleDegrees,
  }) {
    require(
      targetPixels == null || (targetPixels!.isFinite && targetPixels! > 0),
      'Invalid target size',
    );
    require(
      trackDurationUs == null || trackDurationUs! >= 0,
      'Invalid duration',
    );
    for (final value in [blur, occlusion, cameraMotion]) {
      require(
        value == null || (value.isFinite && value >= 0 && value <= 1),
        'Normalized signal must be between zero and one',
      );
    }
    require(
      viewAngleDegrees == null ||
          (viewAngleDegrees!.isFinite &&
              viewAngleDegrees! >= 0 &&
              viewAngleDegrees! <= 180),
      'Invalid angle',
    );
  }
  final double? targetPixels, blur, occlusion, cameraMotion, viewAngleDegrees;
  final int? trackDurationUs;
}

class QualitySignals {
  QualitySignals(Map<QualityGate, bool?> gates, {this.metrics})
    : gates = Map.unmodifiable(gates);
  final QualityMetrics? metrics;

  /// null or absent means unknown; unknown never passes.
  final Map<QualityGate, bool?> gates;
  List<QualityGate> get failures => QualityGate.values
      .where((gate) => gates[gate] != true)
      .toList(growable: false);
  QualityBand get band =>
      failures.isEmpty ? QualityBand.sufficient : QualityBand.unavailable;
}

class ScaleHypothesis {
  ScaleHypothesis({
    required this.method,
    required this.metersPerPixel,
    required this.uncertainty,
    required List<String> assumptions,
  }) : assumptions = List.unmodifiable(assumptions) {
    require(
      method.isNotEmpty &&
          metersPerPixel.isFinite &&
          metersPerPixel > 0 &&
          uncertainty.isFinite &&
          uncertainty >= 0 &&
          assumptions.isNotEmpty,
      'Invalid scale hypothesis',
    );
  }
  final String method;
  final double metersPerPixel, uncertainty;
  final List<String> assumptions;
}

class MeasurementCandidate {
  MeasurementCandidate({
    required this.track,
    required this.quality,
    required this.buildVersion,
    required List<String> limitations,
    this.scale,
    this.metersPerSecond,
  }) : limitations = List.unmodifiable(limitations) {
    require(
      buildVersion.isNotEmpty && limitations.isNotEmpty,
      'Provenance required',
    );
    if (metersPerSecond != null) {
      require(
        metersPerSecond!.isFinite &&
            metersPerSecond! >= 0 &&
            scale != null &&
            quality.band == QualityBand.sufficient &&
            track.observations.length >= 2,
        'Insufficient measurement evidence',
      );
    }
  }
  final TrackingObservation track;
  final QualitySignals quality;
  final String buildVersion;
  final List<String> limitations;
  final ScaleHypothesis? scale;
  final double? metersPerSecond;
}

class EvidenceRecord {
  EvidenceRecord({
    required this.id,
    required this.candidate,
    required List<String> intermediateReferences,
  }) : intermediateReferences = List.unmodifiable(intermediateReferences) {
    require(
      id.isNotEmpty && intermediateReferences.isNotEmpty,
      'Trace references required',
    );
  }
  final String id;
  final MeasurementCandidate candidate;
  final List<String> intermediateReferences;
}

/// An opaque, device-local buffer handle. Native owner controls its lifetime.
class CapturedFrame {
  CapturedFrame({required this.metadata, required this.nativeBufferId}) {
    require(nativeBufferId.isNotEmpty, 'Native buffer reference required');
  }
  final CaptureMetadata metadata;
  final String nativeBufferId;
}

class CameraMotionObservation {
  CameraMotionObservation({
    required this.capture,
    required this.method,
    this.normalizedMotion,
  }) {
    require(method.isNotEmpty, 'Motion method required');
    require(
      normalizedMotion == null ||
          (normalizedMotion!.isFinite &&
              normalizedMotion! >= 0 &&
              normalizedMotion! <= 1),
      'Invalid motion signal',
    );
  }
  final CaptureMetadata capture;
  final String method;
  final double? normalizedMotion;
}

abstract interface class CaptureSource {
  Stream<CapturedFrame> get frames;
  Future<void> stop();
}

abstract interface class Detector {
  Future<List<DetectionObservation>> detect(CapturedFrame frame);
}

abstract interface class Tracker {
  TrackingObservation update(List<DetectionObservation> detections);
}

abstract interface class CameraMotionEstimator {
  Future<CameraMotionObservation> motion(CapturedFrame frame);
}

abstract interface class ScaleEstimator {
  ScaleHypothesis? estimate(TrackingObservation track);
}

abstract interface class SpeedEstimator {
  MeasurementCandidate estimate(
    TrackingObservation track,
    QualitySignals quality,
  );
}

abstract interface class QualityEvaluator {
  QualitySignals evaluate(TrackingObservation track);
}

abstract interface class EvidenceLogger {
  Future<void> append(EvidenceRecord record);
}
