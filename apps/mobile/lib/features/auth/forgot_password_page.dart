import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import 'auth_repository.dart';
import 'reset_password_page.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_switch_prompt.dart';

/// Lupa password, langkah 1: nomor HP akun. Kode OTP dikirim ke nomor itu,
/// lalu dilanjutkan di [ResetPasswordPage] (FR-AUTH-006).
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialPhone});

  /// Diisi dari kolom login kalau isinya nomor HP.
  final String? initialPhone;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final _phoneController = TextEditingController(
    text: widget.initialPhone,
  );
  late final _authRepo = context.read<AuthRepository>();

  String? _errorText;
  bool _isLoading = false;

  // Nomor HP Indonesia minimal 9 digit, sama seperti form penerima.
  bool get _canSubmit => _phoneController.text.trim().length >= 9;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isLoading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final phone = _phoneController.text.trim();

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final challenge = await _authRepo.forgotPassword(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResetPasswordPage(
            phoneNumber: challenge.phoneNumber.isEmpty
                ? phone
                : challenge.phoneNumber,
            debugOtp: challenge.debugOtp,
            expiresInSeconds: challenge.expiresInSeconds,
          ),
        ),
      );
    } on ApiException catch (e) {
      // Nomor tidak terdaftar, terlalu sering minta kode, atau jaringan:
      // semuanya tentang nomor ini, jadi ditempel ke kolomnya.
      if (mounted) {
        setState(() => _errorText = e.fieldErrors['phone_number'] ?? e.message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Lupa Password',
      subtitle:
          'Masukkan nomor HP akunmu. Kode OTP untuk\n'
          'mengatur ulang password dikirim ke sana.',
      children: [
        AppTextField(
          label: 'No. tlpn',
          hint: '08346763242',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          errorText: _errorText,
          onChanged: (_) => setState(() => _errorText = null),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Kirim Kode',
          isLoading: _isLoading,
          onPressed: _canSubmit ? _submit : null,
        ),
        const SizedBox(height: 32),
        AuthSwitchPrompt(
          question: 'Sudah ingat password?',
          action: 'Masuk',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
