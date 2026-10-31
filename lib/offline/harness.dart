import 'dart:convert';
import 'dart:math' as math;

import '../domain/measurement.dart';

/// Synthetic observations only. This is not a detector or video decoder.
class FixtureDetection {
  FixtureDetection(this.id, this.label, this.box, this.score, this.model);
  final String id, label, model;
  final NormalizedBox box;
  final double score;
  TargetClass? get kind => switch (label) {
    'person' => TargetClass.person,
    'bicycle' => TargetClass.bicycle,
    'vehicle' || 'car' => TargetClass.vehicle,
    'ball' => TargetClass.ball,
    _ => null,
  };
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'class': kind?.name,
    'box': [box.x, box.y, box.width, box.height],
    'score': score,
    'modelVersion': model,
  };
}

class FixtureFrame {
  FixtureFrame(this.capture, List<FixtureDetection> detections, this.selection)
    : detections = List.unmodifiable(detections);
  final CaptureMetadata capture;
  final List<FixtureDetection> detections;
  final String? selection;
}

class DetectionFixture {
  DetectionFixture._(this.id, List<FixtureFrame> frames)
    : frames = List.unmodifiable(frames);
  final String id;
  final List<FixtureFrame> frames;

  factory DetectionFixture.parse(String source) {
    try {
      final root = jsonDecode(source) as Map<String, dynamic>;
      require(
        root['schemaVersion'] == 1 && root['origin'] == 'synthetic',
        'Only schema 1 synthetic fixtures are accepted',
      );
      final id = root['fixtureId'] as String;
      require(id.isNotEmpty, 'Fixture ID required');
      final frames = <FixtureFrame>[];
      for (final value in root['frames'] as List) {
        final f = value as Map<String, dynamic>;
        final c = f['capture'] as Map<String, dynamic>;
        final capture = CaptureMetadata(
          timestampUs: c['timestampUs'] as int,
          lensId: c['lensId'] as String,
          zoom: (c['zoom'] as num).toDouble(),
          width: c['width'] as int,
          height: c['height'] as int,
        );
        require(
          frames.isEmpty ||
              capture.timestampUs > frames.last.capture.timestampUs,
          'Capture timestamps must strictly increase',
        );
        final detections = <FixtureDetection>[];
        final ids = <String>{};
        for (final value in f['detections'] as List) {
          final d = value as Map<String, dynamic>;
          final id = d['id'] as String;
          final label = d['label'] as String;
          final model = d['modelVersion'] as String;
          final score = (d['score'] as num).toDouble();
          require(
            id.isNotEmpty &&
                ids.add(id) &&
                label.isNotEmpty &&
                model.isNotEmpty &&
                score.isFinite &&
                score >= 0 &&
                score <= 1,
            'Invalid observation',
          );
          final b = (d['box'] as List).cast<num>();
          require(b.length == 4, 'Four normalized box coordinates required');
          detections.add(
            FixtureDetection(
              id,
              label,
              NormalizedBox(
                b[0].toDouble(),
                b[1].toDouble(),
                b[2].toDouble(),
                b[3].toDouble(),
              ),
              score,
              model,
            ),
          );
        }
        final selection = f['selectDetectionId'] as String?;
        require(
          selection == null || ids.contains(selection),
          'Selection must exist in frame',
        );
        frames.add(FixtureFrame(capture, detections, selection));
      }
      require(frames.isNotEmpty, 'At least one frame required');
      return DetectionFixture._(id, frames);
    } catch (error) {
      throw FormatException('Invalid detection fixture: $error');
    }
  }
}

enum TrackState {
  acquired,
  tracked,
  occluded,
  lost,
  ambiguous,
  unsupported,
  classChanged,
  opticsChanged,
  waiting,
}

/// Conservative single-target association, not validated real-world tracking.
/// No prediction, interpolation, scale, or speed is produced.
class OfflineHarness {
  OfflineHarness({this.maxMissedFrames = 2, this.minimumIou = .2}) {
    require(
      maxMissedFrames >= 0 &&
          minimumIou.isFinite &&
          minimumIou > 0 &&
          minimumIou <= 1,
      'Invalid association policy',
    );
  }
  final int maxMissedFrames;
  final double minimumIou;

  /// Fresh state for every run, including runs on the same harness instance.
  String run(DetectionFixture fixture) {
    String? trackId;
    FixtureDetection? last;
    CaptureMetadata? previous;
    int? lastObservedUs;
    var serial = 0;
    var missed = 0;
    final lines = <String>[];
    for (var index = 0; index < fixture.frames.length; index++) {
      final frame = fixture.frames[index];
      final capture = frame.capture;
      final supported = frame.detections.where((d) => d.kind != null).toList();
      final unsupported = frame.detections
          .where((d) => d.kind == null)
          .map((d) => d.id)
          .toList();
      TrackState state;
      String? reason;
      String? endedTrackId;
      FixtureDetection? observed;
      final opticsChanged =
          previous != null &&
          (capture.lensId != previous.lensId ||
              capture.zoom != previous.zoom ||
              capture.width != previous.width ||
              capture.height != previous.height);
      if (opticsChanged) {
        state = TrackState.opticsChanged;
        reason = 'captureGeometryChanged';
        endedTrackId = trackId;
        trackId = null;
        last = null;
        missed = 0;
        lastObservedUs = null;
      } else {
        final selection = frame.selection;
        if (selection != null) {
          final selected = frame.detections.singleWhere(
            (d) => d.id == selection,
          );
          if (selected.kind == null) {
            state = TrackState.unsupported;
            reason = 'selectedClassUnsupported';
            // Explicit selection terminates the previous target, even if unsupported.
            endedTrackId = trackId;
            trackId = null;
            last = null;
            lastObservedUs = null;
            missed = 0;
          } else {
            endedTrackId = trackId;
            trackId = '${fixture.id}:track-${++serial}';
            observed = selected;
            state = TrackState.acquired;
            reason = 'explicitSelection';
          }
        } else if (trackId == null) {
          if (supported.length == 1) {
            observed = supported.single;
            trackId = '${fixture.id}:track-${++serial}';
            state = TrackState.acquired;
          } else {
            state = supported.length > 1
                ? TrackState.ambiguous
                : unsupported.isNotEmpty
                ? TrackState.unsupported
                : TrackState.waiting;
            reason = supported.length > 1
                ? 'selectionRequired'
                : 'noSupportedTarget';
          }
        } else {
          final matches = frame.detections
              .where((d) => _iou(last!.box, d.box) >= minimumIou)
              .toList();
          if (matches.length > 1) {
            state = TrackState.ambiguous;
            reason = 'multipleSpatialMatches';
          } else if (matches.length == 1 && matches.single.kind != last!.kind) {
            state = matches.single.kind == null
                ? TrackState.unsupported
                : TrackState.classChanged;
            reason = 'targetClassChanged';
            endedTrackId = trackId;
            trackId = null;
            last = null;
            lastObservedUs = null;
            missed = 0;
          } else if (matches.length == 1) {
            observed = matches.single;
            state = TrackState.tracked;
          } else {
            state = unsupported.isNotEmpty
                ? TrackState.unsupported
                : TrackState.occluded;
            reason = 'noSpatialMatch';
          }
          if (observed == null && trackId != null) {
            missed++;
            if (missed > maxMissedFrames) {
              state = TrackState.lost;
              reason = 'missBudgetExceeded';
              endedTrackId = trackId;
              trackId = null;
              last = null;
              lastObservedUs = null;
            }
          }
        }
      }
      if (observed != null) {
        last = observed;
        lastObservedUs = capture.timestampUs;
        missed = 0;
      }
      lines.add(
        jsonEncode({
          'schemaVersion': 1,
          'fixtureId': fixture.id,
          'origin': 'synthetic',
          'harnessVersion': 'offline-iou-v1',
          'frameIndex': index,
          'capture': {
            'timestampUs': capture.timestampUs,
            'lensId': capture.lensId,
            'zoom': capture.zoom,
            'width': capture.width,
            'height': capture.height,
          },
          'policy': {
            'minimumIou': minimumIou,
            'maxMissedFrames': maxMissedFrames,
          },
          'inputDetections': frame.detections.map((d) => d.toJson()).toList(),
          'selection': frame.selection,
          'unsupportedDetectionIds': unsupported,
          'state': state.name,
          'reason': reason,
          'trackId': trackId,
          'endedTrackId': endedTrackId,
          'missedFrames': missed,
          'observedDetectionId': observed?.id,
          'lastObservedTimestampUs': lastObservedUs,
          'measurementAvailable': false,
          'limitations': [
            'syntheticObservationsOnly',
            'modelLicensePending',
            'videoDecoderNotIntegrated',
            'noSpeed',
          ],
        }),
      );
      previous = capture;
    }
    return '${lines.join('\n')}\n';
  }
}

double _iou(NormalizedBox a, NormalizedBox b) {
  final w = math.max(
    0.0,
    math.min(a.x + a.width, b.x + b.width) - math.max(a.x, b.x),
  );
  final h = math.max(
    0.0,
    math.min(a.y + a.height, b.y + b.height) - math.max(a.y, b.y),
  );
  final intersection = w * h;
  return intersection /
      (a.width * a.height + b.width * b.height - intersection);
}
