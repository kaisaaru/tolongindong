import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tombol utama: [ElevatedButton] dari theme ditambah glow sesuai desain.
/// Isi [onPressed] dengan null untuk state disabled.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Saat true tombol mati dan berganti spinner. Ini yang mencegah satu
  /// permintaan terkirim dua kali gara-gara tap ganda.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return AnimatedContainer(
      duration: kThemeChangeDuration,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.dark.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: isLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.light),
                ),
              )
            : Text(label),
      ),
    );
  }
}
