import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../order_style.dart';
import 'order_widgets.dart';

/// Halaman "Beri reting helper", dipakai pesanan Household dan Personal.
///
/// Ukuran diukur dari desain (frame 412 dp, status bar 52 dp): kartu mulai
/// 180 dp di bawah status bar, 37 dp dari tepi layar; cincin kiri berpusat
/// 86 dp dari kiri dan 155 dp di bawah tepi atas kartu, sebagian tertutup
/// kartu.
class HelperRatingView extends StatelessWidget {
  const HelperRatingView({
    super.key,
    required this.name,
    required this.onRate,
    this.photoUrl,
  });

  final String name;
  final String? photoUrl;
  final ValueChanged<int> onRate;

  static const _cardTop = 180.0; // di bawah status bar
  static const _cardSide = 37.0;

  @override
  Widget build(BuildContext context) {
    final cardTop = MediaQuery.paddingOf(context).top + _cardTop;

    return Scaffold(
      backgroundColor: AppColors.light,
      body: CustomPaint(
        painter: _RatingRingsPainter(cardTop: cardTop),
        child: Stack(
          children: [
            Positioned(
              top: cardTop,
              left: _cardSide,
              right: _cardSide,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000), // hitam 20%
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Beri reting helper',
                      style: AppTypography.style(
                        size: 14,
                        weight: AppTypography.semiBold,
                      ),
                    ),
                    const SizedBox(height: 23),
                    HelperAvatar(name: name, photoUrl: photoUrl, size: 48),
                    const SizedBox(height: 11),
                    Text(
                      name,
                      style: AppTypography.style(
                        size: 14,
                        weight: AppTypography.regular,
                      ),
                    ),
                    const SizedBox(height: 17),
                    _StarPicker(onPicked: onRate),
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

/// Dua cincin merah bergradasi (merah di kiri bawah, memudar ke putih di
/// kanan atas), sama seperti cincin SVG di Detail Pesanan.
class _RatingRingsPainter extends CustomPainter {
  const _RatingRingsPainter({required this.cardTop});

  final double cardTop;

  void _ring(Canvas canvas, Offset center, double radius, double stroke) {
    final rect = Rect.fromCircle(center: center, radius: radius + stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFFFF4B4B), Color(0xFFFFFFFF)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Cincin kiri: diameter luar 232 dp, tebal 45 dp.
    _ring(canvas, Offset(86, cardTop + 155), 93.5, 45);
    // Cincin besar di kanan bawah, berpusat di luar layar.
    final w = size.width;
    _ring(canvas, Offset(w * 0.98, size.height + 55), w * 0.55, w * 0.17);
  }

  @override
  bool shouldRepaint(_RatingRingsPainter old) => old.cardTop != cardTop;
}

/// Lima bintang abu-abu; mengetuk bintang ke-n memberi rating n.
class _StarPicker extends StatefulWidget {
  const _StarPicker({required this.onPicked});

  final ValueChanged<int> onPicked;

  @override
  State<_StarPicker> createState() => _StarPickerState();
}

class _StarPickerState extends State<_StarPicker> {
  int _value = 0;

  Future<void> _pick(int value) async {
    setState(() => _value = value);
    // Jeda singkat supaya bintang terisi sempat terlihat.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) widget.onPicked(value);
  }

  @override
  Widget build(BuildContext context) {
    // Bintang 39 dp berjarak 8 dp, memakai aset bintang yang sama dengan
    // komponen "Rating / Bintang" di desain. Di layar 320 dp kartu lebih
    // sempit dari 235 dp, jadi deretan bintang diperkecil utuh.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Semantics(
              button: true,
              label: 'Beri $i bintang',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: _value == 0 ? () => _pick(i) : null,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OrderIcon(
                    OrderStyle.iconStar,
                    size: 39,
                    color: i <= _value
                        ? AppColors.primary
                        : const Color(0xFFD9D9D9),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
