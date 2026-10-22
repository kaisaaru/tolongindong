import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/otp_input.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_link.dart';
import 'auth_repository.dart';
import 'widgets/auth_layout.dart';

/// Lupa password, langkah 2: kode OTP dan password baru dikirim bersama
/// (`POST /password/reset`). Berhasil: kembali ke halaman masuk.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.phoneNumber,
    this.debugOtp,
    this.expiresInSeconds = 300,
    this.authRepo,
  });

  /// Nomor tujuan OTP. Yang ditampilkan cuma 4 digit terakhir.
  final String phoneNumber;

  /// Kode yang dibocorkan backend saat `APP_ENV=local`, sama seperti di
  /// halaman OTP pendaftaran.
  final String? debugOtp;

  final int expiresInSeconds;

  /// Diisi hanya saat pengujian, supaya halaman bisa diuji tanpa server.
  final AuthRepository? authRepo;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  static const _codeLength = 6;
  static const _resendCooldown = 60; // backend menolak lebih cepat dari ini
  static const _minPasswordLength = 8;

  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final _authRepo = widget.authRepo ?? AuthRepository();

  late String? _debugOtp = widget.debugOtp;
  late int _expiresIn = widget.expiresInSeconds;
  int _resendIn = _resendCooldown;
  Timer? _ticker;

  String _code = '';

  /// Error kode OTP atau kegagalan umum; tampil di bawah kotak OTP.
  String? _errorText;
  String? _passwordError;
  String? _confirmError;
  bool _isLoading = false;
  bool _isResending = false;

  bool get _isExpired => _expiresIn <= 0;
  bool get _canResend => _resendIn <= 0 && !_isResending;
  bool get _canSubmit =>
      _code.length == _codeLength &&
      !_isExpired &&
      _passwordController.text.isNotEmpty &&
      _confirmController.text.isNotEmpty;

  String get _maskedPhone {
    final phone = widget.phoneNumber;
    if (phone.length <= 4) return phone;
    return '********${phone.substring(phone.length - 4)}';
  }

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_expiresIn > 0) _expiresIn--;
        if (_resendIn > 0) _resendIn--;
      });
      if (_expiresIn <= 0 && _resendIn <= 0) _ticker?.cancel();
    });
  }

  static String _mmss(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isLoading) return;

    // Dicek di aplikasi dulu; server tetap memvalidasi ulang.
    final password = _passwordController.text;
    if (password.length < _minPasswordLength) {
      setState(
        () => _passwordError = 'Password minimal $_minPasswordLength karakter',
      );
      return;
    }
    if (_confirmController.text != password) {
      setState(() => _confirmError = 'Password tidak sama');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _authRepo.resetPassword(
        phoneNumber: widget.phoneNumber,
        otpCode: _code,
        newPassword: password,
      );
      if (!mounted) return;
      // Kembali ke halaman masuk; pesannya tampil di sana.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diganti. Silakan masuk lagi.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        final fields = e.fieldErrors;
        _passwordError = fields['new_password'];
        _errorText =
            fields['otp_code'] ??
            (_passwordError == null ? _messageFor(e) : null);
        if (e.code == 'OTP_INVALID') {
          _codeController.clear();
          _code = '';
        }
        if (e.code == 'OTP_EXPIRED') _expiresIn = 0;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageFor(ApiException e) {
    if (e.code == 'OTP_INVALID') {
      final left = e.intOf('remaining_attempts');
      if (left != null && left > 0) return '${e.message} Sisa $left percobaan.';
    }
    return e.message;
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      final challenge = await _authRepo.resendOtp(
        widget.phoneNumber,
        type: 'reset_password',
      );
      if (!mounted) return;
      setState(() {
        _debugOtp = challenge.debugOtp ?? _debugOtp;
        _expiresIn = challenge.expiresInSeconds;
        _resendIn = _resendCooldown;
        _codeController.clear();
        _code = '';
      });
      _startTicker();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
        final wait = e.intOf('retry_after_seconds');
        if (e.code == 'OTP_THROTTLED' && wait != null) _resendIn = wait;
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorText != null;
    final caption = AppTypography.style(
      size: AppTypography.small,
      weight: AppTypography.regular,
      color: AppColors.textSecondary,
    );

    return AuthLayout(
      title: 'Atur Ulang Password',
      subtitle: 'Masukkan kode OTP yang dikirim ke\n$_maskedPhone',
      maxTopSpace: 39,
      children: [
        OtpInput(
          length: _codeLength,
          controller: _codeController,
          hasError: hasError,
          onChanged: (code) => setState(() {
            _code = code;
            _errorText = null;
          }),
        ),

        // Belum ada gateway SMS: selama pengembangan kodenya dibocorkan
        // backend. Tidak pernah ikut ke build release.
        if (kDebugMode && _debugOtp != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Mode pengembangan — kode: $_debugOtp',
              textAlign: TextAlign.center,
              style: AppTypography.style(
                size: AppTypography.small,
                weight: AppTypography.medium,
                color: AppColors.primary,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Text(
          hasError
              ? _errorText!
              : _isExpired
              ? 'Kode sudah kedaluwarsa. Silakan kirim ulang.'
              : 'Kode berlaku ${_mmss(_expiresIn)}',
          textAlign: TextAlign.center,
          style: caption.copyWith(
            color: hasError
                ? AppColors.error
                : _isExpired
                ? AppColors.warning
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _canResend
              ? TextLink(text: 'Kirim ulang kode', onTap: _resend)
              : Text(
                  _isResending
                      ? 'Mengirim ulang...'
                      : 'Kirim ulang dalam ${_mmss(_resendIn)}',
                  style: caption,
                ),
        ),
        const SizedBox(height: 28),
        AppTextField(
          label: 'Password baru',
          hint: 'Minimal $_minPasswordLength karakter',
          controller: _passwordController,
          isPassword: true,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          errorText: _passwordError,
          onChanged: (_) => setState(() => _passwordError = null),
        ),
        const SizedBox(height: 19),
        AppTextField(
          label: 'Ulangi password baru',
          hint: 'Ketik ulang password baru',
          controller: _confirmController,
          isPassword: true,
          textInputAction: TextInputAction.done,
          errorText: _confirmError,
          onChanged: (_) => setState(() => _confirmError = null),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Simpan Password',
          isLoading: _isLoading,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}
