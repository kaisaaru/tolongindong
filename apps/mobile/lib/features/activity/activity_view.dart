import 'package:flutter/material.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../delivery/delivery_models.dart';
import '../delivery/delivery_review_page.dart';
import '../home/home_assets.dart';
import '../household/active_order_page.dart';
import '../household/household_models.dart';
import '../order/order_store.dart';
import '../order/personal_order_page.dart';

/// Isi tab "Aktifitas": pesanan yang sedang berjalan dan riwayatnya.
///
/// Sumbernya [OrderStore] (simulasi). Nanti dari `GET /orders`, dipisah
/// berdasarkan status aktif vs selesai/dibatalkan.
class ActivityView extends StatefulWidget {
  const ActivityView({
    super.key,
    this.store,
    this.bottomPadding = 12,
    this.startOnHistory = false,
    this.showTitle = true,
  });

  final OrderStore? store;
  final double bottomPadding;

  /// True: tab Riwayat terbuka lebih dulu (tombol riwayat Delivery).
  final bool startOnHistory;

  /// False kalau halaman pembungkusnya sudah punya judul.
  final bool showTitle;

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  late final _store = widget.store ?? OrderStore.instance;
  late bool _history = widget.startOnHistory;

  void _openActive() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ActiveOrderPage(store: _store)),
  );

  void _openPersonal() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PersonalOrderPage(store: _store)),
  );

  void _openDelivery(DeliveryOrder order) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DeliveryReviewPage.placed(order: order),
    ),
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
                      child: ListenableBuilder(
                        listenable: _store,
                        builder: (context, _) =>
                            _history ? _buildHistory() : _buildActive(),
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

  Widget _buildActive() {
    if (!_store.hasActive) return const _Empty('Belum ada pesanan berjalan.');

    return ListView(
      padding: _listPadding,
      children: [
        if (_store.active != null)
          _ActiveRow(
            title: 'Household',
            status: activeStatusLabel(_store),
            onTap: _openActive,
          ),
        if (_store.personal case final order?)
          _ActiveRow(
            title: 'Personal',
            status: personalStatusLabel(order),
            categoryCode: 'personal',
            onTap: _openPersonal,
          ),
        for (final order in _store.deliveries)
          _ActiveRow(
            title: 'Delivery',
            status: deliveryStatusLabel(order),
            categoryCode: 'delivery',
            onTap: () => _openDelivery(order),
          ),
      ],
    );
  }

  Widget _buildHistory() {
    final records = _store.history;
    if (records.isEmpty) return const _Empty('Belum ada riwayat pesanan.');

    return ListView.builder(
      padding: _listPadding,
      itemCount: records.length,
      itemBuilder: (context, index) => _HistoryRow(record: records[index]),
    );
  }
}

/// Status pesanan Personal: belum ada jam, jadi cukup siapa yang mengerjakan.
String personalStatusLabel(PersonalOrder order) =>
    'Dikerjakan ${order.helper.name}';

/// Status pengantaran: "Diantar sebelum jam 11.00" atau jadwalnya.
String deliveryStatusLabel(DeliveryOrder order) =>
    scheduleLabels(order.draft.schedule, order.placedAt).subtitle;

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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.disabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final OrderRecord record;

  @override
  Widget build(BuildContext context) {
    final cancelled = record.outcome == HistoryOutcome.cancelled;

    return Padding(
      // Kanan 24: harga 29 dp dari tepi kanan kartu, sesuai desain.
      padding: const EdgeInsets.fromLTRB(10, 10, 24, 10),
      // Teks rata atas dengan ilustrasi, tidak di tengah: di desain blok
      // judul+tanggal sedikit di atas pusat ilustrasi.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(child: _CategoryIcon(record.categoryCode, size: 40)),
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
                        record.title,
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
                          ? 'Dibatalkan'
                          : rupiah(record.total, spaced: false),
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
                  dateLabel(record.date),
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
            // Garis bawah selebar 123 dp, berpusat di separuh kartu.
            padding: const EdgeInsets.fromLTRB(29, 28, 29, 0),
            child: Column(
              children: [
                Text(
                  label,
                  style: AppTypography.style(
                    size: 16,
                    weight: AppTypography.regular,
                    color: active ? AppColors.primary : AppColors.textSecondary,
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

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: AppTypography.style(
          size: AppTypography.small,
          weight: AppTypography.regular,
          color: AppColors.textDescription,
        ),
      ),
    );
  }
}
