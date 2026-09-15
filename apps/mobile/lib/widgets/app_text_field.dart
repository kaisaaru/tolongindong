import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Text field dengan label di atasnya. Tampilan field diambil dari
/// `inputDecorationTheme` di `AppTheme`.
///
/// [isPassword] menyembunyikan input dan menambah tombol mata.
/// [hasError] cuma memerahkan border; pesan error ditulis di luar widget ini
/// supaya satu pesan bisa mewakili beberapa field.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.isPassword = false,
    this.hasError = false,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool isPassword;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTypography.style(
            size: AppTypography.small,
            weight: AppTypography.regular,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
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
            // Widget kosong: border jadi merah tanpa menambah ruang di bawah field.
            error: widget.hasError ? const SizedBox.shrink() : null,
            suffixIcon: widget.isPassword ? _buildVisibilityToggle() : null,
            // Default 48 bikin field password lebih tinggi dari field lain.
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
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
