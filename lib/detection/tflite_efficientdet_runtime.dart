import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'efficientdet_lite0.dart';

const efficientDetLite0Asset =
    'assets/models/efficientdet_lite0_metadata_v1.tflite';

/// Mobile runtime only. Video decoding and frame scheduling remain outside this
/// adapter. The interpreter is deliberately not loaded by the prototype UI.
class TfliteEfficientDetRuntime implements EfficientDetRuntime {
  TfliteEfficientDetRuntime._(this._interpreter);

  final Interpreter _interpreter;

  static Future<TfliteEfficientDetRuntime> load() async {
    final options = InterpreterOptions()..threads = 2;
    try {
      final interpreter = await Interpreter.fromAsset(
        efficientDetLite0Asset,
        options: options,
      );
      return TfliteEfficientDetRuntime._(interpreter);
    } catch (error) {
      throw StateError('EfficientDet model could not be loaded: $error');
    } finally {
      options.delete();
    }
  }

  @override
  DetectorTensorSpec get input => _spec(_interpreter.getInputTensor(0));

  @override
  List<DetectorTensorSpec> get outputs =>
      List.unmodifiable(_interpreter.getOutputTensors().map(_spec));

  @override
  Future<EfficientDetRawOutput> run(Uint8List inputRgb) async {
    if (inputRgb.length != 320 * 320 * 3) {
      throw const FormatException('EfficientDet input byte count mismatch');
    }
    final boxes = [
      List.generate(25, (_) => List<double>.filled(4, 0), growable: false),
    ];
    final classes = [List<double>.filled(25, 0)];
    final scores = [List<double>.filled(25, 0)];
    final count = [0.0];
    try {
      _interpreter.runForMultipleInputs(
        [inputRgb],
        {0: boxes, 1: classes, 2: scores, 3: count},
      );
    } catch (error) {
      throw StateError('EfficientDet inference failed: $error');
    }
    return EfficientDetRawOutput(
      boxes: boxes.single,
      classes: classes.single,
      scores: scores.single,
      count: count.single,
    );
  }

  @override
  void close() => _interpreter.close();
}

DetectorTensorSpec _spec(Tensor tensor) {
  final type = switch (tensor.type) {
    TensorType.uint8 => DetectorTensorType.uint8,
    TensorType.float32 => DetectorTensorType.float32,
    _ => throw FormatException('Unsupported tensor type ${tensor.type}'),
  };
  return DetectorTensorSpec(tensor.name, tensor.shape, type);
}
