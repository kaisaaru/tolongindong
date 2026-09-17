import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_link.dart';
import 'register_page.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_switch_prompt.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/or_divider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Pesan kalau login ditolak server. Selama tidak null, kedua field merah.
  String? _errorText;

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Rebuild supaya state tombol Login ikut berubah, sekaligus hapus error lama.
  void _onChanged(String _) => setState(() => _errorText = null);

  void _submit() {
    if (!_canSubmit) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // TODO: panggil API login. Kalau email/password salah:
    // setState(() => _errorText = 'Email atau password salah');
  }

  void _openRegister() {
    final route = MaterialPageRoute<void>(builder: (_) => const RegisterPage());
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorText != null;

    return AuthLayout(
      title: 'Masuk ke Akun',
      subtitle:
          'Senang melihat anda lagi. Silahkan masuk\nkembali untuk memulai',
      children: [
        AppTextField(
          label: 'Email',
          hint: 'Masukkan email anda',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          hasError: hasError,
          onChanged: _onChanged,
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'Password',
          hint: 'Masukkan password anda',
          controller: _passwordController,
          isPassword: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          hasError: hasError,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
        ),
        // Tinggi minimum dijaga supaya tombol Login tidak bergeser saat
        // pesan error muncul (desain Compact-7).
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasError) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: AppTypography.style(
                    size: AppTypography.small,
                    weight: AppTypography.regular,
                    color: AppColors.error,
                  ),
                ),
              ],
              SizedBox(height: hasError ? 24 : 20),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextLink(
                  text: 'Lupa Password?',
                  onTap: () {
                    // TODO: navigasi ke halaman lupa password.
                  },
                ),
              ),
            ],
          ),
        ),
        PrimaryButton(label: 'Login', onPressed: _canSubmit ? _submit : null),
        const SizedBox(height: 34),
        const OrDivider(),
        const SizedBox(height: 36),
        GoogleSignInButton(
          onPressed: () {
            // TODO: login dengan Google.
          },
        ),
        const SizedBox(height: 32),
        AuthSwitchPrompt(
          question: 'Belum punya akun?',
          action: 'Daftar',
          onTap: _openRegister,
        ),
      ],
    );
  }
}
