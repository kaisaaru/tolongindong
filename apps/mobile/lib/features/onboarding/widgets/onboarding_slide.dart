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

  /// Tinggi frame desain (Android Compact 412x917).
  static const designHeight = 917.0;

  /// Pengali jarak vertikal onboarding: 1 di layar setinggi desain, mengecil
  /// di HP yang lebih pendek (568 dp -> ±0,62) supaya proporsinya sama.
  static double scaleOf(BuildContext context) =>
      (MediaQuery.sizeOf(context).height / designHeight).clamp(0.55, 1.0);

  @override
  Widget build(BuildContext context) {
    final k = scaleOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, box) => Column(
          children: [
            // Ilustrasi mengisi sisa ruang di atas judul: 1:1 di layar
            // seukuran desain, mengecil di layar yang lebih pendek.
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
            // Teks memakai baris dari desain dan mengecil utuh kalau tidak
            // muat (HP 320 dp, font HP diperbesar), alih-alih pecah ke
            // baris baru atau meluap. Ilustrasi selalu kebagian ruang.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.65),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        size: AppTypography.h5,
                        weight: AppTypography.bold,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 31 * k),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
