import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../detection/efficientdet_lite0.dart';
import '../detection/tflite_efficientdet_runtime.dart';
import '../domain/measurement.dart';
import 'local_video_analysis.dart';
import 'local_video_source.dart';

class LocalVideoPage extends StatefulWidget {
  const LocalVideoPage({super.key, this.source, this.runtimeFactory});

  final LocalVideoSource? source;
  final Future<EfficientDetRuntime> Function()? runtimeFactory;

  @override
  State<LocalVideoPage> createState() => _LocalVideoPageState();
}

class _LocalVideoPageState extends State<LocalVideoPage> {
  bool busy = false;
  String? message;
  LocalVideoAnalysisSummary? summary;
  ui.Image? selectionImage;

  Future<void> selectAndAnalyze() async {
    setState(() {
      busy = true;
      message = null;
      summary = null;
      selectionImage?.dispose();
      selectionImage = null;
    });
    final source = widget.source ?? MethodChannelLocalVideoSource();
    try {
      final selection = await source.pickVideo();
      if (selection == null) {
        if (mounted) setState(() => busy = false);
        return;
      }
      final session = await source.open(selection);
      final analyzer = LocalVideoAnalyzer(
        runtimeFactory: widget.runtimeFactory ?? TfliteEfficientDetRuntime.load,
      );
      final result = await analyzer.analyze(session);
      final image = result.selectionPrompt == null
          ? null
          : await _decodeRgb(result.selectionPrompt!);
      if (mounted) {
        setState(() {
          summary = result;
          selectionImage = image;
          busy = false;
        });
      } else {
        image?.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          message = 'Video çözülemedi veya model çalıştırılamadı. Dosyayı değiştirip tekrar dene.';
          busy = false;
        });
      }
    }
  }

  void selectCandidate(int index) {
    final result = summary;
    if (result == null) return;
    final selected = result.selectCandidate(index);
    setState(() {
      summary = selected;
      selectionImage?.dispose();
      selectionImage = null;
    });
  }

  Future<void> selectCandidateAt(
    LocalVideoSelectionPrompt prompt,
    Offset position,
    Size previewSize,
  ) async {
    final matches = prompt.candidateIndexesAt(
      normalizedX: position.dx / previewSize.width,
      normalizedY: position.dy / previewSize.height,
    );
    if (matches.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seçmek için bir kutunun içine dokun.')),
      );
      return;
    }
    if (matches.length == 1) {
      selectCandidate(matches.single);
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Üst üste gelen nesneler'),
              subtitle: Text('Takip etmek istediğin nesneyi seç.'),
            ),
            for (final index in matches)
              ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(
                  '${_targetLabel(prompt.candidates[index].target.kind)} '
                  '%${(prompt.candidates[index].score * 100).round()}',
                ),
                onTap: () => Navigator.pop(context, index),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) selectCandidate(selected);
  }

  @override
  void dispose() {
    selectionImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yerel video analizi')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('M1 • Gerçek video giriş prototipi'),
        const SizedBox(height: 12),
        const Text(
          'Seçtiğin video yalnızca cihazda işlenir. İlk 120 karede insan, bisiklet, araç ve top algılamaları aranır.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Bu ekran basit deneysel takip yapar; takip kimlikleri henüz gerçek nesne doğruluğu bakımından doğrulanmadı. Sayısal hız göstermez.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : selectAndAnalyze,
          child: Text(busy ? 'Video işleniyor…' : 'Telefondan video seç'),
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (message != null) ...[const SizedBox(height: 16), Text(message!)],
        if (summary case final result?) ...[
          const SizedBox(height: 24),
          Text(result.video.displayName),
          Text('Çözülen kare: ${result.decodedFrames}'),
          Text('Algılama bulunan kare: ${result.framesWithDetections}'),
          if (result.truncated)
            const Text('Prototip sınırı nedeniyle ilk 120 kare işlendi.'),
          const SizedBox(height: 12),
          for (final target in TargetClass.values)
            Text('${_label(target)}: ${result.detectionCounts[target] ?? 0}'),
          const SizedBox(height: 16),
          if (result.selectionPrompt case final prompt?) ...[
            const Text(
              'Takip edilecek nesneyi seç',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Görüntüde takip etmek istediğin kutuya dokun. Alttaki numaralı düğmeleri de kullanabilirsin. Önizleme yalnızca cihaz belleğinde tutulur.',
            ),
            const SizedBox(height: 12),
            if (selectionImage case final image?)
              AspectRatio(
                aspectRatio: prompt.capture.width / prompt.capture.height,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final previewSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => selectCandidateAt(
                        prompt,
                        details.localPosition,
                        previewSize,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RawImage(image: image, fit: BoxFit.fill),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CandidateBoxPainter(prompt.candidates),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < prompt.candidates.length; index++)
                  FilledButton.tonal(
                    onPressed: () => selectCandidate(index),
                    child: Text(
                      '${index + 1} • ${_targetLabel(prompt.candidates[index].target.kind)} '
                      '%${(prompt.candidates[index].score * 100).round()}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Text('Oluşturulan deneysel takip: ${result.tracks.length}'),
          Text('Takip edilen kare: ${result.framesWithTrackObservation}'),
          Text('Belirsiz eşleşme karesi: ${result.ambiguousFrames}'),
          if (result.longestTrack case final track?)
            Text(
              'En uzun takip: ${_targetLabel(track.targetClass)}, '
              '${track.observedFrames} algılanan kare',
            ),
          const Text(
            'Takip sınırı: yalnızca kutu örtüşmesi; hareket tahmini ve yeniden tanıma yok.',
          ),
          const SizedBox(height: 16),
          const Text('Hız sonucu: kullanılamıyor'),
        ],
      ],
    ),
  );
}

String _label(TargetClass target) => switch (target) {
  TargetClass.person => 'İnsan algılaması',
  TargetClass.bicycle => 'Bisiklet algılaması',
  TargetClass.vehicle => 'Araç algılaması',
  TargetClass.ball => 'Top algılaması',
};

Future<ui.Image> _decodeRgb(LocalVideoSelectionPrompt prompt) async {
  final rgba = Uint8List(prompt.capture.width * prompt.capture.height * 4);
  for (var source = 0, target = 0; source < prompt.rgb.length;) {
    rgba[target++] = prompt.rgb[source++];
    rgba[target++] = prompt.rgb[source++];
    rgba[target++] = prompt.rgb[source++];
    rgba[target++] = 255;
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: prompt.capture.width,
    height: prompt.capture.height,
    rowBytes: prompt.capture.width * 4,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  try {
    final codec = await descriptor.instantiateCodec();
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}

class _CandidateBoxPainter extends CustomPainter {
  _CandidateBoxPainter(this.candidates);

  final List<DetectionObservation> candidates;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff8edbc1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (var index = 0; index < candidates.length; index++) {
      final box = candidates[index].box;
      final rect = Rect.fromLTWH(
        box.x * size.width,
        box.y * size.height,
        box.width * size.width,
        box.height * size.height,
      );
      canvas.drawRect(rect, paint);
      final label = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: const TextStyle(
            color: Colors.black,
            backgroundColor: Color(0xff8edbc1),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, rect.topLeft);
    }
  }

  @override
  bool shouldRepaint(covariant _CandidateBoxPainter oldDelegate) =>
      oldDelegate.candidates != candidates;
}

String _targetLabel(TargetClass target) => switch (target) {
  TargetClass.person => 'insan',
  TargetClass.bicycle => 'bisiklet',
  TargetClass.vehicle => 'araç',
  TargetClass.ball => 'top',
};
