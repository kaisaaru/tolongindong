import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../models/auth_user.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../auth/auth_repository.dart';
import '../activity/activity_view.dart';
import '../auth/login_page.dart';
import '../chat/chat_list_view.dart';
import '../chat/chat_store.dart';
import '../delivery/delivery_page.dart';
import '../delivery/delivery_review_page.dart';
import '../household/active_order_page.dart';
import '../household/household_page.dart';
import '../order/category_helpers_page.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/personal_order_page.dart';
import 'catalog_repository.dart';
import 'home_assets.dart';
import 'home_metrics.dart';
import 'widgets/category_grid.dart';
import 'widgets/home_bottom_nav.dart';
import 'widgets/home_header.dart';
import 'widgets/promo_carousel.dart';
import 'widgets/service_offer_section.dart';

/// Beranda client (FR-PRF-004, FR-HLP-001, FR-NOT-001, FR-WLT-010).
///
/// Akun belum punya isi. Endpoint-nya (`/me`) sudah ada di backend, tinggal
/// layarnya dibangun.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    this.authRepo,
    this.catalogRepo,
    this.orderStore,
    this.chatStore,
  });

  final AuthUser user;

  /// Diisi hanya saat pengujian, supaya halaman bisa diuji tanpa server.
  final AuthRepository? authRepo;
  final CatalogRepository? catalogRepo;
  final OrderStore? orderStore;
  final ChatStore? chatStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _authRepo = widget.authRepo ?? AuthRepository();
  late final _catalogRepo = widget.catalogRepo ?? CatalogRepository();
  late final _orderStore = widget.orderStore ?? OrderStore.instance;
  late final _chatStore = widget.chatStore ?? ChatStore.instance;

  late Future<List<ServiceCategory>> _categories = _catalogRepo.categories();
  late AuthUser _user = widget.user;

  /// Null = belum dimuat atau user belum punya alamat.
  String? _address;
  int _unreadCount = 0;

  HomeTab _tab = HomeTab.beranda;

  /// Jarak banner dari bawah (10) + tinggi banner (±51), dilebihkan sedikit
  /// untuk font HP yang diperbesar.
  static const _bannerClearance = 80.0;

  @override
  void initState() {
    super.initState();
    _loadHeader();
  }

  /// Alamat dan notifikasi dimuat terpisah: kalau salah satu gagal, yang
  /// lain tetap tampil, dan header memakai nilai terakhirnya. Kegagalan apa
  /// pun ditelan — isi header bukan alasan beranda error.
  Future<void> _loadHeader() async {
    await Future.wait([
      _catalogRepo
          .primaryAddress()
          .then((address) {
            if (mounted) setState(() => _address = address);
          })
          .catchError((_) {}),
      _catalogRepo
          .unreadNotificationCount()
          .then((count) {
            if (mounted) setState(() => _unreadCount = count);
          })
          .catchError((_) {}),
    ]);
  }

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
    await Future.wait([
      _loadHeader(),
      reloaded.catchError((_) => <ServiceCategory>[]),
    ]);
  }

  Future<void> _logout() async {
    await _authRepo.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _soon(String feature) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature belum tersedia.')));

  void _openCategory(ServiceCategory category) {
    // Household dan Delivery punya alur sendiri; kategori lain masih daftar
    // helper.
    final Widget page = switch (category.code) {
      'household' => HouseholdPage(category: category),
      'delivery' => DeliveryPage(
        senderName: _user.fullName,
        senderPhone: _user.phoneNumber,
        store: _orderStore,
      ),
      _ => CategoryHelpersPage(category: category),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final nav = HomeBottomNav(
      current: _tab,
      onSelected: (tab) => setState(() => _tab = tab),
    );

    // Aktifitas dan Obrolan tidak memakai header merah: halaman penuh.
    if (_tab == HomeTab.aktifitas) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.light,
          body: ActivityView(store: _orderStore),
          bottomNavigationBar: nav,
        ),
      );
    }
    if (_tab == HomeTab.obrolan) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: OrderStyle.background,
          body: ChatListView(store: _chatStore),
          bottomNavigationBar: nav,
        ),
      );
    }

    final sheetTop = HomeHeader.sheetTopOf(context);

    // Ikon status bar putih di atas header merah.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.light,
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
                location: _address ?? 'Atur alamat',
                hasUnreadNotification: _unreadCount > 0,
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
            // Banner pesanan aktif melayang di atas bilah navigasi.
            if (_tab == HomeTab.beranda)
              ListenableBuilder(
                listenable: _orderStore,
                builder: (context, _) {
                  // Satu banner saja: Household (berwaktu) didahulukan,
                  // lalu Personal, lalu pengantaran terbaru.
                  final personal = _orderStore.personal;
                  final deliveries = _orderStore.deliveries;
                  final ActiveOrderTile tile;
                  if (_orderStore.active != null) {
                    tile = ActiveOrderTile(
                      title: 'Household',
                      status: activeStatusLabel(_orderStore),
                      elevated: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ActiveOrderPage(store: _orderStore),
                        ),
                      ),
                    );
                  } else if (personal != null) {
                    tile = ActiveOrderTile(
                      title: 'Personal',
                      status: personalStatusLabel(personal),
                      categoryCode: 'personal',
                      elevated: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PersonalOrderPage(store: _orderStore),
                        ),
                      ),
                    );
                  } else if (deliveries.isNotEmpty) {
                    final delivery = deliveries.first;
                    tile = ActiveOrderTile(
                      title: 'Delivery',
                      status: deliveryStatusLabel(delivery),
                      categoryCode: 'delivery',
                      elevated: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DeliveryReviewPage.placed(order: delivery),
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: 24,
                    right: 24,
                    bottom: 10,
                    child: tile,
                  );
                },
              ),
          ],
        ),
        bottomNavigationBar: nav,
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
              // Pesanan dimulai dari kategori (tidak ada tombol di nav).
              onCategoryTap: _openCategory,
              onHelperTap: () => _soon('Cari helper'),
            ),
          ),
          const SizedBox(height: HomeMetrics.sectionTopGap),
          const _SectionTitle('Jasa tersedia'),
          const SizedBox(height: HomeMetrics.titleToContent),
          ServiceOfferSection(onTap: (offer) => _soon(offer.title)),
          const SizedBox(height: HomeMetrics.sectionTopGap),
          const _SectionTitle('Penawaran Spesial'),
          const SizedBox(height: HomeMetrics.titleToContent),
          PromoCarousel(onTap: (_) => _soon('Voucher')),
          const SizedBox(height: HomeMetrics.sectionTopGap),
          const _SectionTitle('Seputar TolongDong'),
          const SizedBox(height: HomeMetrics.titleToContent),
          // Isi seksi ini terpotong di desain dan backend belum punya
          // endpoint artikel, jadi sementara penanda saja.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: HomeMetrics.bodyPadding),
            child: _ComingSoonCard('Info dan tips TolongDong segera hadir.'),
          ),
          // Banner pesanan aktif melayang di atas akhir daftar. Tanpa ruang
          // ini, isi paling bawah tertutup banner walau sudah digulir mentok.
          // Hanya bagian ini yang dibangun ulang tiap detik oleh store.
          ListenableBuilder(
            listenable: _orderStore,
            builder: (context, _) =>
                SizedBox(height: _orderStore.hasActive ? _bannerClearance : 0),
          ),
        ],
      ),
    );
  }

  /// Isi sementara untuk tab yang modulnya belum dibangun. Tombol keluar
  /// ditaruh di Akun supaya tetap terjangkau.
  Widget _buildPlaceholder() {
    // Aktifitas dan Obrolan punya halaman sendiri (lihat build); yang sampai
    // ke sini praktis hanya Akun.
    final label = switch (_tab) {
      HomeTab.aktifitas => 'Aktifitas',
      HomeTab.obrolan => 'Obrolan',
      HomeTab.akun => 'Akun',
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
            if (_tab == HomeTab.akun) ...[
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

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(HomeMetrics.offerCardRadius),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.style(
          size: AppTypography.small,
          weight: AppTypography.regular,
          color: AppColors.textDescription,
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
          const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
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

/// Baris kategori beserta keadaan memuat dan gagal.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categories,
    required this.onRetry,
    required this.onCategoryTap,
    required this.onHelperTap,
  });

  final Future<List<ServiceCategory>> categories;
  final VoidCallback onRetry;
  final ValueChanged<ServiceCategory> onCategoryTap;
  final VoidCallback onHelperTap;

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
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        // Urutan tampil mengikuti desain, bukan urutan id dari server.
        final sorted = [...?snapshot.data]
          ..sort(
            (a, b) => HomeAssets.orderOf(
              a.code,
            ).compareTo(HomeAssets.orderOf(b.code)),
          );

        final tiles = [
          for (final category in sorted)
            CategoryTile.fromCategory(
              category,
              onTap: () => onCategoryTap(category),
            ),
          // Ubin terakhir bukan kategori layanan, jadi ditambahkan di sini
          // dan tidak ikut bergantung pada data server.
          CategoryTile(
            label: 'Helper',
            assetPath: HomeAssets.helperTile,
            onTap: onHelperTap,
          ),
        ];

        return CategoryGrid(tiles: tiles);
      },
    );
  }
}
