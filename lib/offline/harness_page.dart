import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'harness.dart';

class HarnessPage extends StatefulWidget {
  const HarnessPage({super.key});
  @override
  State<HarnessPage> createState() => _HarnessPageState();
}

class _HarnessPageState extends State<HarnessPage> {
  String? evidence;
  bool busy = false;
  Future<void> run() async {
    setState(() => busy = true);
    String result;
    try {
      final source = await rootBundle.loadString(
        'assets/fixtures/occlusion.json',
      );
      result = OfflineHarness().run(DetectionFixture.parse(source));
    } catch (_) {
      result = 'Sentetik test dosyası çalıştırılamadı.';
    }
    if (mounted) {
      setState(() {
        evidence = result;
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Çevrimdışı test düzeneği')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('M1 • Offline harness • Model bekleniyor'),
        const Text(
          'Yalnızca sentetik gözlemler işlenir. Gerçek algılama ve video içe aktarma henüz yok. Sayısal hız üretilmez.',
        ),
        const Text(
          'Bu senaryo kısa görünmezlikte takip kimliğini korur; hedef kaybından sonra yeni kimlik başlatır. Gerçek görüntü üzerinde takip başarısı kanıtlanmaz.',
        ),
        FilledButton(
          onPressed: busy ? null : run,
          child: const Text('Sentetik test senaryosunu çalıştır'),
        ),
        if (evidence != null) ...[
          const Text('Sentetik kare kanıtı • JSON Lines'),
          SelectableText(evidence!),
        ],
      ],
    ),
  );
}
