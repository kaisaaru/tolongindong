import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';

final _secondaryText = AppTypography.style(
  size: AppTypography.small,
  weight: AppTypography.regular,
  color: AppColors.textSecondary,
);

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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: _CenteredScrollView(child: AutofillGroup(child: _buildForm())),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final hasError = _errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Masuk ke Akun',
          textAlign: TextAlign.center,
          style: AppTypography.style(
            size: AppTypography.h6,
            weight: AppTypography.medium,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Senang melihat anda lagi. Silahkan masuk kembali untuk memulai',
          textAlign: TextAlign.center,
          style: _secondaryText.copyWith(height: 1.5),
        ),
        const SizedBox(height: 48),
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
                  style: _secondaryText.copyWith(color: AppColors.error),
                ),
              ],
              SizedBox(height: hasError ? 24 : 20),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _TextLink(
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
        const _OrDivider(),
        const SizedBox(height: 36),
        OutlinedButton(
          onPressed: () {
            // TODO: login dengan Google.
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/google.svg',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 12),
              const Flexible(child: Text('Login dengan Google')),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Belum punya akun? ', style: _secondaryText),
            _TextLink(
              text: 'Daftar',
              onTap: () {
                // TODO: navigasi ke halaman registrasi.
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Konten di tengah layar, lebar maksimal 300 (sesuai desain), dan tetap bisa
/// di-scroll saat keyboard muncul.
class _CenteredScrollView extends StatelessWidget {
  const _CenteredScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Garis pemisah dengan tulisan "atau" di tengah.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('atau', style: _secondaryText),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }
}

/// Teks merah yang bisa diklik, misal "Lupa Password?" dan "Daftar".
class _TextLink extends StatelessWidget {
  const _TextLink({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: _secondaryText,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(text),
    );
  }
}
