import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../home_metrics.dart';

/// Satu kartu di daftar "Makanan Favorit".
class FavoriteFood {
  const FavoriteFood({
    required this.name,
    required this.rating,
    required this.ratingCount,
    this.imageUrl,
  });

  final String name;
  final double rating;
  final String ratingCount;

  /// Belum ada foto makanan di folder aset, jadi untuk sekarang selalu null
  /// dan kartu menampilkan latar penanda.
  final String? imageUrl;
}

/// Daftar mendatar rekomendasi makanan.
///
/// Data masih contoh. Bagian ini menunggu modul pesanan di backend —
/// tabelnya belum ada, jadi belum ada yang bisa diambil. Struktur kartunya
/// sudah final, tinggal ganti sumber datanya.
class FavoriteFoodSection extends StatelessWidget {
  const FavoriteFoodSection({super.key, this.items = _sample, this.onTap});

  final List<FavoriteFood> items;
  final ValueChanged<FavoriteFood>? onTap;

  static const _sample = [
    FavoriteFood(name: 'Mie Gacoan Sudirman', rating: 4.8, ratingCount: '100+'),
    FavoriteFood(name: 'Kebab Turki Baba Rafi', rating: 4.6, ratingCount: '100+'),
    FavoriteFood(name: 'Shiraku Ramen Kalibirus', rating: 5.0, ratingCount: '200+'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeMetrics.foodCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HomeMetrics.bodyPadding),
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: HomeMetrics.foodCardGap),
        itemBuilder: (context, index) {
          final item = items[index];
          return _FoodCard(
            item: item,
            onTap: onTap == null ? null : () => onTap!(item),
          );
        },
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.item, this.onTap});

  final FavoriteFood item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: HomeMetrics.foodCardWidth,
        padding: const EdgeInsets.all(HomeMetrics.foodCardPadding),
        decoration: BoxDecoration(
          color: AppColors.light,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: HomeMetrics.foodImageHeight,
                width: double.infinity,
                child: _FoodImage(url: item.imageUrl),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                size: AppTypography.small,
                weight: AppTypography.semiBold,
                height: 1.3,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${item.rating} · ${item.ratingCount} rating',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: AppTypography.tiny,
                      weight: AppTypography.regular,
                      color: AppColors.textDescription,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _FoodImage extends StatelessWidget {
  const _FoodImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) {
      return const ColoredBox(
        color: AppColors.primaryLight,
        child: Center(
          child: Icon(
            Icons.restaurant_rounded,
            color: AppColors.primary,
            size: 28,
          ),
        ),
      );
    }

    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.primaryLight),
    );
  }
}
