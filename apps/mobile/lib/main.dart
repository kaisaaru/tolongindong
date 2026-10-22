import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'features/splash/splash_page.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AppScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tolongin Dong',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => PhoneWidth(child: child!),
      // Penentuan halaman awal ada di SplashPage, bukan di sini.
      home: const SplashPage(),
    );
  }
}

/// Desain hanya untuk HP (frame 412 dp). Di tablet — iPad didukung,
/// termasuk landscape — aplikasi tampil selebar HP besar di tengah layar,
/// alih-alih kartu dan form melar selebar layar.
class PhoneWidth extends StatelessWidget {
  const PhoneWidth({super.key, required this.child});

  final Widget child;

  /// Lebar HP terbesar yang umum (iPhone Pro Max).
  static const maxWidth = 430.0;

  /// Mulai lebar ini layar dianggap tablet.
  static const tabletWidth = 600.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < tabletWidth) return child;

    return ColoredBox(
      color: AppColors.inputFill,
      child: Center(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 24)],
          ),
          child: ClipRect(
            child: SizedBox(
              width: maxWidth,
              // Halaman mengukur dirinya dari MediaQuery, jadi lebarnya ikut
              // diganti supaya proporsinya sama seperti di HP.
              child: MediaQuery(
                data: media.copyWith(size: Size(maxWidth, media.size.height)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
