import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/app_preferences.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_repository.dart';
import '../auth/session_store.dart';
import '../auth/login_page.dart';
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
  const SplashPage({super.key});

  /// Lama splash tampil minimal, walau pengecekan selesai lebih cepat.
  static const duration = Duration(seconds: 2);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final _authRepo = context.read<AuthRepository>();
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
    Widget destination;
    try {
      destination = await _resolveDestination();
    } on Object {
      // Kegagalan tak terduga (respons rusak, keystore/preferensi gagal
      // dibaca) tidak boleh menahan pengguna di splash selamanya.
      destination = const LoginPage();
    }
    await minimumDisplay;

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  Future<Widget> _resolveDestination() async {
    // Diambil sebelum menunggu apa pun: context tidak boleh dipakai lagi
    // kalau halaman sudah ditutup saat balasan tiba.
    final session = context.read<SessionStore>();
    if (await _authRepo.hasSession()) {
      try {
        session.signIn(await _authRepo.me());
        return const HomePage();
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
