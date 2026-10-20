import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/app_preferences.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_repository.dart';
import '../auth/login_page.dart';
import '../home/catalog_repository.dart';
import '../home/home_page.dart';
import '../onboarding/onboarding_page.dart';
import 'widgets/splash_waves.dart';

/// Layar pertama aplikasi. Selain tampil sesuai desain, di sinilah
/// ditentukan pengguna dibawa ke mana:
///
/// ```
/// sudah login (token masih sah)  -> Beranda
/// belum pernah lihat onboarding  -> Onboarding
/// sisanya                        -> Login
/// ```
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.authRepo, this.catalogRepo});

  /// Diisi hanya saat pengujian, supaya splash bisa diuji tanpa server.
  final AuthRepository? authRepo;

  /// Diteruskan ke beranda. Splash sendiri tidak memakainya — ada di sini
  /// supaya beranda tetap bisa diuji walau dibuka lewat splash.
  final CatalogRepository? catalogRepo;

  /// Lama splash tampil minimal, walau pengecekan selesai lebih cepat.
  static const duration = Duration(seconds: 2);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final _authRepo = widget.authRepo ?? AuthRepository();
  final _prefs = AppPreferences();

  @override
  void initState() {
    super.initState();
    unawaited(_decideNextPage());
  }

  Future<void> _decideNextPage() async {
    // Hitungan mulai sekarang, lalu pengecekan jalan bersamaan. Jadi splash
    // tetap tampil penuh 2 detik tanpa menambah waktu tunggu.
    final minimumDisplay = Future<void>.delayed(SplashPage.duration);
    final destination = await _resolveDestination();
    await minimumDisplay;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => destination),
    );
  }

  Future<Widget> _resolveDestination() async {
    if (await _authRepo.hasSession()) {
      try {
        return HomePage(
          user: await _authRepo.me(),
          authRepo: widget.authRepo,
          catalogRepo: widget.catalogRepo,
        );
      } on ApiException catch (e) {
        // Token hanya dibuang kalau server benar-benar menolaknya. Jaringan
        // mati bukan alasan menghapus sesi — pengguna cuma diminta login lagi.
        if (e.code == 'UNAUTHENTICATED') await _authRepo.logout();
      }
    }

    if (!await _prefs.hasSeenOnboarding()) return const OnboardingPage();
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // ikon status bar gelap di latar putih
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Align(alignment: Alignment.bottomCenter, child: SplashWaves()),
            // Pusat logo di sekitar 32% tinggi layar, sama seperti desain.
            // TODO: ganti kotak merah (placeholder di desain) dengan logo.
            Align(
              alignment: Alignment(0, -0.4),
              child: SizedBox.square(
                dimension: 106,
                child: ColoredBox(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
