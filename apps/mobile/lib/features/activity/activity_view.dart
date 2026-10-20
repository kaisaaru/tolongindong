import 'package:flutter/material.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../home/home_assets.dart';
import '../household/active_order_page.dart';
import '../household/household_models.dart';
import '../order/order_store.dart';

/// Isi tab "Aktifitas": pesanan yang sedang berjalan dan riwayatnya.
///
/// Sumbernya [OrderStore] (simulasi). Nanti dari `GET /orders`, dipisah
/// berdasarkan status aktif vs selesai/dibatalkan.
class ActivityView extends StatefulWidget {
  const ActivityView({super.key, this.store, this.bottomPadding = 16});

  final OrderStore? store;
  final double bottomPadding;

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  late final _store = widget.store ?? OrderStore.instance;
  bool _history = false;

  void _openActive() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ActiveOrderPage(store: _store)),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 24, 22, widget.bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktifitas',
              style: AppTypography.style(
                size: 22,
                weight: AppTypography.semiBold,
              ),
            ),
            const SizedBox(height: 18),
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

  Widget _buildActive() {
    final order = _store.active;
    if (order == null) return const _Empty('Belum ada pesanan berjalan.');

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ActiveOrderTile(
          title: 'Household',
          status: activeStatusLabel(_store),
          onTap: _openActive,
        ),
      ],
    );
  }

  Widget _buildHistory() {
    final records = _store.history;
    if (records.isEmpty) return const _Empty('Belum ada riwayat pesanan.');

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: records.length,
      itemBuilder: (context, index) => _HistoryRow(record: records[index]),
    );
  }
}

/// Baris pesanan aktif. Dipakai juga sebagai banner melayang di beranda.
class ActiveOrderTile extends StatelessWidget {
  const ActiveOrderTile({
    super.key,
    required this.title,
    required this.status,
    required this.onTap,
    this.elevated = false,
  });

  final String title;
  final String status;
  final VoidCallback onTap;

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
                child: Image.asset(
                  HomeAssets.categoryIcon('household')!,
                  width: 30,
                  height: 30,
                ),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final OrderRecord record;

  @override
  Widget build(BuildContext context) {
    final cancelled = record.outcome == HistoryOutcome.cancelled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              HomeAssets.categoryIcon('household')!,
              width: 30,
              height: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: AppTypography.style(
                    size: 12,
                    weight: AppTypography.semiBold,
                    height: 1.4,
                  ),
                ),
                Text(
                  dateLabel(record.date),
                  style: AppTypography.style(
                    size: 9,
                    weight: AppTypography.regular,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            cancelled ? 'Dibatalkan' : rupiah(record.total, spaced: false),
            style: AppTypography.style(
              size: 11,
              weight: AppTypography.medium,
              color: cancelled ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
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
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                Text(
                  label,
                  style: AppTypography.style(
                    size: 13,
                    weight: AppTypography.regular,
                    color: active ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
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
