import 'package:flutter/material.dart';

import '../../../core/format/rupiah.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../home_metrics.dart';

/// Satu kartu di daftar "Jasa tersedia": jasa yang ditawarkan seorang helper.
class ServiceOffer {
  const ServiceOffer({
    required this.title,
    required this.helperName,
    required this.rating,
    required this.price,
    required this.unit,
    required this.color,
  });

  final String title;
  final String helperName;
  final double rating;

  /// Harga dalam rupiah, bilangan bulat.
  final int price;

  /// Satuan harga, misalnya "tugas" atau "page".
  final String unit;

  /// Warna latar panel judul.
  final Color color;
}

/// Daftar mendatar jasa yang ditawarkan helper.
///
/// Isinya masih contoh statis: backend belum punya tabel jasa/listing.
/// `GET /helpers` hanya memberi nama, rating, dan tarif per jam — tanpa
/// judul jasa maupun satuan harga seperti di desain.
class ServiceOfferSection extends StatelessWidget {
  const ServiceOfferSection({super.key, this.items = _sample, this.onTap});

  final List<ServiceOffer> items;
  final ValueChanged<ServiceOffer>? onTap;

  static const _sample = [
    ServiceOffer(
      title: 'Joki Tugas Kuliah & Makalah Kilat',
      helperName: 'Agus Setiawan',
      rating: 5.0,
      price: 30000,
      unit: 'tugas',
      color: Color(0xFFFFCDCD),
    ),
    ServiceOffer(
      title: 'Desain UI/UX App & Dashboard',
      helperName: 'Jerry Markiy',
      rating: 4.9,
      price: 150000,
      unit: 'page',
      color: Color(0xFFCDD0FF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeMetrics.offerCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HomeMetrics.bodyPadding),
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: HomeMetrics.offerCardGap),
        itemBuilder: (context, index) {
          final item = items[index];
          return _OfferCard(
            item: item,
            onTap: onTap == null ? null : () => onTap!(item),
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.item, this.onTap});

  final ServiceOffer item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: HomeMetrics.offerCardWidth,
        padding: const EdgeInsets.all(HomeMetrics.offerCardPadding),
        decoration: BoxDecoration(
          color: AppColors.light,
          borderRadius: BorderRadius.circular(HomeMetrics.offerCardRadius),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: HomeMetrics.offerPanelHeight,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 12, 11, 10),
              decoration: BoxDecoration(
                color: item.color,
                borderRadius:
                    BorderRadius.circular(HomeMetrics.offerPanelRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: HomeMetrics.offerTitleSize,
                      weight: AppTypography.semiBold,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.helperName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            size: HomeMetrics.offerMetaSize,
                            weight: AppTypography.regular,
                          ),
                        ),
                      ),
                      const SizedBox(width: 22),
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: AppTypography.style(
                          size: HomeMetrics.offerMetaSize,
                          weight: AppTypography.regular,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: rupiah(item.price),
                      style: AppTypography.style(
                        size: HomeMetrics.offerPriceSize,
                        weight: AppTypography.semiBold,
                      ),
                    ),
                    TextSpan(
                      text: '/${item.unit}',
                      style: AppTypography.style(
                        size: HomeMetrics.offerPriceSize,
                        weight: AppTypography.regular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
