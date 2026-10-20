import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../home_assets.dart';
import '../home_metrics.dart';

/// Banner promo yang bisa digeser mendatar (FR-WLT-010).
///
/// Isinya masih statis: backend belum punya tabel voucher, jadi belum ada
/// endpoint untuk diambil. Begitu tersedia, cukup ganti [_banners] dengan
/// data dari server — bentuk widget-nya tidak perlu berubah.
class PromoCarousel extends StatelessWidget {
  const PromoCarousel({super.key, this.onTap});

  final ValueChanged<int>? onTap;

  static const _banners = [
    HomeAssets.promoBanner,
    HomeAssets.promoBanner,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeMetrics.bannerHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Banner kedua sengaja mengintip di tepi kanan, seperti desain.
        padding: const EdgeInsets.symmetric(horizontal: HomeMetrics.bodyPadding),
        itemCount: _banners.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: HomeMetrics.bannerGap),
        itemBuilder: (context, index) => GestureDetector(
          onTap: onTap == null ? null : () => onTap!(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(HomeMetrics.bannerRadius),
            child: Image.asset(
              _banners[index],
              width: HomeMetrics.bannerWidth,
              height: HomeMetrics.bannerHeight,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: HomeMetrics.bannerWidth,
                child: ColoredBox(color: AppColors.primaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
