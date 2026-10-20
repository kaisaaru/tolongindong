import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';
import '../home_assets.dart';
import '../home_metrics.dart';

/// Empat tab sesuai dokumen: Beranda, Cari Helper, Percakapan, Profil,
/// dengan tombol buat pesanan di tengah.
enum HomeTab { beranda, cariHelper, percakapan, profil }

/// Bilah navigasi mengambang berbentuk kaca buram: konten di belakangnya
/// tetap terlihat samar, persis seperti desain. Tab aktif ditandai lingkaran
/// putih pekat di belakang ikonnya.
///
/// Dipasang lewat `Scaffold.bottomNavigationBar` dengan `extendBody: true`,
/// jadi latarnya sendiri harus transparan.
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.current,
    required this.onSelected,
    this.onCreateOrder,
  });

  final HomeTab current;
  final ValueChanged<HomeTab> onSelected;
  final VoidCallback? onCreateOrder;

  /// Ruang yang perlu disisakan konten di bawahnya supaya item terakhir
  /// tidak tertutup bilah ini.
  static double clearanceOf(BuildContext context) =>
      math.max(MediaQuery.paddingOf(context).bottom, HomeMetrics.navBottomGap) +
      HomeMetrics.navHeight +
      16;

  static const _height = HomeMetrics.navHeight;
  static const _radius = _height / 2;

  // Warna diambil dari SVG ekspor Figma: ikon aktif hitam, sisanya #3F3F3F.
  static const _activeColor = Color(0xFF000000);
  static const _inactiveColor = Color(0xFF3F3F3F);

  @override
  Widget build(BuildContext context) {
    const center = HomeMetrics.navWidth / 2;
    final offsets = HomeMetrics.navIconOffsets;
    const tabs = [
      (HomeTab.beranda, 'Beranda'),
      (HomeTab.cariHelper, 'Cari Helper'),
      (HomeTab.percakapan, 'Percakapan'),
      (HomeTab.profil, 'Profil'),
    ];
    final activeIndex = tabs.indexWhere((t) => t.$1 == current);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: HomeMetrics.navBottomGap),
      child: Center(
        heightFactor: 1,
        // Tanpa bayangan: di balik kaca yang transparan, bayangan ikut tembus
        // dan membuat bilah tampak abu-abu. Desain juga tidak memakainya.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              width: HomeMetrics.navWidth,
              height: _height,
              color: AppColors.light.withValues(alpha: 0.7),
              child: Stack(
                children: [
                  // Lingkaran putih pekat di belakang tab aktif, setinggi bilah.
                  if (activeIndex >= 0)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      left: center + offsets[activeIndex] - _radius,
                      top: 0,
                      width: _height,
                      height: _height,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.light,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  for (var i = 0; i < tabs.length; i++)
                    _positioned(
                      centerX: center + offsets[i],
                      size: 44,
                      child: _NavItem(
                        label: tabs[i].$2,
                        onTap: () => onSelected(tabs[i].$1),
                        icon: _iconFor(
                          tabs[i].$1,
                          i == activeIndex ? _activeColor : _inactiveColor,
                        ),
                      ),
                    ),
                  _positioned(
                    centerX: center,
                    size: HomeMetrics.navFabSize,
                    child: _CreateOrderButton(onTap: onCreateOrder),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ukuran ikon disesuaikan dengan ukuran tintanya di desain:
  /// rumah 18,6 x 18, tas 21 x 21, chat 21 x 21, profil 15 x 19,2 (dp).
  static Widget _iconFor(HomeTab tab, Color color) => switch (tab) {
        HomeTab.beranda => _HomeIcon(color: color),
        HomeTab.cariHelper => CustomPaint(
            size: const Size.square(24),
            painter: _BagIconPainter(color),
          ),
        HomeTab.percakapan => _SvgIcon(HomeAssets.navChat, 21.6, color),
        HomeTab.profil => _SvgIcon(HomeAssets.navProfile, 20.4, color),
      };

  static Widget _positioned({
    required double centerX,
    required double size,
    required Widget child,
  }) =>
      Positioned(
        left: centerX - size / 2,
        top: (_height - size) / 2,
        width: size,
        height: size,
        child: child,
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.onTap});

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Center(child: icon),
      ),
    );
  }
}

class _SvgIcon extends StatelessWidget {
  const _SvgIcon(this.asset, this.height, this.color);

  final String asset;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      height: height,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// Ikon Beranda: rumah terisi dengan pintu melengkung di tengah bawah.
///
/// `Vector.svg` hanya berisi siluet rumahnya — pintu di desain adalah layer
/// terpisah yang tidak ikut terekspor, jadi digambar di sini dengan ukuran
/// hasil pengukuran (rumah 18,6 x 18 dp, pintu 6,6 x 7,8 dp).
class _HomeIcon extends StatelessWidget {
  const _HomeIcon({required this.color});

  final Color color;

  static const _size = 19.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        children: [
          SvgPicture.asset(
            HomeAssets.navHome,
            width: _size,
            height: _size,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          Positioned(
            // Viewbox 21 menyisakan 0,5 di tepi; alas rumah di 20,5/21.
            bottom: _size * 0.5 / 21,
            left: (_size - 6.6) / 2,
            width: 6.6,
            height: 7.8,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.light,
                borderRadius: BorderRadius.vertical(top: Radius.circular(3.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ikon tas "Cari Helper", digambar mengikuti peta piksel ikon di desain:
/// badan membulat, gagang di atas, garis tutup melengkung, dan kancing kecil
/// di tengahnya. Belum ada ekspor SVG-nya; kalau nanti tersedia, ganti saja.
class _BagIconPainter extends CustomPainter {
  const _BagIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Koordinat dalam dp pada kotak tinta 21,6 x 22,2, dipusatkan di 24 x 24.
    canvas.translate((size.width - 21.6) / 2, (size.height - 22.2) / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Badan tas.
    canvas.drawRRect(
      RRect.fromLTRBR(0.9, 5.7, 20.7, 21.3, const Radius.circular(3.3)),
      stroke,
    );
    // Gagang: kaki lurus turun ke badan, sudut atas membulat.
    canvas.drawPath(
      Path()
        ..moveTo(6.9, 5.7)
        ..lineTo(6.9, 2.7)
        ..arcToPoint(const Offset(8.7, 0.9), radius: const Radius.circular(1.8))
        ..lineTo(12.9, 0.9)
        ..arcToPoint(const Offset(14.7, 2.7), radius: const Radius.circular(1.8))
        ..lineTo(14.7, 5.7),
      stroke,
    );
    // Garis tutup melengkung dan kancingnya.
    canvas.drawPath(
      Path()
        ..moveTo(4.2, 9.9)
        ..quadraticBezierTo(10.5, 14.0, 16.8, 9.9),
      stroke,
    );
    canvas.drawLine(const Offset(10.5, 11.9), const Offset(10.5, 13.8), stroke);
  }

  @override
  bool shouldRepaint(_BagIconPainter old) => old.color != color;
}

class _CreateOrderButton extends StatelessWidget {
  const _CreateOrderButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buat pesanan',
      child: GestureDetector(
        onTap: onTap,
        // Asetnya sudah berupa lingkaran bergradasi merah (#FF4B4B ke
        // #FF7A7A) dengan tanda tambah, jadi tidak diberi warna ulang.
        child: SvgPicture.asset(
          HomeAssets.navCreateOrder,
          width: HomeMetrics.navFabSize,
          height: HomeMetrics.navFabSize,
        ),
      ),
    );
  }
}
