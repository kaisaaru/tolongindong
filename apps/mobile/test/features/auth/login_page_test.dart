import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/auth/register_page.dart';

import '../../helpers/pump_page.dart';

void main() {
  Finder field(int index) => find.byType(TextField).at(index);

  testWidgets('tombol Login baru aktif setelah email dan password diisi', (
    tester,
  ) async {
    await pumpPage(tester, const LoginPage());
    ElevatedButton loginButton() =>
        tester.widget(find.widgetWithText(ElevatedButton, 'Login'));

    expect(loginButton().onPressed, isNull);

    await tester.enterText(field(0), 'alexsander83@gmail.com');
    await tester.pump();
    expect(loginButton().onPressed, isNull);

    await tester.enterText(field(1), '@lexSa76');
    await tester.pump();
    expect(loginButton().onPressed, isNotNull);
  });

  testWidgets('ikon mata menampilkan dan menyembunyikan password', (
    tester,
  ) async {
    await pumpPage(tester, const LoginPage());
    bool obscured() => tester.widget<TextField>(field(1)).obscureText;

    expect(obscured(), isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();
    expect(obscured(), isFalse);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(obscured(), isTrue);
  });

  testWidgets('Daftar membuka halaman registrasi, Masuk kembali ke login', (
    tester,
  ) async {
    await pumpPage(tester, const LoginPage());

    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
