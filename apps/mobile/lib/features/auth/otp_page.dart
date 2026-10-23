import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/otp_input.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_link.dart';
import '../home/home_page.dart';
import 'auth_repository.dart';
import 'session_store.dart';
import 'widgets/auth_layout.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({
    super.key,
    required this.phoneNumber,
    this.debugOtp,
    this.expiresInSeconds = 300,
    this.tempToken,
  });

  /// Nomor tujuan OTP. Yang ditampilkan cuma 4 digit terakhir.
  final String phoneNumber;

  /// Kode yang dibocorkan backend saat `APP_ENV=local`. Belum ada gateway SMS,
  /// jadi ini satu-satunya cara melihat kodenya selama pengembangan.
  final String? debugOtp;

  /// Umur kode, 300 detik (FR-AUTH-002).
  final int expiresInSeconds;

  /// Dipakai alur daftar lewat Google, belum terpakai sekarang.
  final String? tempToken;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  static const _codeLength = 6; // FR-AUTH-002: OTP enam digit
  static const _resendCooldown = 60; // backend menolak lebih cepat dari ini

  final _codeController = TextEditingController();
  late final _authRepo = context.read<AuthRepository>();

  late String? _debugOtp = widget.debugOtp;
  late int _expiresIn = widget.expiresInSeconds;
  int _resendIn = _resendCooldown;

  Timer? _ticker;
  String _code = '';
  String? _errorText;
  bool _isLoading = false;
  bool _isResending = false;

  bool get _isComplete => _code.length == _codeLength;
  bool get _isExpired => _expiresIn <= 0;
  bool get _canResend => _resendIn <= 0 && !_isResending;

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
    super.dispose();
  }

  /// Satu timer menghitung dua hal sekaligus: sisa umur kode dan jeda
  /// sebelum tombol kirim ulang boleh dipakai.
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
    if (!_isComplete || _isLoading) return;
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = await _authRepo.verifyOtp(
        phoneNumber: widget.phoneNumber,
        otpCode: _code,
        tempToken: widget.tempToken,
      );

      if (!mounted) return;
      context.read<SessionStore>().signIn(user);
      // Seluruh tumpukan daftar/OTP dibuang: tombol kembali tidak boleh
      // membawa pengguna balik ke layar OTP setelah akun aktif.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = _messageFor(e);
        // Kode salah dikosongkan supaya pengguna tidak perlu menghapus manual.
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

  Future<void> _resend() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      final challenge = await _authRepo.resendOtp(widget.phoneNumber);
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
        // Backend memberi tahu sisa jeda lewat detail, ikuti angkanya.
        final wait = e.intOf('retry_after_seconds') ?? e.intOf('seconds');
        if (e.code == 'OTP_THROTTLED' && wait != null) _resendIn = wait;
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _messageFor(ApiException e) {
    if (e.code == 'OTP_INVALID') {
      final left = e.intOf('remaining_attempts');
      if (left != null && left > 0) return '${e.message} Sisa $left percobaan.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorText != null;

    return AuthLayout(
      title: 'Kode OTP',
      subtitle: 'Kode OTP anda dikirim melalui nomor\n$_maskedPhone',
      children: [
        OtpInput(
          length: _codeLength,
          controller: _codeController,
          hasError: hasError,
          onChanged: (code) => setState(() {
            _code = code;
            _errorText = null;
          }),
          onSubmitted: (_) => _submit(),
        ),

        // Selama pengembangan backend membocorkan kodenya, karena belum ada
        // gateway SMS. Tidak pernah ikut ke build release.
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

        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              if (hasError)
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    size: AppTypography.small,
                    weight: AppTypography.regular,
                    color: AppColors.error,
                  ),
                )
              else
                Text(
                  _isExpired
                      ? 'Kode sudah kedaluwarsa. Silakan kirim ulang.'
                      : 'Kode berlaku ${_mmss(_expiresIn)}',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    size: AppTypography.small,
                    weight: AppTypography.regular,
                    color: _isExpired
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
                        style: AppTypography.style(
                          size: AppTypography.small,
                          weight: AppTypography.regular,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Verifikasi',
          isLoading: _isLoading,
          onPressed: _isComplete && !_isExpired ? _submit : null,
        ),
      ],
    );
  }
}
