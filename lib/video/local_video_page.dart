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

  Future<void> selectAndAnalyze() async {
    setState(() {
      busy = true;
      message = null;
      summary = null;
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
      if (mounted) {
        setState(() {
          summary = result;
          busy = false;
        });
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
          'Bu ekran takip veya hız ölçmez. Sayısal hız göstermez ve algılama sayısı doğruluk anlamına gelmez.',
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
