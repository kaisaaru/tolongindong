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
    this.imageAsset,
    this.imageUrl,
  });

  final String name;
  final double rating;
  final String ratingCount;

  /// Foto lokal di `assets/`, untuk data contoh.
  final String? imageAsset;

  /// Foto dari server, untuk data sungguhan nanti.
  final String? imageUrl;
}

/// Daftar mendatar rekomendasi makanan.
///
/// Belum ada sumber data: backend belum punya tabel produk atau pesanan, dan
/// foto makanan di desain belum diekspor ke `assets/`. Jadi untuk sekarang
/// isinya contoh tanpa foto, dan kartu menampilkan penanda "belum ada foto".
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
                child: _FoodImage(item: item),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                size: HomeMetrics.foodTitleSize,
                weight: AppTypography.regular,
                height: 1.33,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: HomeMetrics.foodStarSize,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${item.rating.toStringAsFixed(1)} · ${item.ratingCount} rating',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: HomeMetrics.foodRatingSize,
                      weight: AppTypography.medium,
                      color: HomeMetrics.foodRatingColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// Foto kartu dengan tiga keadaan yang bisa dibedakan sekilas:
/// belum ada foto (ikon alat makan), sedang memuat (spinner), dan gagal
/// dimuat (ikon gambar rusak).
class _FoodImage extends StatelessWidget {
  const _FoodImage({required this.item});

  final FavoriteFood item;

  @override
  Widget build(BuildContext context) {
    final asset = item.imageAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        // Berkas aset yang belum ditambahkan sama artinya dengan belum ada foto.
        errorBuilder: (_, _, _) => const _ImageState.empty(),
      );
    }

    final url = item.imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _ImageState.loading(),
        errorBuilder: (_, _, _) => const _ImageState.error(),
      );
    }

    return const _ImageState.empty();
  }
}

class _ImageState extends StatelessWidget {
  const _ImageState.empty() : _kind = _Kind.empty;
  const _ImageState.loading() : _kind = _Kind.loading;
  const _ImageState.error() : _kind = _Kind.error;

  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primaryLight,
      child: Center(
        child: switch (_kind) {
          _Kind.empty => const Icon(
              Icons.restaurant_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          _Kind.loading => const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          _Kind.error => const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textDescription,
              size: 26,
            ),
        },
      ),
    );
  }
}

enum _Kind { empty, loading, error }
