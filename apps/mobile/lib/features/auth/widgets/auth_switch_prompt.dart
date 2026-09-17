import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/text_link.dart';

/// Ajakan pindah halaman di bawah form, misal "Belum punya akun? Daftar".
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Wrap, bukan Row: kalau font HP diperbesar, teks turun ke baris baru
    // alih-alih overflow.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$question ',
          style: AppTypography.style(
            size: AppTypography.small,
            weight: AppTypography.regular,
            color: AppColors.textSecondary,
          ),
        ),
        TextLink(text: action, onTap: onTap),
      ],
    );
  }
}
