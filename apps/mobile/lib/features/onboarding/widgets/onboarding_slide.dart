import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// Satu halaman onboarding: ilustrasi, judul, lalu deskripsi.
class OnboardingSlide extends StatelessWidget {
  const OnboardingSlide({
    super.key,
    required this.image,
    required this.title,
    required this.description,
  });

  /// Ilustrasi yang diexport utuh dari Figma (322x483).
  final String image;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Ilustrasi mengisi sisa ruang di atas judul: 1:1 di layar seukuran
          // desain, mengecil di layar yang lebih pendek. Teks tidak ikut.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomCenter,
              // 35 bagian atas dan bawah gambar kosong (di desain, bagian
              // bawahnya tertutup judul), jadi dipotong lewat BoxFit.cover.
              child: Image.asset(
                image,
                width: 322,
                height: 413,
                fit: BoxFit.cover,
                excludeFromSemantics: true, // isinya sudah diwakili judul
              ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.style(
              size: AppTypography.h5,
              weight: AppTypography.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 31),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.style(
              size: AppTypography.caption,
              weight: AppTypography.regular,
              color: AppColors.textDescription,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
