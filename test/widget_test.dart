import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiz/main.dart';

void main() {
  testWidgets(
    'prototype navigation exposes unavailable states without speeds',
    (tester) async {
      await tester.pumpWidget(const HizApp());
      expect(find.textContaining('Kamera henüz bağlı değil'), findsOneWidget);
      expect(find.textContaining('M0 ·'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      expect(find.textContaining('Henüz kayıt yok'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.textContaining('Yerel prototip'), findsOneWidget);
      expect(find.textContaining('km/h'), findsNothing);
    },
  );
}
