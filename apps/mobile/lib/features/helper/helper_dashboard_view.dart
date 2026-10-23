import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../auth/session_store.dart';
import '../notification/notification_page.dart';
import '../order/order_repository.dart';
import '../order/widgets/order_widgets.dart';
import 'earnings_page.dart';
import 'helper_job_page.dart';
import 'helper_store.dart';
import 'widgets/helper_widgets.dart';

/// Beranda mode Helper: status kerja, pendapatan, permintaan baru, pesanan
/// berjalan, dan layanan helper.
class HelperDashboardView extends StatelessWidget {
  const HelperDashboardView({super.key, required this.onOpenJobs});

  /// Pindah ke tab Pesanan, misal untuk meninjau permintaan baru.
  final VoidCallback onOpenJobs;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HelperStore>();
    final user = context.watch<SessionStore>().user;
    final firstName = (user?.fullName ?? '').trim().split(' ').first;
    final active = store.active;
    final requests = store.toReview.length;

    return Column(
      children: [
        HelperHeader(
          title: firstName.isEmpty ? 'Halo!' : 'Halo, $firstName!',
          subtitle: 'Siap membantu hari ini?',
          back: false,
          leading: HelperAvatar(
            name: user?.fullName ?? '',
            photoUrl: user?.photoUrl,
            size: 40,
          ),
          trailing: _BellButton(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NotificationPage()),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: store.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _AvailabilityCard(store: store),
                const SizedBox(height: 12),
                _EarningsCard(store: store),
                if (requests > 0) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: HelperStyle.softRed,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onOpenJobs,
                      child: HelperBanner(
                        title: '$requests permintaan baru menunggu responsmu',
                        message:
                            'Tinjau dalam 5 menit, lalu buat penawaran '
                            'atau tolak.',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: HelperStyle.red,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _SectionTitle(
                  'Pesanan berjalan',
                  tag: active.isEmpty ? null : '${active.length} aktif',
                ),
                const SizedBox(height: 10),
                if (active.isEmpty)
                  HelperCard(
                    child: Text(
                      store.loading
                          ? 'Memuat pesanan...'
                          : 'Belum ada pesanan berjalan. Permintaan baru muncul '
                                'di tab Pesanan.',
                      style: AppTypography.style(
                        size: 11,
                        weight: AppTypography.regular,
                        color: HelperStyle.muted,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  for (final job in active) ...[
                    ActiveJobCard(job: job),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 10),
                const _SectionTitle('Layanan kamu'),
                const SizedBox(height: 10),
                _ServicesCard(store: store),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.light.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
      child: IconButton(
        tooltip: 'Notifikasi',
        onPressed: onTap,
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: AppColors.light,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.tag});

  final String text;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final tag = this.tag;
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: AppTypography.style(
              size: 15,
              weight: AppTypography.semiBold,
              color: HelperStyle.ink,
            ),
          ),
        ),
        if (tag != null) CategoryTag(tag),
      ],
    );
  }
}

class _AvailabilityCard extends StatefulWidget {
  const _AvailabilityCard({required this.store});

  final HelperStore store;

  @override
  State<_AvailabilityCard> createState() => _AvailabilityCardState();
}

class _AvailabilityCardState extends State<_AvailabilityCard> {
  bool _saving = false;

  Future<void> _toggle(bool value) async {
    setState(() => _saving = true);
    try {
      await widget.store.setAvailable(value);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.store.status.available;
    return HelperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status kerja',
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        color: HelperStyle.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: available
                                ? HelperStyle.green
                                : HelperStyle.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            available
                                ? 'Sedang tersedia'
                                : 'Sedang tidak tersedia',
                            style: AppTypography.style(
                              size: 14,
                              weight: AppTypography.semiBold,
                              color: HelperStyle.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: available,
                onChanged: _saving || !widget.store.statusLoaded
                    ? null
                    : _toggle,
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          const Divider(height: 22, color: HelperStyle.cardBorder),
          Text(
            'Saat tidak tersedia, kamu tidak muncul di pencarian dan tidak '
            'menerima permintaan baru. Permintaan yang sudah masuk tetap '
            'dapat dijawab.',
            style: AppTypography.style(
              size: 10,
              weight: AppTypography.regular,
              color: HelperStyle.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.store});

  final HelperStore store;

  @override
  Widget build(BuildContext context) {
    final label = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      color: HelperStyle.muted,
    );
    final figure = AppTypography.style(
      size: 24,
      weight: AppTypography.bold,
      color: HelperStyle.ink,
    );

    return HelperCard(
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pendapatan', style: label),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          rupiah(store.paidOutTotal, spaced: false),
                          style: figure,
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 28, color: HelperStyle.cardBorder),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pesanan selesai', style: label),
                    Text('${store.status.completedCount}', style: figure),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: HelperStyle.softRed,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const EarningsPage()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const OrderIcon(HelperStyle.iconWallet, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lihat pendapatan',
                        style: AppTypography.style(
                          size: 12,
                          weight: AppTypography.medium,
                          color: HelperStyle.red,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: HelperStyle.red,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu pesanan berjalan: nomor, kategori, Client, tugas, status, dan
/// "Lihat pekerjaan".
class ActiveJobCard extends StatelessWidget {
  const ActiveJobCard({super.key, required this.job});

  final ServerOrder job;

  static String statusText(OrderStatus status) => switch (status) {
    OrderStatus.accepted => 'Siap berangkat',
    OrderStatus.onTheWay => 'Menuju lokasi',
    OrderStatus.arrived => 'Sudah sampai',
    OrderStatus.inProgress ||
    OrderStatus.priceAdjustment => 'Sedang dikerjakan',
    OrderStatus.awaitingConfirmation => 'Menunggu konfirmasi Client',
    _ => status.label,
  };

  @override
  Widget build(BuildContext context) {
    final parsed = job.parsed;
    final task = parsed.rows.isEmpty
        ? (parsed.freeText ?? job.title)
        : parsed.rows.first.value;

    return HelperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${job.number}',
                  style: AppTypography.style(
                    size: 10,
                    weight: AppTypography.regular,
                    color: HelperStyle.muted,
                  ),
                ),
              ),
              CategoryTag(HelperStyle.categoryName(job.categoryCode)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job.client?.name ?? job.title,
            style: AppTypography.style(
              size: 13,
              weight: AppTypography.semiBold,
              color: HelperStyle.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            task,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              size: 11,
              weight: AppTypography.regular,
              color: HelperStyle.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.autorenew_rounded,
                size: 14,
                color: HelperStyle.red,
              ),
              const SizedBox(width: 6),
              Text(
                statusText(job.status),
                style: AppTypography.style(
                  size: 10,
                  weight: AppTypography.medium,
                  color: HelperStyle.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HelperButton(
            label: 'Lihat pekerjaan',
            soft: true,
            icon: Icons.arrow_forward_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HelperJobPage(orderId: job.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.store});

  final HelperStore store;

  @override
  Widget build(BuildContext context) {
    final status = store.status;
    return HelperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const OrderIcon(
                HelperStyle.iconVerified,
                size: 15,
                color: HelperStyle.green,
              ),
              const SizedBox(width: 8),
              Text(
                status.isVerifiedHelper
                    ? 'Identitas terverifikasi'
                    : 'Menunggu verifikasi',
                style: AppTypography.style(
                  size: 11,
                  weight: AppTypography.medium,
                  color: HelperStyle.ink,
                ),
              ),
            ],
          ),
          if (status.categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in status.categories) CategoryTag(c.name),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
