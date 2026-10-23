import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_scope.dart';
import '../../core/api/api_exception.dart';
import '../../models/auth_user.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../account/account_view.dart';
import '../account/change_password_page.dart';
import '../activity/activity_view.dart';
import '../auth/login_page.dart';
import '../auth/session_store.dart';
import '../chat/chat_list_view.dart';
import '../chat/chat_store.dart';
import '../delivery/delivery_page.dart';
import '../household/household_page.dart';
import '../notification/notification_page.dart';
import '../order/category_helpers_page.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/order_detail_page.dart';
import '../wallet/wallet_page.dart';
import 'catalog_repository.dart';
import 'home_assets.dart';
import 'home_metrics.dart';
import 'widgets/category_grid.dart';
import 'widgets/home_bottom_nav.dart';
import 'widgets/home_header.dart';
import 'widgets/promo_carousel.dart';
import 'widgets/service_offer_section.dart';
import 'widgets/tips_section.dart';

/// Beranda client (FR-PRF-004, FR-HLP-001, FR-NOT-001, FR-WLT-010).
///
/// Pengguna dari [SessionStore]; repository dan store pesanan/obrolan dari
/// [AppScope] (lihat `app_scope.dart`).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _catalogRepo = context.read<CatalogRepository>();
  late final _orderStore = context.read<OrderStore>();

  late Future<List<ServiceCategory>> _categories = _catalogRepo.categories();

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
    // Pesanan berjalan untuk banner di bawah beranda.
    WidgetsBinding.instance.addPostFrameCallback((_) => _orderStore.refresh());
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
    // Blok, bukan `=>`: closure setState tidak boleh mengembalikan Future.
    setState(() {
      _categories = reloaded;
    });

    await Future.wait([
      context.read<SessionStore>().refresh(),
      _orderStore.refresh(),
      _loadHeader(),
      reloaded.catchError((_) => <ServiceCategory>[]),
    ]);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationPage()));
    // Titik merah di lonceng mengikuti yang baru dibaca.
    if (mounted) await _loadHeader();
  }

  // Saldo di tab Akun ikut berubah sendiri: TD-Wallet memperbarui
  // SessionStore setelah isi saldo.
  void _openWallet() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const WalletPage()));

  void _openChangePassword() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordPage()));

  Future<void> _logout() async {
    // Diambil sebelum menunggu: context tidak dipakai lagi setelah await.
    final session = context.read<SessionStore>();
    final chats = context.read<ChatStore>();
    final navigator = Navigator.of(context);

    await session.signOut();
    // Pesanan dan obrolan akun ini tidak boleh terlihat akun berikutnya.
    _orderStore.reset();
    chats.reset();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _goTo(HomeTab tab) => setState(() => _tab = tab);

  void _soon(String feature) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature belum tersedia.')));

  void _openCategory(ServiceCategory category) {
    // Household dan Delivery punya alur sendiri; kategori lain masih daftar
    // helper.
    final Widget page = switch (category.code) {
      'household' => HouseholdPage(category: category),
      'delivery' => DeliveryPage(category: category),
      _ => CategoryHelpersPage(category: category),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Kategori yang sudah dimuat, atau kosong kalau gagal dimuat.
  Future<List<ServiceCategory>> _loadedCategories() async {
    try {
      return await _categories;
    } on Object {
      return const [];
    }
  }

  /// Kartu "Jasa tersedia" adalah jasa Personal: buka daftar helpernya.
  Future<void> _openOffer(ServiceOffer offer) async {
    final categories = await _loadedCategories();
    if (!mounted) return;
    final personal = categories.where((c) => c.code == 'personal').firstOrNull;
    if (personal == null) return _soon(offer.title);
    _openCategory(personal);
  }

  /// Kata yang biasa diketik per kategori. Backend belum punya pencarian
  /// layanan, jadi kolom cari mengarahkan ke kategori yang cocok.
  static const _keywords = <String, List<String>>{
    'delivery': ['kirim', 'antar', 'paket', 'barang', 'kurir', 'dokumen'],
    'household': [
      'rumah',
      'kamar',
      'pindah',
      'bersih',
      'cuci',
      'pakaian',
      'laundry',
      'setrika',
    ],
    'personal': ['tugas', 'desain', 'website', 'skripsi', 'joki', 'makalah'],
  };

  Future<void> _search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();

    bool matches(ServiceCategory c) =>
        c.name.toLowerCase().contains(q) ||
        (_keywords[c.code] ?? const []).any(
          (k) => q.contains(k) || (q.length >= 3 && k.startsWith(q)),
        );

    final categories = await _loadedCategories();
    if (!mounted) return;
    final match = categories.where(matches).firstOrNull;
    if (match == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Belum ada layanan untuk "${query.trim()}".')),
        );
      return;
    }
    _openCategory(match);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionStore>().user;
    // Sesaat setelah keluar akun, sebelum pindah ke halaman masuk.
    if (user == null) return const Scaffold(backgroundColor: AppColors.light);

    // Tombol kembali Android di tab lain membawa ke Beranda dulu, bukan
    // langsung menutup aplikasi.
    return PopScope(
      canPop: _tab == HomeTab.beranda,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = HomeTab.beranda);
      },
      child: _buildTab(context, user),
    );
  }

  Widget _buildTab(BuildContext context, AuthUser user) {
    final nav = HomeBottomNav(
      current: _tab,
      onSelected: (tab) => setState(() => _tab = tab),
    );

    // Aktifitas, Obrolan, dan Akun tidak memakai header merah: halaman penuh.
    if (_tab == HomeTab.akun) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.light,
          body: AccountView(
            user: user,
            onLogout: _logout,
            onOpenOrders: () => _goTo(HomeTab.aktifitas),
            onOpenChats: () => _goTo(HomeTab.obrolan),
            onOpenWallet: _openWallet,
            onChangePassword: _openChangePassword,
          ),
          bottomNavigationBar: nav,
        ),
      );
    }
    if (_tab == HomeTab.aktifitas) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.light,
          body: ActivityView(onExplore: () => _goTo(HomeTab.beranda)),
          bottomNavigationBar: nav,
        ),
      );
    }
    if (_tab == HomeTab.obrolan) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: OrderStyle.background,
          body: ChatListView(onExplore: () => _goTo(HomeTab.beranda)),
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
                user: user,
                location: _address ?? 'Atur alamat',
                hasUnreadNotification: _unreadCount > 0,
                onNotificationTap: _openNotifications,
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
                  child: _buildBeranda(),
                ),
              ),
            ),
            // Banner pesanan aktif melayang di atas bilah navigasi.
            ListenableBuilder(
              listenable: _orderStore,
              builder: (context, _) {
                // Satu banner saja: pesanan berjalan terbaru.
                final active = _orderStore.active;
                if (active.isEmpty) return const SizedBox.shrink();
                final order = active.first;
                return Positioned(
                  left: 24,
                  right: 24,
                  bottom: 10,
                  child: ActiveOrderTile(
                    title: order.title,
                    status: order.status.label,
                    categoryCode: order.categoryCode,
                    elevated: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OrderDetailPage(orderId: order.id),
                      ),
                    ),
                  ),
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.searchSideInset,
            ),
            child: _SearchBar(onSubmitted: _search),
          ),
          const SizedBox(height: HomeMetrics.gridTopGap),
          Padding(
            padding: const EdgeInsets.only(left: HomeMetrics.bodyPadding),
            child: _CategorySection(
              categories: _categories,
              onRetry: () => setState(() {
                _categories = _catalogRepo.categories();
              }),
              // Pesanan dimulai dari kategori (tidak ada tombol di nav).
              onCategoryTap: _openCategory,
              onHelperTap: () => _soon('Cari helper'),
            ),
          ),
          const SizedBox(height: HomeMetrics.sectionTopGap),
          const _SectionTitle('Jasa tersedia'),
          const SizedBox(height: HomeMetrics.titleToContent),
          ServiceOfferSection(onTap: _openOffer),
          const SizedBox(height: HomeMetrics.sectionTopGap),
          const _SectionTitle('Penawaran Spesial'),
          const SizedBox(height: HomeMetrics.titleToContent),
          PromoCarousel(onTap: (_) => _soon('Voucher')),
          const SizedBox(height: HomeMetrics.sectionTopGap),
          const _SectionTitle('Seputar TolongDong'),
          const SizedBox(height: HomeMetrics.titleToContent),
          // Isi seksi ini terpotong di desain dan backend belum punya
          // endpoint artikel: tips statis tentang alur di aplikasi.
          const TipsSection(),
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
  const _SearchBar({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

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
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
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
