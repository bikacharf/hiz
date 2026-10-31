import 'package:flutter/material.dart';

void main() => runApp(const HizApp());

class HizApp extends StatelessWidget {
  const HizApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hız Ölçer',
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF77EAC1),
    ),
    initialRoute: '/',
    routes: {
      '/': (_) => const ShellPage(title: 'Hız Ölçer'),
      '/camera': (_) => const ShellPage(title: 'Kamera'),
      '/history': (_) => const ShellPage(title: 'Geçmiş'),
      '/profile': (_) => const ShellPage(title: 'Profil'),
    },
  );
}

class ShellPage extends StatelessWidget {
  const ShellPage({required this.title, super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('M0 • İşlevsiz arayüz prototipi'),
        const SizedBox(height: 16),
        const Text(
          'Kamera, algılama, takip ve hız ölçümü henüz uygulanmadı. Sayısal hız gösterilmez.',
        ),
        const SizedBox(height: 24),
        const Text('Telefonu yolun yanında, hareket yönüne dik tut'),
        const Text('Telefonu sabit tut, mümkünse tripod kullan'),
        const Text('Nesnenin tamamı ekranda görünsün'),
        const Text('Güvenli mesafeden ölç, yola girme.'),
        for (final entry in const {
          '/camera': 'Kamera',
          '/history': 'Geçmiş',
          '/profile': 'Profil',
        }.entries)
          TextButton(
            onPressed: () => Navigator.pushNamed(context, entry.key),
            child: Text(entry.value),
          ),
      ],
    ),
  );
}
