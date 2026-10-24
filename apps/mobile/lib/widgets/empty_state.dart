import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Isi daftar yang masih kosong: ikon, judul, penjelasan, dan ajakan
/// opsional, supaya layar kosong tetap memberi tahu langkah berikutnya.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Tombol ajakan; tampil hanya kalau [onAction] juga diisi.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;

    // Bisa digulir: di layar pendek dengan font besar isinya tidak meluap.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.style(
                size: AppTypography.caption,
                weight: AppTypography.semiBold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.style(
                size: AppTypography.small,
                weight: AppTypography.regular,
                color: AppColors.textDescription,
                height: 1.5,
              ),
            ),
            if (label != null && action != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: action,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(160, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
