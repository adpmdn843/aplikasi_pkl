import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aplikasi_pkl/main.dart';

void main() {
  testWidgets(
    'Aplikasi PKL berhasil dibuka',
    (WidgetTester tester) async {
      // ======================================================
      // SIMULASI BELUM LOGIN
      // ======================================================

      SharedPreferences.setMockInitialValues({
        'isLoggedIn': false,
      });

      // ======================================================
      // BUKA APLIKASI
      // ======================================================

      await tester.pumpWidget(
        const ThanuSmartApp(),
      );

      await tester.pumpAndSettle();

      // ======================================================
      // CEK HALAMAN LOGIN
      // ======================================================

      expect(
        find.text('ID PKL'),
        findsOneWidget,
      );

      expect(
        find.text('Password'),
        findsOneWidget,
      );

      expect(
        find.text('Masuk'),
        findsOneWidget,
      );
    },
  );
}