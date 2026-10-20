import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/service_category.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../home_assets.dart';
import '../home_metrics.dart';

/// Satu ubin di grid kategori. Dipakai untuk kategori dari server maupun
/// dua ubin statis di akhir (Helper dan Lainnya).
class CategoryTile {
  const CategoryTile({
    required this.label,
    required this.assetPath,
    this.onTap,
  });

  final String label;

  /// PNG berisi kartu lengkap (latar, blob pink, ilustrasi) dengan sudut
  /// transparan. SVG berisi ikon polos, jadi ubin yang menggambar kartunya.
  /// Null berarti belum ada ilustrasinya.
  final String? assetPath;

  final VoidCallback? onTap;

  bool get _isCardArt => assetPath?.toLowerCase().endsWith('.png') ?? false;

  factory CategoryTile.fromCategory(
    ServiceCategory category, {
    VoidCallback? onTap,
  }) =>
      CategoryTile(
        label: HomeAssets.displayName(category.code, category.name),
        assetPath: HomeAssets.categoryIcon(category.code),
        onTap: onTap,
      );
}

/// Grid 4 kolom berisi enam kategori layanan (FR-HLP-001) ditambah pintasan
/// Helper dan Lainnya.
///
/// Ubin berukuran tetap 69 dp dengan jarak tetap, bukan dibagi rata ke lebar
/// layar — di desain ukurannya memang tidak berubah mengikuti lebar.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.tiles});

  final List<CategoryTile> tiles;

  static const _perRow = 4;

  /// Tinggi total dua baris, dipakai penanda memuat supaya layar tidak
  /// melompat saat kategori selesai dimuat.
  static const height = 2 *
          (HomeMetrics.tileSize +
              HomeMetrics.tileLabelGap +
              HomeMetrics.tileLabelSize) +
      HomeMetrics.tileRowGap;

  @override
  Widget build(BuildContext context) {
    final rows = <List<CategoryTile>>[
      for (var i = 0; i < tiles.length; i += _perRow)
        tiles.sublist(i, (i + _perRow).clamp(0, tiles.length)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: HomeMetrics.tileRowGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < rows[r].length; c++) ...[
                if (c > 0) const SizedBox(width: HomeMetrics.tileGap),
                _Tile(tile: rows[r][c]),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile});

  final CategoryTile tile;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tile.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: HomeMetrics.tileSize,
        child: Column(
          children: [
            DecoratedBox(
              // Bayangan merata di keempat sisi, sesuai profil yang diukur
              // dari Figma: tanpa offset, sigma ~4,2 dp, hitam 15%.
              // blurRadius 6,4 -> sigma = 6,4 x 0,577 + 0,5 = 4,2 dp.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HomeMetrics.tileRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6.4,
                  ),
                ],
              ),
              child: SizedBox.square(
                dimension: HomeMetrics.tileSize,
                child: _TileArt(tile: tile),
              ),
            ),
            const SizedBox(height: HomeMetrics.tileLabelGap),
            Text(
              tile.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: AppTypography.style(
                size: HomeMetrics.tileLabelSize,
                weight: AppTypography.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileArt extends StatelessWidget {
  const _TileArt({required this.tile});

  final CategoryTile tile;

  @override
  Widget build(BuildContext context) {
    final path = tile.assetPath;
    if (path == null) return _Card(child: _MissingArt(label: tile.label));

    if (tile._isCardArt) {
      return Image.asset(
        path,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _Card(child: _MissingArt(label: tile.label)),
      );
    }

    return _Card(
      child: Center(
        child: SvgPicture.asset(
          path,
          width: 36,
          height: 37,
          placeholderBuilder: (_) => _MissingArt(label: tile.label),
        ),
      ),
    );
  }
}

/// Kartu untuk ikon yang tidak membawa latarnya sendiri. Warnanya sama
/// dengan latar kartu di ilustrasi PNG supaya semua ubin seragam.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomeAssets.tileCardColor,
        borderRadius: BorderRadius.circular(HomeMetrics.tileRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Penanda ilustrasi yang belum ada: huruf awal kategori di atas latar pink.
class _MissingArt extends StatelessWidget {
  const _MissingArt({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();

    return ColoredBox(
      color: AppColors.primaryLight,
      child: Center(
        child: Text(
          initial,
          style: AppTypography.style(
            size: AppTypography.h6,
            weight: AppTypography.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
