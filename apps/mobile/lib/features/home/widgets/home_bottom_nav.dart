import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../home_assets.dart';
import '../home_metrics.dart';

/// Empat tab sesuai desain: Beranda, Aktifitas, Obrolan, Akun. Pesanan
/// dibuat dari ubin kategori di beranda, jadi tidak ada tombol di tengah.
enum HomeTab { beranda, aktifitas, obrolan, akun }

/// Bilah navigasi putih selebar layar dengan garis tipis di atasnya. Tab
/// aktif ditandai ikon dan label berwarna merah.
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final HomeTab current;
  final ValueChanged<HomeTab> onSelected;

  /// Ruang di bawah item terakhir konten. Bilah ini tidak menutupi konten,
  /// jadi cukup jarak napas biasa.
  static double clearanceOf(BuildContext context) => 16;

  static const _tabs = [
    (HomeTab.beranda, 'Beranda'),
    (HomeTab.aktifitas, 'Aktifitas'),
    (HomeTab.obrolan, 'Obrolan'),
    (HomeTab.akun, 'Akun'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.light,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: HomeMetrics.navHeight,
          child: Row(
            children: [
              for (final (tab, label) in _tabs)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    label: label,
                    active: tab == current,
                    onTap: () => onSelected(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final HomeTab tab;
  final String label;
  final bool active;
  final VoidCallback onTap;

  static const _inactiveColor = AppColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : _inactiveColor;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: HomeMetrics.navIconSize,
              child: Center(child: _icon(color)),
            ),
            const SizedBox(height: HomeMetrics.navLabelGap),
            Text(
              label,
              style: AppTypography.style(
                size: HomeMetrics.navLabelSize,
                weight: AppTypography.semiBold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tinggi mengikuti ukuran viewBox ekspor Figma.
  Widget _icon(Color color) => switch (tab) {
        HomeTab.beranda => _SvgIcon(HomeAssets.navHome, 25, color),
        HomeTab.aktifitas => _SvgIcon(HomeAssets.navActivity, 26, color),
        HomeTab.obrolan => _SvgIcon(HomeAssets.navChat, 29, color),
        HomeTab.akun => _SvgIcon(HomeAssets.navProfile, 30, color),
      };
}

/// Ikon SVG yang garisnya diwarnai ulang. Tidak memakai `colorFilter`
/// karena itu juga mewarnai isi putih ikon (badan rumah, pena) sehingga
/// ikonnya jadi pejal.
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
      colorMapper: _InkColorMapper(color),
    );
  }
}

/// Mengganti semua warna selain putih dengan [color].
class _InkColorMapper extends ColorMapper {
  const _InkColorMapper(this.color);

  final Color color;

  static const _white = Color(0xFFFFFFFF);

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) =>
      color == _white ? color : this.color;
}
