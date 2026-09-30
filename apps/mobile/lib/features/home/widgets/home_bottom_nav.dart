import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';
import '../home_assets.dart';
import '../home_metrics.dart';

/// Empat tab sesuai dokumen: Beranda, Cari Helper, Percakapan, Profil,
/// dengan tombol buat pesanan di tengah.
enum HomeTab { beranda, cariHelper, percakapan, profil }

/// Bilah navigasi mengambang berbentuk pil kaca: konten di belakangnya
/// tetap terlihat samar, seperti desain.
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

  static const _radius = HomeMetrics.navHeight / 2;

  // Di desain semua ikon berwarna gelap; tab aktif (Beranda) dibedakan oleh
  // ikonnya yang terisi, bukan oleh warna.
  static const _iconColor = AppColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    const center = HomeMetrics.navWidth / 2;
    final offsets = HomeMetrics.navIconOffsets;

    final items = <(HomeTab, Widget, String)>[
      (HomeTab.beranda, const _HomeIcon(), 'Beranda'),
      (
        HomeTab.cariHelper,
        const Icon(CupertinoIcons.briefcase, size: 24, color: _iconColor),
        'Cari Helper',
      ),
      (HomeTab.percakapan, const _SvgIcon(HomeAssets.navChat), 'Percakapan'),
      (HomeTab.profil, const _SvgIcon(HomeAssets.navProfile), 'Profil'),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: HomeMetrics.navBottomGap),
      child: Center(
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: HomeMetrics.navWidth,
                height: HomeMetrics.navHeight,
                color: AppColors.light.withValues(alpha: 0.8),
                child: Stack(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _positioned(
                        centerX: center + offsets[i],
                        size: 44,
                        child: _NavItem(
                          icon: items[i].$2,
                          label: items[i].$3,
                          onTap: () => onSelected(items[i].$1),
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
      ),
    );
  }

  static Widget _positioned({
    required double centerX,
    required double size,
    required Widget child,
  }) => Positioned(
    left: centerX - size / 2,
    top: (HomeMetrics.navHeight - size) / 2,
    width: size,
    height: size,
    child: child,
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
  const _SvgIcon(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      height: 21,
      colorFilter: const ColorFilter.mode(
        HomeBottomNav._iconColor,
        BlendMode.srcIn,
      ),
    );
  }
}

/// Ikon Beranda: rumah terisi dengan pintu melengkung di tengah bawah.
///
/// `Vector.svg` hanya berisi siluet rumahnya — pintu di desain adalah layer
/// terpisah yang tidak ikut terekspor, jadi digambar di sini dengan ukuran
/// hasil pengukuran (rumah 18,6 x 18 dp, pintu 6,6 x 7,8 dp).
class _HomeIcon extends StatelessWidget {
  const _HomeIcon();

  static const _size = 19.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        children: [
          const _SvgIconSized(HomeAssets.navHome, _size),
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

class _SvgIconSized extends StatelessWidget {
  const _SvgIconSized(this.asset, this.size);

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(
        HomeBottomNav._iconColor,
        BlendMode.srcIn,
      ),
    );
  }
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
        // Asetnya sudah berupa lingkaran bergradasi merah dengan tanda
        // tambah, jadi tidak diberi warna ulang.
        child: SvgPicture.asset(
          HomeAssets.navCreateOrder,
          width: HomeMetrics.navFabSize,
          height: HomeMetrics.navFabSize,
        ),
      ),
    );
  }
}
