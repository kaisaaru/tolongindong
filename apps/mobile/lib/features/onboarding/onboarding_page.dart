import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../auth/login_page.dart';
import 'widgets/onboarding_slide.dart';
import 'widgets/page_indicator.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _slides = [
    OnboardingSlide(
      image: 'assets/images/onboarding/onboarding_1.png',
      title: 'Bantuan Mudah untuk\nTugas Harian',
      description:
          'Temukan Helper terdekat untuk belanja,\nbebersih, dan kebutuhan '
          'harianmu\nkapan saja.',
    ),
    OnboardingSlide(
      image: 'assets/images/onboarding/onboarding_2.png',
      title: 'Aman dengan Helper\nTerverifikasi',
      description:
          'Seluruh Helper telah lolos verifikasi\nidentitas resmi demi '
          'keamanan dan\nkenyamananmu.',
    ),
    OnboardingSlide(
      image: 'assets/images/onboarding/onboarding_3.png',
      title: 'Solusi Tuntas dengan\nHarga Adil',
      description:
          'Ajukan tugas dan sepakati harga\nterbaik langsung di dalam '
          'aplikasi\ntanpa ribet.',
    ),
  ];

  final _pageController = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLastPage) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _finish() {
    // TODO: simpan status onboarding sudah dilihat supaya tidak muncul lagi.
    final route = MaterialPageRoute<void>(builder: (_) => const LoginPage());
    Navigator.of(context).pushReplacement(route);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // ikon status bar gelap di latar putih
      child: Scaffold(
        body: SafeArea(
          // Jarak atas-bawah diukur dari tepi layar, sama seperti desain.
          // Kalau status bar atau navigation bar lebih tinggi, SafeArea
          // memakai tinggi bar tersebut.
          minimum: const EdgeInsets.only(top: 69, bottom: 60),
          child: Stack(
            children: [
              Padding(
                // Slide mulai tepat di bawah teks "Lewati" (100 dari atas).
                padding: const EdgeInsets.only(top: 31),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (page) =>
                            setState(() => _currentPage = page),
                        children: _slides,
                      ),
                    ),
                    const SizedBox(height: 32),
                    PageIndicator(count: _slides.length, current: _currentPage),
                    const SizedBox(height: 54),
                    // Tanpa glow (beda dengan PrimaryButton), sesuai desain.
                    SizedBox(
                      width: 280,
                      child: ElevatedButton(
                        onPressed: _next,
                        child: Text(_isLastPage ? 'Ayo Mulai' : 'Selanjutnya'),
                      ),
                    ),
                  ],
                ),
              ),
              // Teks berjarak 44 dari tepi kanan: 32 di sini + padding 12.
              PositionedDirectional(top: 0, end: 32, child: _buildSkipButton()),
            ],
          ),
        ),
      ),
    );
  }

  /// "Lewati" disembunyikan di halaman terakhir, sesuai desain.
  Widget _buildSkipButton() {
    return IgnorePointer(
      ignoring: _isLastPage,
      child: AnimatedOpacity(
        opacity: _isLastPage ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: TextButton(
          onPressed: _finish,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppTypography.style(
              size: AppTypography.body,
              weight: AppTypography.semiBold,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(48, 48), // area tap tetap nyaman
          ),
          child: const Text('Lewati'),
        ),
      ),
    );
  }
}
