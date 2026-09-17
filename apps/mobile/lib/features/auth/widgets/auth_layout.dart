import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// Kerangka halaman auth (login, daftar, OTP): judul, subjudul, lalu
/// [children] dalam satu kolom selebar 300, sesuai desain.
///
/// Konten diletakkan di tengah layar, tapi ruang di atas judul maksimal 104.
/// Jadi halaman pendek seperti OTP tetap di bagian atas, sama seperti desain.
/// Kalau konten lebih tinggi dari layar (misal keyboard muncul), halaman
/// bisa di-scroll.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // ikon status bar gelap di latar putih
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 348, // konten 300 + padding 24 kiri-kanan
                    minHeight: viewport.maxHeight,
                  ),
                  // Bikin Column minimal setinggi layar (supaya Spacer di
                  // bawah bisa bekerja), tapi tetap boleh lebih tinggi.
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AutofillGroup(child: _buildContent()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sisa ruang dibagi dua atas-bawah (konten di tengah), tapi yang
        // atas dibatasi 104. SizedBox.expand dipakai (bukan SizedBox(height:))
        // supaya ruang ini tidak ikut dihitung sebagai tinggi konten.
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 104),
            child: const SizedBox.expand(),
          ),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.style(
            size: AppTypography.h6,
            weight: AppTypography.medium,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTypography.style(
            size: AppTypography.small,
            weight: AppTypography.regular,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),
        ...children,
        const Spacer(),
      ],
    );
  }
}
