import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Teks merah yang bisa diklik, misal "Lupa Password?" atau "Daftar".
class TextLink extends StatelessWidget {
  const TextLink({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTypography.style(
          size: AppTypography.small,
          weight: AppTypography.regular,
        ),
        // Tanpa padding dan ukuran minimum, jadi ukurannya pas teks saja.
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(text),
    );
  }
}
