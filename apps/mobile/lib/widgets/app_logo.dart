import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo SEMENTARA TolonginDong: kotak merah membulat berisi tangan menolong
/// putih. Ikon aplikasi (`assets/launcher/`) digambar dari desain yang sama.
///
/// Saat logo final sudah ada: ganti isi widget ini dengan gambarnya, timpa
/// `assets/launcher/icon.png` dan `icon_foreground.png`, lalu jalankan
/// `dart run flutter_launcher_icons`.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 106});

  final double size;

  /// Ikon di dalam kotak, dipakai juga untuk ikon aplikasi.
  static const symbol = Icons.volunteer_activism_rounded;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'TolonginDong',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
        child: Icon(symbol, size: size * 0.56, color: AppColors.light),
      ),
    );
  }
}
