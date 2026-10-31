import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiz_olcer/main.dart';

void main() {
  testWidgets('prototype routes disclose unavailable functionality', (
    tester,
  ) async {
    await tester.pumpWidget(const HizApp());
    expect(find.text('M0 • İşlevsiz arayüz prototipi'), findsOneWidget);
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
