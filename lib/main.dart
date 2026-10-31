import 'package:flutter/material.dart';

void main() => runApp(const HizApp());

class HizApp extends StatelessWidget {
  const HizApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hız Ölçer',
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF80EAC5),
      scaffoldBackgroundColor: const Color(0xFF101C1A),
      useMaterial3: true,
    ),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int selected = 0;
  static const titles = ['Kamera', 'Geçmiş', 'Profil'];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Hız Ölçer · ${titles[selected]}')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Chip(label: Text('M0 · İşlevsel olmayan prototip')),
            const SizedBox(height: 32),
            Icon(
              [
                Icons.camera_alt_outlined,
                Icons.history,
                Icons.person_outline,
              ][selected],
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              [
                'Kamera henüz bağlı değil. Algılama, takip ve hız ölçümü kullanılamıyor.',
                'Henüz kayıt yok. Oturum kaydetme ve tekrar oynatma bu prototipte kullanılamıyor.',
                'Yerel prototip. Hesap, abonelik ve satın alma işlevleri kullanılamıyor.',
              ][selected],
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (selected == 0) ...[
              const SizedBox(height: 24),
              const Text(
                'Telefonu yolun yanında, hareket yönüne dik tut\n\n'
                'Telefonu sabit tut, mümkünse tripod kullan\n\n'
                'Nesnenin tamamı ekranda görünsün\n\n'
                'Güvenli mesafeden ölç, yola girme.',
              ),
              const SizedBox(height: 24),
              const Text('Ölçüm kalitesi: kullanılamıyor'),
            ],
          ],
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (value) => setState(() => selected = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.camera_alt_outlined),
          label: 'Kamera',
        ),
        NavigationDestination(icon: Icon(Icons.history), label: 'Geçmiş'),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ],
    ),
  );
}
