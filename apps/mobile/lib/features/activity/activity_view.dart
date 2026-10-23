import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../home/home_assets.dart';
import '../household/household_models.dart' show dateLabel;
import '../order/order_detail_page.dart';
import '../order/order_repository.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';

/// Isi tab "Aktifitas": pesanan yang sedang berjalan dan riwayatnya, dari
/// `GET /orders` lewat [OrderStore].
class ActivityView extends StatefulWidget {
  const ActivityView({
    super.key,
    this.bottomPadding = 12,
    this.startOnHistory = false,
    this.showTitle = true,
    this.onExplore,
  });
  final double bottomPadding;

  /// True: tab Riwayat terbuka lebih dulu (tombol riwayat Delivery).
  final bool startOnHistory;

  /// False kalau halaman pembungkusnya sudah punya judul.
  final bool showTitle;

  /// Ajakan "Cari Layanan" saat belum ada pesanan, misal pindah ke Beranda.
  final VoidCallback? onExplore;

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  late final _store = context.read<OrderStore>();
  late bool _history = widget.startOnHistory;

  @override
  void initState() {
    super.initState();
    // Selalu terbaru saat tab dibuka: helper bisa memajukan status kapan
    // saja dari aplikasinya.
    WidgetsBinding.instance.addPostFrameCallback((_) => _store.refresh());
  }

  void _open(ServerOrder order) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => OrderDetailPage(orderId: order.id)),
  );

  @override
  Widget build(BuildContext context) {
    // Ukuran diukur dari Figma (frame 207): kartu 24 dp dari tepi layar,
    // judul 24, tab 16, baris pesanan setinggi 60 dengan ilustrasi 40.
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          widget.showTitle ? 24 : 8,
          24,
          widget.bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              Text(
                'Aktifitas',
                style: AppTypography.style(
                  size: 24,
                  weight: AppTypography.semiBold,
                ),
              ),
              const SizedBox(height: 22),
            ],
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Tab(
                          label: 'Dalam Proses',
                          active: !_history,
                          onTap: () => setState(() => _history = false),
                        ),
                        _Tab(
                          label: 'Riwayat',
                          active: _history,
                          onTap: () => setState(() => _history = true),
                        ),
                      ],
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _store.refresh,
                        child: ListenableBuilder(
                          listenable: _store,
                          builder: (context, _) =>
                              _history ? _buildHistory() : _buildActive(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Ilustrasi baris pertama 15 dp dari tepi kiri kartu dan pusatnya 111 dp
  // dari tepi atas kartu; sisa jaraknya ada di padding tiap baris.
  static const _listPadding = EdgeInsets.fromLTRB(4, 27, 4, 14);

  /// Kosong, memuat, atau gagal. Tetap bisa ditarik untuk memuat ulang.
  Widget? _state({required bool empty, required Widget whenEmpty}) {
    if (!empty) return null;
    if (_store.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _store.error;
    final child = error == null
        ? whenEmpty
        : EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Pesanan gagal dimuat',
            message: error.message,
            actionLabel: 'Coba lagi',
            onAction: _store.refresh,
          );
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: box.maxHeight, child: child),
      ),
    );
  }

  Widget _buildActive() {
    final orders = _store.active;
    final state = _state(
      empty: orders.isEmpty,
      whenEmpty: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada pesanan berjalan',
        message: 'Pesanan yang sedang dikerjakan helper akan tampil di sini.',
        actionLabel: 'Cari Layanan',
        onAction: widget.onExplore,
      ),
    );
    if (state != null) return state;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _listPadding,
      children: [
        for (final order in orders)
          _ActiveRow(
            title: order.title,
            status: order.status.label,
            categoryCode: order.categoryCode,
            onTap: () => _open(order),
          ),
      ],
    );
  }

  Widget _buildHistory() {
    final orders = _store.history;
    final state = _state(
      empty: orders.isEmpty,
      whenEmpty: const EmptyState(
        icon: Icons.history_rounded,
        title: 'Belum ada riwayat pesanan',
        message: 'Pesanan yang selesai atau dibatalkan tersimpan di sini.',
      ),
    );
    if (state != null) return state;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _listPadding,
      itemCount: orders.length,
      itemBuilder: (context, index) =>
          _HistoryRow(order: orders[index], onTap: () => _open(orders[index])),
    );
  }
}

/// Banner pesanan aktif yang melayang di beranda. Di kartu Aktifitas
/// barisnya [_ActiveRow], yang lebih besar sesuai desain.
class ActiveOrderTile extends StatelessWidget {
  const ActiveOrderTile({
    super.key,
    required this.title,
    required this.status,
    required this.onTap,
    this.categoryCode = 'household',
    this.elevated = false,
  });

  final String title;
  final String status;
  final VoidCallback onTap;

  /// Kode kategori backend, untuk ikonnya.
  final String categoryCode;

  /// True untuk banner beranda: latar putih dengan bayangan.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.light,
      elevation: elevated ? 4 : 0,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _CategoryIcon(categoryCode),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        height: 1.4,
                      ),
                    ),
                    Text(
                      status,
                      style: AppTypography.style(
                        size: 12,
                        weight: AppTypography.semiBold,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris pesanan berjalan di kartu Aktifitas: kategori di atas, status
/// tebal di bawah, chevron di kanan.
class _ActiveRow extends StatelessWidget {
  const _ActiveRow({
    required this.title,
    required this.status,
    required this.onTap,
    this.categoryCode = 'household',
  });

  final String title;
  final String status;
  final VoidCallback onTap;

  /// Kode kategori backend, untuk ikonnya.
  final String categoryCode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        // Kanan 26: chevron 30 dp dari tepi kanan kartu, sesuai desain.
        padding: const EdgeInsets.fromLTRB(10, 10, 26, 10),
        child: Row(
          children: [
            ClipOval(child: _CategoryIcon(categoryCode, size: 40)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.style(
                      size: 12,
                      weight: AppTypography.regular,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: 14,
                      weight: AppTypography.semiBold,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.disabled),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.order, required this.onTap});

  final ServerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status.isCancelled;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        // Kanan 24: harga 29 dp dari tepi kanan kartu, sesuai desain.
        padding: const EdgeInsets.fromLTRB(10, 10, 24, 10),
        // Teks rata atas dengan ilustrasi, tidak di tengah: di desain blok
        // judul+tanggal sedikit di atas pusat ilustrasi.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(child: _CategoryIcon(order.categoryCode, size: 40)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Harga sebaris dengan judul, bukan di tengah baris.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          order.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            size: 14,
                            weight: AppTypography.semiBold,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cancelled
                            ? order.status.label
                            : rupiah(order.price, spaced: false),
                        style: AppTypography.style(
                          size: 12,
                          weight: AppTypography.medium,
                          color: cancelled
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    dateLabel(order.createdAt),
                    style: AppTypography.style(
                      size: 12,
                      weight: AppTypography.regular,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ilustrasi kategori; kotak abu-abu kalau ilustrasinya belum ada.
class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon(this.code, {this.size = 30});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = HomeAssets.categoryIcon(code);
    if (asset == null) {
      return ColoredBox(
        color: AppColors.disabled,
        child: SizedBox.square(dimension: size),
      );
    }
    return Image.asset(asset, width: size, height: size);
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // Garis bawah selebar 123 dp, berpusat di separuh kartu. Di layar
            // sempit jarak tepinya ikut menyempit dan label tetap sebaris.
            padding: EdgeInsets.fromLTRB(
              OrderStyle.inset(context, 29),
              28,
              OrderStyle.inset(context, 29),
              0,
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.style(
                      size: 16,
                      weight: AppTypography.regular,
                      color: active
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 1.5,
                  color: active ? AppColors.primary : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
