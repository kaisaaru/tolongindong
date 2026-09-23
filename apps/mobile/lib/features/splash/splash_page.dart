import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../onboarding/onboarding_page.dart';
import 'widgets/splash_waves.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  /// Lama splash tampil sebelum pindah ke onboarding.
  static const duration = Duration(seconds: 2);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashPage.duration, _openOnboarding);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _openOnboarding() {
    // TODO: kalau onboarding sudah pernah dilihat atau user sudah login,
    // langsung arahkan ke halaman yang sesuai.
    final route = MaterialPageRoute<void>(
      builder: (_) => const OnboardingPage(),
    );
    Navigator.of(context).pushReplacement(route);
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
