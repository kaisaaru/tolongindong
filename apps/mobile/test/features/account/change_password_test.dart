import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/account/change_password_page.dart';
import 'package:mobile/widgets/app_text_field.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_page.dart';

Finder _field(int index) => find.descendant(
  of: find.byType(AppTextField).at(index),
  matching: find.byType(TextField),
);

Future<void> _fill(WidgetTester tester, String current, String next) async {
  await tester.enterText(_field(0), current);
  await tester.enterText(_field(1), next);
  await tester.enterText(_field(2), next);
  await tester.pump();
}

void main() {
  testWidgets('berhasil: halaman tertutup dan diberi tahu', (tester) async {
    final repo = FakeAuthRepository();
    await pumpPage(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangePasswordPage(authRepo: repo),
              ),
            ),
            child: const Text('Akun'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Akun'));
    await tester.pumpAndSettle();

    await _fill(tester, 'password-lama', 'password-baru');
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();

    expect(repo.lastCall, {
      'current_password': 'password-lama',
      'new_password': 'password-baru',
    });
    expect(find.byType(ChangePasswordPage), findsNothing);
    expect(find.text('Password berhasil diganti.'), findsOneWidget);
  });

  testWidgets('password lama salah tampil di kolomnya', (tester) async {
    final repo = FakeAuthRepository(
      failWith: const ApiException(
        code: 'CURRENT_PASSWORD_INCORRECT',
        message: 'Kata sandi saat ini yang Anda masukkan salah.',
      ),
    );
    await pumpPage(tester, ChangePasswordPage(authRepo: repo));

    await _fill(tester, 'salah', 'password-baru');
    await tester.tap(find.text('Simpan Password'));
    await tester.pump();

    expect(
      find.text('Kata sandi saat ini yang Anda masukkan salah.'),
      findsOneWidget,
    );
  });

  testWidgets('password baru sama dengan lama ditolak tanpa ke server', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await pumpPage(tester, ChangePasswordPage(authRepo: repo));

    await _fill(tester, 'password-sama', 'password-sama');
    await tester.tap(find.text('Simpan Password'));
    await tester.pump();

    expect(find.text('Password baru sama dengan yang lama'), findsOneWidget);
    expect(repo.lastCall, isNull);
  });
}
