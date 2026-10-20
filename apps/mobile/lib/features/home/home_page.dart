import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../models/auth_user.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../auth/auth_repository.dart';
import '../auth/login_page.dart';
import 'catalog_repository.dart';
import 'home_assets.dart';
import 'home_metrics.dart';
import 'widgets/category_grid.dart';
import 'widgets/favorite_food_section.dart';
import 'widgets/home_bottom_nav.dart';
import 'widgets/home_header.dart';
import 'widgets/promo_carousel.dart';

/// Beranda client (FR-PRF-004, FR-HLP-001, FR-NOT-001, FR-WLT-010).
///
/// Tab selain Beranda belum punya isi: modul pesanan, percakapan, dan
/// pencarian helper masih menunggu tabelnya dibuat di backend.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    this.authRepo,
    this.catalogRepo,
  });

  final AuthUser user;

  /// Diisi hanya saat pengujian, supaya halaman bisa diuji tanpa server.
  final AuthRepository? authRepo;
  final CatalogRepository? catalogRepo;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _authRepo = widget.authRepo ?? AuthRepository();
  late final _catalogRepo = widget.catalogRepo ?? CatalogRepository();

  late Future<List<ServiceCategory>> _categories = _catalogRepo.categories();
  late AuthUser _user = widget.user;

  HomeTab _tab = HomeTab.beranda;

  Future<void> _refresh() async {
    final reloaded = _catalogRepo.categories();
    setState(() => _categories = reloaded);

    try {
      final fresh = await _authRepo.me();
      if (mounted) setState(() => _user = fresh);
    } on ApiException {
      // Profil gagal dimuat ulang bukan alasan mengosongkan beranda —
      // data lama tetap dipakai.
    }
    await reloaded.catchError((_) => <ServiceCategory>[]);
  }

  Future<void> _logout() async {
    await _authRepo.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _soon(String feature) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$feature belum tersedia.')),
      );

  @override
  Widget build(BuildContext context) {
    final sheetTop = HomeHeader.sheetTopOf(context);

    // Ikon status bar putih di atas header merah.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.light,
        // Konten menggulir di balik bilah navigasi yang mengambang.
        extendBody: true,
        // Semua anak diposisikan, jadi Stack mengambil ukuran layar penuh.
        // Kalau header dibiarkan tidak diposisikan, tinggi Stack ikut tinggi
        // header dan lembar putih di bawahnya terpotong.
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: HomeHeader(
                user: _user,
                onNotificationTap: () => _soon('Notifikasi'),
              ),
            ),
            Positioned.fill(
              top: sheetTop,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(HomeMetrics.sheetRadius),
                ),
                child: ColoredBox(
                  color: AppColors.light,
                  child: _tab == HomeTab.beranda
                      ? _buildBeranda()
                      : _buildPlaceholder(),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: HomeBottomNav(
          current: _tab,
          onSelected: (tab) => setState(() => _tab = tab),
          onCreateOrder: () => _soon('Buat pesanan'),
        ),
      ),
    );
  }

  Widget _buildBeranda() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.only(
          top: HomeMetrics.searchTopGap,
          bottom: HomeBottomNav.clearanceOf(context),
        ),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: HomeMetrics.searchSideInset,
            ),
            child: _SearchBar(),
          ),
          const SizedBox(height: HomeMetrics.gridTopGap),
          Padding(
            padding: const EdgeInsets.only(left: HomeMetrics.bodyPadding),
            child: _CategorySection(
              categories: _categories,
              onRetry: () =>
                  setState(() => _categories = _catalogRepo.categories()),
              onCategoryTap: _soon,
            ),
          ),
          const SizedBox(height: HomeMetrics.promoTopGap),
          const _SectionTitle('Penawaran Spesial'),
          const SizedBox(height: HomeMetrics.titleToBanner),
          PromoCarousel(onTap: (_) => _soon('Voucher')),
          const SizedBox(height: HomeMetrics.foodTopGap),
          const _SectionTitle('Makanan Favorit'),
          const SizedBox(height: HomeMetrics.titleToCards),
          FavoriteFoodSection(onTap: (food) => _soon(food.name)),
        ],
      ),
    );
  }

  /// Isi sementara untuk tab yang modulnya belum dibangun. Tombol keluar
  /// ditaruh di Profil supaya tetap terjangkau.
  Widget _buildPlaceholder() {
    final label = switch (_tab) {
      HomeTab.cariHelper => 'Cari Helper',
      HomeTab.percakapan => 'Percakapan',
      HomeTab.profil => 'Profil',
      HomeTab.beranda => 'Beranda',
    };

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          HomeBottomNav.clearanceOf(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.style(
                size: AppTypography.h6,
                weight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Modul ini belum dibangun.',
              textAlign: TextAlign.center,
              style: AppTypography.style(
                size: AppTypography.small,
                weight: AppTypography.regular,
                color: AppColors.textDescription,
              ),
            ),
            if (_tab == HomeTab.profil) ...[
              const SizedBox(height: 28),
              Text(
                _user.email,
                style: AppTypography.style(
                  size: AppTypography.small,
                  weight: AppTypography.medium,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _logout, child: const Text('Keluar')),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HomeMetrics.bodyPadding),
      child: Text(
        text,
        style: AppTypography.style(
          size: HomeMetrics.sectionTitleSize,
          weight: AppTypography.bold,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final hintStyle = AppTypography.style(
      size: HomeMetrics.searchTextSize,
      weight: AppTypography.regular,
      color: AppColors.textSecondary,
    );

    return Container(
      height: HomeMetrics.searchHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(HomeMetrics.searchRadius),
        border: Border.all(
          color: AppColors.border,
          width: HomeMetrics.searchBorder,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration.collapsed(
                hintText: 'Cari kebutuhanmu',
                hintStyle: hintStyle,
              ),
              style: hintStyle.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid kategori beserta keadaan memuat dan gagal.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categories,
    required this.onRetry,
    required this.onCategoryTap,
  });

  final Future<List<ServiceCategory>> categories;
  final VoidCallback onRetry;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceCategory>>(
      future: categories,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: CategoryGrid.height,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final error = snapshot.error;
        if (error != null) {
          return SizedBox(
            height: CategoryGrid.height,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is ApiException
                        ? error.message
                        : 'Kategori layanan gagal dimuat.',
                    textAlign: TextAlign.center,
                    style: AppTypography.style(
                      size: AppTypography.small,
                      weight: AppTypography.regular,
                      color: AppColors.textDescription,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
                ],
              ),
            ),
          );
        }

        // Urutan tampil mengikuti desain, bukan urutan id dari server.
        final sorted = [...?snapshot.data]
          ..sort((a, b) =>
              HomeAssets.orderOf(a.code).compareTo(HomeAssets.orderOf(b.code)));

        final tiles = [
          for (final category in sorted)
            CategoryTile.fromCategory(
              category,
              onTap: () => onCategoryTap(category.name),
            ),
          // Dua ubin terakhir bukan kategori layanan, jadi ditambahkan di sini
          // dan tidak ikut bergantung pada data server.
          CategoryTile(
            label: 'Helper',
            assetPath: HomeAssets.helperTile,
            onTap: () => onCategoryTap('Cari Helper'),
          ),
          CategoryTile(
            label: 'Lainnya',
            assetPath: HomeAssets.lainnyaTile,
            onTap: () => onCategoryTap('Kategori lainnya'),
          ),
        ];

        return CategoryGrid(tiles: tiles);
      },
    );
  }
}
