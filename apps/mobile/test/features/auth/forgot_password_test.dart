import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/auth/forgot_password_page.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/auth/reset_password_page.dart';
import 'package:mobile/widgets/app_text_field.dart';
import 'package:mobile/widgets/otp_input.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_page.dart';

/// Halaman awal berisi tombol yang membuka [page], supaya kembali ke
/// halaman pertama bisa diuji.
Widget _launcher(Widget page) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page)),
        child: const Text('Buka'),
      ),
    ),
  ),
);

Finder _field(int index) => find.descendant(
  of: find.byType(AppTextField).at(index),
  matching: find.byType(TextField),
);

Finder get _otpField => find.descendant(
  of: find.byType(OtpInput),
  matching: find.byType(TextField),
);

void main() {
  testWidgets('Lupa Password? membawa nomor HP dari kolom login', (
    tester,
  ) async {
    await pumpPage(tester, LoginPage(), authRepo: FakeAuthRepository());

    await tester.enterText(find.byType(TextField).first, '081234563914');
    await tester.tap(find.text('Lupa Password?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    expect(find.text('081234563914'), findsOneWidget);
  });

  testWidgets('nomor tidak terdaftar tampil di bawah kolom', (tester) async {
    final repo = FakeAuthRepository(
      failWith: const ApiException(
        code: 'USER_NOT_FOUND',
        message: 'Nomor telepon tidak terdaftar dalam sistem.',
      ),
    );
    await pumpPage(
      tester,
      ForgotPasswordPage(initialPhone: '080000000001'),
      authRepo: repo,
    );

    await tester.tap(find.text('Kirim Kode'));
    await tester.pump();

    expect(
      find.text('Nomor telepon tidak terdaftar dalam sistem.'),
      findsOneWidget,
    );
    expect(find.byType(ResetPasswordPage), findsNothing);
  });

  testWidgets('kode OTP dan password baru: kembali ke halaman pertama', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await pumpPage(
      tester,
      _launcher(ForgotPasswordPage(initialPhone: '081234563914')),
      authRepo: repo,
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kirim Kode'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordPage), findsOneWidget);
    expect(find.textContaining('********3914'), findsOneWidget);
    expect(find.textContaining('654321'), findsOneWidget); // kode debug

    await tester.enterText(_otpField, '654321');
    await tester.enterText(_field(0), 'rahasia-baru');
    await tester.enterText(_field(1), 'rahasia-lain');
    await tester.pump();
    await tester.tap(find.text('Simpan Password'));
    await tester.pump();
    expect(find.text('Password tidak sama'), findsOneWidget);

    await tester.enterText(_field(1), 'rahasia-baru');
    await tester.pump();
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();

    expect(repo.lastCall, {
      'phone_number': '081234563914',
      'otp_code': '654321',
      'new_password': 'rahasia-baru',
    });
    expect(find.text('Buka'), findsOneWidget);
    expect(
      find.text('Password berhasil diganti. Silakan masuk lagi.'),
      findsOneWidget,
    );
  });

  testWidgets('kode salah: pesan sisa percobaan dan kotak dikosongkan', (
    tester,
  ) async {
    final repo = FakeAuthRepository(
      failWith: const ApiException(
        code: 'OTP_INVALID',
        message: 'Kode OTP yang Anda masukkan salah.',
        detail: {'remaining_attempts': 2},
      ),
    );
    await pumpPage(
      tester,
      ResetPasswordPage(phoneNumber: '081234563914'),
      authRepo: repo,
    );

    await tester.enterText(_otpField, '111111');
    await tester.enterText(_field(0), 'rahasia-baru');
    await tester.enterText(_field(1), 'rahasia-baru');
    await tester.pump();
    await tester.tap(find.text('Simpan Password'));
    await tester.pump();

    expect(
      find.text('Kode OTP yang Anda masukkan salah. Sisa 2 percobaan.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(_otpField).controller!.text, isEmpty);
  });
}
