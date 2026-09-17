import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Text field dengan label di atasnya. Tampilan field diambil dari
/// `inputDecorationTheme` di `AppTheme`.
///
/// [isPassword] menyembunyikan input dan menambah tombol mata.
///
/// Dua cara menampilkan error:
/// - [errorText]: error milik field ini (misal "Email sudah digunakan!").
///   Label dan border jadi merah, pesan tampil di bawah field.
/// - [hasError]: cuma memerahkan border. Dipakai kalau satu pesan mewakili
///   beberapa field (misal "Email atau password salah" di halaman login).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.isPassword = false,
    this.hasError = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool isPassword;
  final bool hasError;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final errorText = widget.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTypography.style(
            size: AppTypography.small,
            weight: AppTypography.regular,
            color: errorText != null
                ? AppColors.error
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          autofillHints: widget.autofillHints,
          obscureText: _obscured,
          obscuringCharacter: '●',
          autocorrect: !widget.isPassword,
          enableSuggestions: !widget.isPassword,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: AppTypography.style(
            size: AppTypography.small,
            weight: AppTypography.regular,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            // Widget kosong: border jadi merah tanpa menambah ruang di bawah
            // field. Pesan error ditulis sendiri di bawah supaya rata kiri
            // dengan tepi field, sesuai desain.
            error: widget.hasError || errorText != null
                ? const SizedBox.shrink()
                : null,
            suffixIcon: widget.isPassword ? _buildVisibilityToggle() : null,
            // Default 48 bikin field password lebih tinggi dari field lain.
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            // Bawah 6: jarak ke label field berikutnya jadi 24, sesuai desain.
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              errorText,
              style: AppTypography.style(
                size: AppTypography.small,
                weight: AppTypography.regular,
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVisibilityToggle() {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(_obscured ? Icons.visibility_off : Icons.visibility),
        iconSize: 20,
        tooltip: _obscured ? 'Tampilkan password' : 'Sembunyikan password',
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
