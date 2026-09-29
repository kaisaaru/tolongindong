import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import 'auth_repository.dart';
import 'otp_page.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_switch_prompt.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/or_divider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.authRepo});

  /// Diisi hanya saat pengujian, supaya halaman bisa diuji tanpa server.
  final AuthRepository? authRepo;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const _minPasswordLength = 8;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  late final _authRepo = widget.authRepo ?? AuthRepository();

  // Error per field. Email dan nomor dari server, password dicek di aplikasi.
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;

  bool _isLoading = false;

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

  Future<void> _submit() async {
    if (!_canSubmit || _isLoading) return;

    // Dicek lebih dulu di aplikasi supaya pengguna tidak menunggu server
    // untuk aturan yang sudah pasti. Server tetap memvalidasi ulang.
    if (_passwordController.text.length < _minPasswordLength) {
      setState(
        () => _passwordError = 'Password minimal $_minPasswordLength karakter',
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
    });

    try {
      final challenge = await _authRepo.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      // Registrasi belum menerbitkan token. Akun baru aktif setelah OTP
      // diverifikasi, jadi nomor dan kode dibawa ke halaman berikutnya.
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OtpPage(
            phoneNumber: challenge.phoneNumber,
            debugOtp: challenge.debugOtp,
            expiresInSeconds: challenge.expiresInSeconds,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kegagalan validasi ditempel ke field yang bersangkutan; sisanya
  /// (jaringan mati, error server) tampil sebagai snackbar karena tidak
  /// dimiliki satu field pun.
  void _showError(ApiException e) {
    if (e.code == 'VALIDATION_ERROR') {
      final fields = e.fieldErrors;
      setState(() {
        _nameError = fields['full_name'];
        _emailError = fields['email'];
        _phoneError = fields['phone_number'];
        _passwordError = fields['password'];
      });
      // Pesan yang tidak cocok ke field mana pun jangan sampai hilang diam-diam.
      if (fields.isNotEmpty) return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.message)));
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
                errorText: _nameError,
                onChanged: (_) => setState(() => _nameError = null),
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
        PrimaryButton(
          label: 'Daftar',
          isLoading: _isLoading,
          onPressed: _canSubmit ? _submit : null,
        ),
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
