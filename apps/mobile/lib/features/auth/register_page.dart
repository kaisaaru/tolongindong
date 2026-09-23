import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import 'otp_page.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_switch_prompt.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/or_divider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const _minPasswordLength = 8;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Error per field. Email dan nomor dari server, password dicek di aplikasi.
  String? _emailError;
  String? _phoneError;
  String? _passwordError;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _phoneController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    if (_passwordController.text.length < _minPasswordLength) {
      setState(
        () => _passwordError = 'Password minimal $_minPasswordLength karakter',
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    // TODO: panggil POST /auth/register dulu. Kalau email/nomor sudah
    // terdaftar, tampilkan errornya dan jangan lanjut ke OTP:
    // setState(() => _emailError = 'Email sudah digunakan!');
    // setState(() => _phoneError = 'Nomor telfon sudah digunakan!');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OtpPage(phoneNumber: _phoneController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Daftar Akun',
      subtitle: 'Lengkapi data diri Anda untuk mulai\nmenggunakan TolonginDong',
      maxTopSpace: 39,
      children: [
        // Tinggi normal 4 field = 321. Sisa 31 jadi cadangan untuk satu pesan
        // error (29), supaya tombol Daftar tidak bergeser (desain
        // Compact-16/18/21).
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 352),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Nama Lengkap',
                hint: 'Masukkan nama anda',
                controller: _nameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 19),
              AppTextField(
                label: 'Email',
                hint: 'Masukkan email anda',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                errorText: _emailError,
                onChanged: (_) => setState(() => _emailError = null),
              ),
              const SizedBox(height: 19),
              AppTextField(
                label: 'No. tlpn',
                hint: '08346763242',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                errorText: _phoneError,
                onChanged: (_) => setState(() => _phoneError = null),
              ),
              const SizedBox(height: 19),
              AppTextField(
                label: 'Password',
                hint: 'Masukkan password anda',
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                errorText: _passwordError,
                onChanged: (_) => setState(() => _passwordError = null),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Daftar', onPressed: _canSubmit ? _submit : null),
        const SizedBox(height: 34),
        const OrDivider(),
        const SizedBox(height: 36),
        GoogleSignInButton(
          onPressed: () {
            // TODO: daftar dengan Google.
          },
        ),
        const SizedBox(height: 32),
        AuthSwitchPrompt(
          question: 'Sudah punya akun?',
          action: 'Masuk',
          // Halaman ini selalu dibuka dari login, jadi cukup kembali.
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
