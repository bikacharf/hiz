import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/measurement.dart';

const efficientDetLite0ModelVersion =
    'efficientdet-lite0-metadata-v1@sha256:'
    '2e04c53bfeac0ac2a30c057c7e2a777594ce39baaac35a92f74fb1e8c4fc4e0b';

const efficientDetInputSize = 320;
const efficientDetMaximumDetections = 25;

/// One decoded, upright RGB888 frame. The PTS must come from the source media,
/// never from the UI clock or an assumed frame rate.
class DecodedRgbFrame {
  DecodedRgbFrame({
    required this.rgb,
    required this.capture,
    this.rotationDegrees = 0,
  }) {
    require(
      rotationDegrees == 0 && rgb.length == capture.width * capture.height * 3,
      'Only complete, upright RGB888 frames are supported',
    );
  }

  final Uint8List rgb;
  final CaptureMetadata capture;
  final int rotationDegrees;
}

class DetectionFrame {
  DetectionFrame({
    required this.capture,
    required List<DetectionObservation> detections,
  }) : detections = List.unmodifiable(detections);

  final CaptureMetadata capture;
  final List<DetectionObservation> detections;
}

enum DetectorTensorType { uint8, float32 }

class DetectorTensorSpec {
  const DetectorTensorSpec(this.name, this.shape, this.type);

  final String name;
  final List<int> shape;
  final DetectorTensorType type;
}

class EfficientDetRawOutput {
  EfficientDetRawOutput({
    required this.boxes,
    required this.classes,
    required this.scores,
    required this.count,
  });

  final List<List<double>> boxes;
  final List<double> classes;
  final List<double> scores;
  final double count;
}

abstract interface class EfficientDetRuntime {
  DetectorTensorSpec get input;
  List<DetectorTensorSpec> get outputs;
  Future<EfficientDetRawOutput> run(Uint8List inputRgb);
  void close();
}

class LetterboxedRgb {
  LetterboxedRgb({
    required this.bytes,
    required this.scale,
    required this.padX,
    required this.padY,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final Uint8List bytes;
  final double scale;
  final int padX;
  final int padY;
  final int sourceWidth;
  final int sourceHeight;

  NormalizedBox? sourceBox(List<double> modelBox) {
    if (modelBox.length != 4 || modelBox.any((value) => !value.isFinite)) {
      throw const FormatException('Invalid EfficientDet box tensor');
    }
    final ymin = modelBox[0];
    final xmin = modelBox[1];
    final ymax = modelBox[2];
    final xmax = modelBox[3];
    if (ymax <= ymin || xmax <= xmin) {
      throw const FormatException('Inverted EfficientDet box');
    }

    final left = ((xmin * efficientDetInputSize) - padX) / scale;
    final top = ((ymin * efficientDetInputSize) - padY) / scale;
    final right = ((xmax * efficientDetInputSize) - padX) / scale;
    final bottom = ((ymax * efficientDetInputSize) - padY) / scale;
    final clippedLeft = left.clamp(0.0, sourceWidth.toDouble());
    final clippedTop = top.clamp(0.0, sourceHeight.toDouble());
    final clippedRight = right.clamp(0.0, sourceWidth.toDouble());
    final clippedBottom = bottom.clamp(0.0, sourceHeight.toDouble());
    if (clippedRight <= clippedLeft || clippedBottom <= clippedTop) return null;
    return NormalizedBox(
      clippedLeft / sourceWidth,
      clippedTop / sourceHeight,
      (clippedRight - clippedLeft) / sourceWidth,
      (clippedBottom - clippedTop) / sourceHeight,
    );
  }
}

/// Preserves aspect ratio and pads with black. Nearest-neighbour sampling is
/// deterministic and avoids a second image-processing dependency.
LetterboxedRgb letterboxRgb(DecodedRgbFrame frame) {
  final sourceWidth = frame.capture.width;
  final sourceHeight = frame.capture.height;
  final scale = math.min(
    efficientDetInputSize / sourceWidth,
    efficientDetInputSize / sourceHeight,
  );
  final resizedWidth = math.max(1, (sourceWidth * scale).round());
  final resizedHeight = math.max(1, (sourceHeight * scale).round());
  final padX = (efficientDetInputSize - resizedWidth) ~/ 2;
  final padY = (efficientDetInputSize - resizedHeight) ~/ 2;
  final output = Uint8List(efficientDetInputSize * efficientDetInputSize * 3);
  for (var y = 0; y < resizedHeight; y++) {
    final sourceY = math.min(sourceHeight - 1, (y / scale).floor());
    for (var x = 0; x < resizedWidth; x++) {
      final sourceX = math.min(sourceWidth - 1, (x / scale).floor());
      final sourceOffset = (sourceY * sourceWidth + sourceX) * 3;
      final outputOffset = ((y + padY) * efficientDetInputSize + x + padX) * 3;
      output[outputOffset] = frame.rgb[sourceOffset];
      output[outputOffset + 1] = frame.rgb[sourceOffset + 1];
      output[outputOffset + 2] = frame.rgb[sourceOffset + 2];
    }
  }
  return LetterboxedRgb(
    bytes: output,
    scale: scale,
    padX: padX,
    padY: padY,
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
  );
}

class EfficientDetLite0Adapter {
  EfficientDetLite0Adapter(this._runtime, {this.minimumScore = 0.35}) {
    require(
      minimumScore.isFinite && minimumScore >= 0 && minimumScore <= 1,
      'Invalid detection threshold',
    );
    _validateTensorContract();
  }

  final EfficientDetRuntime _runtime;
  final double minimumScore;

  Future<DetectionFrame> detect(DecodedRgbFrame frame) async {
    final prepared = letterboxRgb(frame);
    final raw = await _runtime.run(prepared.bytes);
    final detections = parseEfficientDetOutput(
      raw,
      transform: prepared,
      capture: frame.capture,
      minimumScore: minimumScore,
    );
    return DetectionFrame(capture: frame.capture, detections: detections);
  }

  void close() => _runtime.close();

  void _validateTensorContract() {
    final input = _runtime.input;
    if (input.name != 'serving_default_images:0' ||
        !_sameShape(input.shape, const [1, 320, 320, 3]) ||
        input.type != DetectorTensorType.uint8) {
      throw const FormatException('Unsupported EfficientDet input tensor');
    }
    const expectedNames = [
      'StatefulPartitionedCall:3',
      'StatefulPartitionedCall:2',
      'StatefulPartitionedCall:1',
      'StatefulPartitionedCall:0',
    ];
    const expectedShapes = [
      [1, 25, 4],
      [1, 25],
      [1, 25],
      [1],
    ];
    if (_runtime.outputs.length != expectedNames.length) {
      throw const FormatException('Unsupported EfficientDet output count');
    }
    for (var index = 0; index < expectedNames.length; index++) {
      final output = _runtime.outputs[index];
      if (output.name != expectedNames[index] ||
          !_sameShape(output.shape, expectedShapes[index]) ||
          output.type != DetectorTensorType.float32) {
        throw const FormatException('Unsupported EfficientDet output tensor');
      }
    }
  }
}

List<DetectionObservation> parseEfficientDetOutput(
  EfficientDetRawOutput output, {
  required LetterboxedRgb transform,
  required CaptureMetadata capture,
  required double minimumScore,
}) {
  if (!output.count.isFinite || output.count < 0 || output.count % 1 != 0) {
    throw const FormatException('Invalid EfficientDet detection count');
  }
  final count = output.count.toInt();
  if (count > efficientDetMaximumDetections ||
      output.boxes.length != efficientDetMaximumDetections ||
      output.classes.length != efficientDetMaximumDetections ||
      output.scores.length != efficientDetMaximumDetections ||
      output.boxes.any((box) => box.length != 4)) {
    throw const FormatException('Malformed EfficientDet output tensors');
  }

  final detections = <DetectionObservation>[];
  for (var index = 0; index < count; index++) {
    final score = output.scores[index];
    final classValue = output.classes[index];
    if (!score.isFinite || score < 0 || score > 1) {
      throw const FormatException('Invalid EfficientDet score');
    }
    if (!classValue.isFinite || classValue < 0 || classValue % 1 != 0) {
      throw const FormatException('Invalid EfficientDet class');
    }
    // Validate every active box before applying score/class filters. A corrupt
    // model result must fail closed instead of disappearing as a low-score or
    // unsupported detection.
    final box = transform.sourceBox(output.boxes[index]);
    if (score < minimumScore) continue;
    final targetClass = _targetForCocoIndex(classValue.toInt());
    if (targetClass == null) continue;
    if (box == null) continue;
    detections.add(
      DetectionObservation(
        capture: capture,
        target: Target(targetClass),
        box: box,
        score: score,
        modelVersion: efficientDetLite0ModelVersion,
      ),
    );
  }
  return List.unmodifiable(detections);
}

TargetClass? _targetForCocoIndex(int index) => switch (index) {
  0 => TargetClass.person,
  1 => TargetClass.bicycle,
  2 || 3 || 5 || 7 => TargetClass.vehicle,
  36 => TargetClass.ball,
  _ => null,
};

bool _sameShape(List<int> actual, List<int> expected) {
  if (actual.length != expected.length) return false;
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) return false;
  }
  return true;
}
