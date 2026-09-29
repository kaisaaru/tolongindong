import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/auth/otp_page.dart';
import 'package:mobile/features/auth/register_page.dart';
import 'package:mobile/models/auth_user.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_page.dart';

void main() {
  Finder field(int index) => find.byType(TextField).at(index);
  final daftarButton = find.widgetWithText(ElevatedButton, 'Daftar');

  Future<void> fillForm(
    WidgetTester tester, {
    String password = 'rahasia123',
  }) async {
    await tester.enterText(field(0), 'Alex sander');
    await tester.enterText(field(1), 'alexsander83@gmail.com');
    await tester.enterText(field(2), '08774438764');
    await tester.enterText(field(3), password);
    await tester.pump();
  }

  testWidgets('tombol Daftar baru aktif setelah semua field diisi', (
    tester,
  ) async {
    await pumpPage(tester, const RegisterPage());
    VoidCallback? onPressed() =>
        tester.widget<ElevatedButton>(daftarButton).onPressed;

    expect(onPressed(), isNull);

    await fillForm(tester);
    expect(onPressed(), isNotNull);
  });

  testWidgets('No. tlpn cuma menerima angka', (tester) async {
    await pumpPage(tester, const RegisterPage());

    await tester.enterText(field(2), '0877-44 38a');
    expect(tester.widget<TextField>(field(2)).controller!.text, '08774438');
  });

  testWidgets('password kurang dari 8 karakter ditolak sebelum ke OTP', (
    tester,
  ) async {
    await pumpPage(tester, const RegisterPage());
    await fillForm(tester, password: 'abc123');

    await tester.tap(daftarButton);
    await tester.pumpAndSettle();
    expect(find.text('Password minimal 8 karakter'), findsOneWidget);
    expect(find.byType(OtpPage), findsNothing);

    // Error hilang begitu password diubah.
    await tester.enterText(field(3), 'abc12345');
    await tester.pump();
    expect(find.text('Password minimal 8 karakter'), findsNothing);
  });

  testWidgets('data valid lanjut ke OTP dengan nomor yang disamarkan', (
    tester,
  ) async {
    final repo = FakeAuthRepository(
      registerResult: const OtpChallenge(
        phoneNumber: '08774438764',
        expiresInSeconds: 300,
      ),
    );
    await pumpPage(tester, RegisterPage(authRepo: repo));
    await fillForm(tester);

    await tester.tap(daftarButton);
    await tester.pumpAndSettle();

    // Server dipanggil dengan data yang diisi, bukan dilewati.
    expect(repo.lastCall?['email'], 'alexsander83@gmail.com');
    expect(find.byType(OtpPage), findsOneWidget);
    expect(find.textContaining('********8764'), findsOneWidget);
  });

  testWidgets('email sudah terdaftar ditempel ke field email, tidak ke OTP', (
    tester,
  ) async {
    final repo = FakeAuthRepository(
      failWith: const ApiException(
        code: 'VALIDATION_ERROR',
        message: 'Validasi pendaftaran gagal',
        detail: {
          'email': ['Alamat email ini sudah terdaftar.'],
        },
        statusCode: 422,
      ),
    );
    await pumpPage(tester, RegisterPage(authRepo: repo));
    await fillForm(tester);

    await tester.tap(daftarButton);
    await tester.pumpAndSettle();

    expect(find.text('Alamat email ini sudah terdaftar.'), findsOneWidget);
    expect(find.byType(OtpPage), findsNothing);
  });
}
