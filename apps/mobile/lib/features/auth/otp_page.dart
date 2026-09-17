import 'package:flutter/material.dart';

import '../../widgets/otp_input.dart';
import '../../widgets/primary_button.dart';
import 'widgets/auth_layout.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.phoneNumber});

  /// Nomor tujuan OTP. Yang ditampilkan cuma 4 digit terakhir.
  final String phoneNumber;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  static const _codeLength = 6; // FR-AUTH-002: OTP enam digit

  String _code = '';

  bool get _isComplete => _code.length == _codeLength;

  String get _maskedPhone {
    final phone = widget.phoneNumber;
    if (phone.length <= 4) return phone;
    return '********${phone.substring(phone.length - 4)}';
  }

  void _submit() {
    if (!_isComplete) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // TODO: panggil API verifikasi OTP. Kalau berhasil, arahkan ke beranda.
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Kode OTP',
      subtitle: 'Kode OTP anda dikirim melalui nomor\n$_maskedPhone',
      children: [
        OtpInput(
          length: _codeLength,
          onChanged: (code) => setState(() => _code = code),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 60),
        PrimaryButton(
          label: 'Verifikasi',
          onPressed: _isComplete ? _submit : null,
        ),
      ],
    );
  }
}
