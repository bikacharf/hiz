/// M0 contracts only. No implementation claims camera or measurement support.
enum TargetClass { person, bicycle, vehicle, ball }

enum BallSubtype { football, basketball, tennis }

enum QualityBand { unavailable, poor, acceptable }

class Target {
  Target(this.kind, {this.ballSubtype}) {
    if ((kind == TargetClass.ball) != (ballSubtype != null)) {
      throw ArgumentError('Only balls require a subtype');
    }
  }
  final TargetClass kind;
  final BallSubtype? ballSubtype;
}

class CaptureMetadata {
  CaptureMetadata({
    required this.timestampUs,
    required this.lensId,
    required this.zoom,
    required this.width,
    required this.height,
  }) {
    if (timestampUs < 0 ||
        lensId.isEmpty ||
        !zoom.isFinite ||
        zoom <= 0 ||
        width <= 0 ||
        height <= 0) {
      throw ArgumentError('Invalid capture metadata');
    }
  }

  /// Monotonic timestamp from native capture metadata, never UI frame timing.
  final int timestampUs;
  final String lensId;
  final double zoom;
  final int width;
  final int height;
}

class NormalizedBox {
  NormalizedBox(this.x, this.y, this.width, this.height) {
    if (![x, y, width, height].every((v) => v.isFinite) ||
        x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width > 1 ||
        y + height > 1) {
      throw ArgumentError('Box must fit normalized image coordinates');
    }
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
    if (!score.isFinite || score < 0 || score > 1 || modelVersion.isEmpty) {
      throw ArgumentError('Invalid detector provenance or score');
    }
  }
  final CaptureMetadata capture;
  final Target target;
  final NormalizedBox box;

  /// Detector score, not measurement accuracy.
  final double score;
  final String modelVersion;
}

class TrackingObservation {
  TrackingObservation({
    required this.trackId,
    required this.detection,
    required this.missedFrames,
  }) {
    if (trackId.isEmpty || missedFrames < 0)
      throw ArgumentError('Invalid track');
  }
  final String trackId;
  final DetectionObservation detection;
  final int missedFrames;
}

class QualitySignals {
  QualitySignals({
    required this.targetPixels,
    required this.durationUs,
    required this.blurAcceptable,
    required this.occlusionAcceptable,
    required this.angleAcceptable,
    required this.cameraStable,
    required this.modelSupported,
    required this.lensUnchanged,
  }) {
    if (!targetPixels.isFinite || targetPixels < 0 || durationUs < 0) {
      throw ArgumentError('Invalid quality evidence');
    }
  }
  final double targetPixels;
  final int durationUs;
  final bool blurAcceptable,
      occlusionAcceptable,
      angleAcceptable,
      cameraStable,
      modelSupported,
      lensUnchanged;
}

class QualityDecision {
  QualityDecision(this.band, Iterable<String> failures)
    : failures = List.unmodifiable(failures);
  final QualityBand band;
  final List<String> failures;
}

/// Provisional engineering thresholds, not validated accuracy bounds.
class QualityGate implements QualityEvaluator {
  @override
  QualityDecision evaluate(QualitySignals s) {
    final failures = <String>[
      if (!s.modelSupported) 'unsupportedModel',
      if (!s.lensUnchanged) 'lensOrZoomChanged',
      if (s.targetPixels < 80) 'targetTooSmall',
      if (s.durationUs < 1000000) 'trackTooShort',
      if (!s.blurAcceptable) 'blur',
      if (!s.occlusionAcceptable) 'occlusion',
      if (!s.angleAcceptable) 'viewAngle',
      if (!s.cameraStable) 'cameraMotion',
    ];
    return QualityDecision(
      failures.isEmpty ? QualityBand.acceptable : QualityBand.unavailable,
      failures,
    );
  }
}

class ScaleHypothesis {
  ScaleHypothesis({
    required this.method,
    required this.metersPerPixel,
    required this.uncertainty,
    required Iterable<String> assumptions,
  }) : assumptions = List.unmodifiable(assumptions) {
    if (method.isEmpty ||
        this.assumptions.isEmpty ||
        !metersPerPixel.isFinite ||
        metersPerPixel <= 0 ||
        !uncertainty.isFinite ||
        uncertainty < 0) {
      throw ArgumentError('Invalid scale hypothesis');
    }
  }
  final String method;
  final double metersPerPixel, uncertainty;
  final List<String> assumptions;
}

class EvidenceRecord {
  EvidenceRecord({
    required this.id,
    required this.capture,
    required this.stage,
    required this.buildVersion,
    required Map<String, double> values,
  }) : values = Map.unmodifiable(values) {
    if (id.isEmpty ||
        stage.isEmpty ||
        buildVersion.isEmpty ||
        values.entries.any((e) => e.key.isEmpty || !e.value.isFinite)) {
      throw ArgumentError('Invalid evidence');
    }
  }
  final String id, stage, buildVersion;
  final CaptureMetadata capture;
  final Map<String, double> values;
}

class MeasurementCandidate {
  MeasurementCandidate({
    required this.trackId,
    required this.target,
    required this.start,
    required this.end,
    required this.scale,
    required this.quality,
    required this.signals,
    required this.modelVersion,
    required this.buildVersion,
    required Iterable<EvidenceRecord> evidence,
    required Iterable<String> limitations,
  }) : evidence = List.unmodifiable(evidence),
       limitations = List.unmodifiable(limitations) {
    if (trackId.isEmpty ||
        end.timestampUs <= start.timestampUs ||
        start.lensId != end.lensId ||
        start.zoom != end.zoom ||
        modelVersion.isEmpty ||
        buildVersion.isEmpty ||
        this.evidence.isEmpty ||
        this.limitations.isEmpty)
      throw ArgumentError('Incomplete candidate evidence');
  }
  final String trackId, modelVersion, buildVersion;
  final Target target;
  final CaptureMetadata start, end;
  final ScaleHypothesis scale;
  final QualityDecision quality;
  final QualitySignals signals;
  final List<EvidenceRecord> evidence;
  final List<String> limitations;

  /// M0 has no validated method. Quality alone never enables a numeric speed.
  double? get estimatedMetersPerSecond => null;
}

abstract interface class CaptureSource {
  Stream<CaptureMetadata> get frames;
}

abstract interface class Detector {
  Future<List<DetectionObservation>> detect(CaptureMetadata capture);
}

abstract interface class Tracker {
  List<TrackingObservation> update(List<DetectionObservation> detections);
  void reset();
}

abstract interface class CameraMotionEstimator {
  Future<bool?> isStable(CaptureMetadata capture);
}

abstract interface class ScaleEstimator {
  ScaleHypothesis? estimate(TrackingObservation observation);
}

abstract interface class SpeedEstimator {
  MeasurementCandidate? estimate(List<TrackingObservation> track);
}

abstract interface class QualityEvaluator {
  QualityDecision evaluate(QualitySignals signals);
}

abstract interface class EvidenceLogger {
  Future<void> record(EvidenceRecord record);
}
