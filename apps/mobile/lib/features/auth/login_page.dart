import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_link.dart';
import '../home/home_page.dart';
import 'auth_repository.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'session_store.dart';
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
  // Backend menerima email ATAU nomor HP di field yang sama (`identifier`),
  // jadi satu controller untuk keduanya.
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  late final _authRepo = context.read<AuthRepository>();

  /// Pesan kalau login ditolak server. Selama tidak null, kedua field merah.
  String? _errorText;

  bool _isLoading = false;

  bool get _canSubmit =>
      _identifierController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Rebuild supaya state tombol Login ikut berubah, sekaligus hapus error lama.
  void _onChanged(String _) => setState(() => _errorText = null);

  Future<void> _submit() async {
    if (!_canSubmit || _isLoading) return;
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = await _authRepo.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      context.read<SessionStore>().signIn(user);
      // pushReplacement, bukan push: tombol kembali tidak boleh membawa
      // pengguna balik ke layar login setelah berhasil masuk.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorText = _messageFor(e));
    } finally {
      // Dijaga `mounted` karena halaman bisa sudah ditutup saat balasan tiba.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Pesan dari server sudah berbahasa Indonesia dan layak tampil apa adanya.
  /// Yang perlu ditambahkan cuma angka sisa percobaan (FR-AUTH-005), karena
  /// letaknya di `error.detail`, bukan di `message`.
  String _messageFor(ApiException e) {
    if (e.code == 'INVALID_CREDENTIALS') {
      final left = e.intOf('remaining_attempts');
      if (left != null && left > 0) return '${e.message} Sisa $left percobaan.';
    }
    return e.message;
  }

  void _soon(String feature) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature belum tersedia.')));

  void _openForgotPassword() {
    // Nomor HP yang sudah diketik di kolom login ikut dibawa.
    final typed = _identifierController.text.trim();
    final isPhone = RegExp(r'^\d{9,}$').hasMatch(typed);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ForgotPasswordPage(initialPhone: isPhone ? typed : null),
      ),
    );
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
          label: 'Email atau No. tlpn',
          hint: 'Masukkan email atau nomor anda',
          controller: _identifierController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          hasError: hasError,
          onChanged: _onChanged,
        ),
        const SizedBox(height: 19),
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
          constraints: const BoxConstraints(minHeight: 94),
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
                  onTap: _openForgotPassword,
                ),
              ),
            ],
          ),
        ),
        PrimaryButton(
          label: 'Login',
          isLoading: _isLoading,
          onPressed: _canSubmit ? _submit : null,
        ),
        const SizedBox(height: 34),
        const OrDivider(),
        const SizedBox(height: 36),
        GoogleSignInButton(
          // TODO: login dengan Google.
          onPressed: () => _soon('Masuk dengan Google'),
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
