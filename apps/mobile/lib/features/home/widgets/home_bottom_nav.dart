import 'dart:ui' show ImageFilter;

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
      MediaQuery.paddingOf(context).bottom +
      HomeMetrics.navBottomGap +
      HomeMetrics.navHeight +
      16;

  static const _radius = HomeMetrics.navHeight / 2;

  @override
  Widget build(BuildContext context) {
    const center = HomeMetrics.navWidth / 2;
    final offsets = HomeMetrics.navIconOffsets;

    final items = [
      (HomeTab.beranda, HomeAssets.navHome, null, 'Beranda'),
      (HomeTab.cariHelper, null, Icons.work_outline_rounded, 'Cari Helper'),
      (HomeTab.percakapan, HomeAssets.navChat, null, 'Percakapan'),
      (HomeTab.profil, HomeAssets.navProfile, null, 'Profil'),
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
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 6),
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
                color: AppColors.light.withValues(alpha: 0.72),
                child: Stack(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _positioned(
                        centerX: center + offsets[i],
                        size: 44,
                        child: _NavItem(
                          asset: items[i].$2,
                          fallbackIcon: items[i].$3,
                          label: items[i].$4,
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
  }) =>
      Positioned(
        left: centerX - size / 2,
        top: (HomeMetrics.navHeight - size) / 2,
        width: size,
        height: size,
        child: child,
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.asset,
    required this.fallbackIcon,
    required this.label,
    required this.onTap,
  });

  final String? asset;
  final IconData? fallbackIcon;
  final String label;
  final VoidCallback onTap;

  // Di desain semua ikon berwarna gelap; tab aktif (Beranda) dibedakan
  // oleh bentuk ikonnya yang terisi, bukan oleh warna.
  static const _color = AppColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    final path = asset;
    final icon = path != null
        ? SvgPicture.asset(
            path,
            height: 21,
            colorFilter: const ColorFilter.mode(_color, BlendMode.srcIn),
          )
        : Icon(fallbackIcon, size: 23, color: _color);

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
