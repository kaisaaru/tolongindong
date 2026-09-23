import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Dua gelombang di bawah splash: pink muda di belakang, merah di depan.
///
/// Lebarnya selebar layar, tingginya ikut rasio desain supaya bentuk kurva
/// tidak gepeng di HP yang lebih kecil atau lebih lebar.
class SplashWaves extends StatelessWidget {
  const SplashWaves({super.key});

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: _WavesPainter.designWidth / _WavesPainter.designHeight,
      child: CustomPaint(painter: _WavesPainter()),
    );
  }
}

class _WavesPainter extends CustomPainter {
  const _WavesPainter();

  // Titik kurva diukur dari desain (frame 412x917, gelombang mulai di y 533.5),
  // lalu di-scale mengikuti ukuran canvas.
  static const double designWidth = 412;
  static const double designHeight = 383.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / designWidth, size.height / designHeight);

    const bottom = designHeight;
    final back = Path()
      ..moveTo(0, 0)
      ..cubicTo(32, 4, 117, 53, 197, 61)
      ..cubicTo(225, 50, 255, 44, 283, 44)
      ..cubicTo(315, 44, 345, 75, 345, 110)
      ..lineTo(345, bottom)
      ..lineTo(0, bottom)
      ..close();
    final front = Path()
      ..moveTo(8, bottom)
      ..cubicTo(48, 279, 118, 224, 225, 219)
      ..cubicTo(285, 216, 362, 189.5, designWidth, 173.5)
      ..lineTo(designWidth, bottom)
      ..close();

    canvas.drawPath(back, Paint()..color = AppColors.primaryLight);
    canvas.drawPath(front, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_WavesPainter oldDelegate) => false;
}
