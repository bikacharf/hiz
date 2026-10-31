import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiz_olcer/main.dart';

void main() {
  testWidgets(
    'offline screen labels synthetic input and runs evidence export',
    (tester) async {
      await tester.pumpWidget(const HizApp());
      await tester.tap(find.text('Çevrimdışı test düzeneği'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Model bekleniyor'), findsOneWidget);
      await tester.tap(find.text('Sentetik test senaryosunu çalıştır'));
      await tester.pumpAndSettle();
      expect(find.text('Sentetik kare kanıtı • JSON Lines'), findsOneWidget);
      expect(
        find.textContaining('authored-occlusion-v1:track-2'),
        findsOneWidget,
      );
    },
  );
  testWidgets('prototype routes disclose unavailable functionality', (
    tester,
  ) async {
    await tester.pumpWidget(const HizApp());
    expect(find.text('M1 • Çevrimdışı algılama prototipi'), findsOneWidget);
    await tester.tap(find.text('Yerel video analizi'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Yerel video analizi'), findsOneWidget);
    expect(find.textContaining('Sayısal hız göstermez'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    for (final label in ['Kamera', 'Geçmiş', 'Profil']) {
      await tester.tap(find.widgetWithText(TextButton, label).first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, label), findsOneWidget);
      expect(find.textContaining('Sayısal hız gösterilmez'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
