import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../household/household_models.dart';
import '../order/order_repository.dart';
import 'helper_store.dart';
import 'widgets/helper_widgets.dart';

/// Ringkasan pendapatan: total bersih yang sudah cair, pendapatan yang
/// menunggu konfirmasi Client, dan riwayat per pesanan. Dihitung dari
/// pekerjaan helper (`helper_payout` tiap pesanan).
class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<HelperStore>().refresh(quiet: true),
    );
  }

  void _open(BuildContext context, ServerOrder job) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransactionDetailPage(orderId: job.id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HelperStore>();
    final paid = store.paidOut;
    final pending = store.pendingPayout;
    final muted = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      color: HelperStyle.muted,
      height: 1.5,
    );

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          const HelperHeader(
            title: 'Ringkasan pendapatan',
            subtitle: 'Pendapatan bersih dari pekerjaanmu',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: store.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  HelperCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Figure(
                                label: 'Total bersih sudah cair',
                                value: rupiah(
                                  store.paidOutTotal,
                                  spaced: false,
                                ),
                              ),
                            ),
                            _Figure(
                              label: 'Pesanan cair',
                              value: '${paid.length}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Komisi platform 10% sudah dipotong. Tidak termasuk '
                          'pendapatan yang masih menunggu konfirmasi.',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  for (final job in pending) ...[
                    const SizedBox(height: 12),
                    _PendingCard(job: job, onTap: () => _open(context, job)),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Riwayat pendapatan cair',
                    style: AppTypography.style(
                      size: 14,
                      weight: AppTypography.semiBold,
                      color: HelperStyle.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (paid.isEmpty)
                    const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Belum ada pendapatan cair',
                      message:
                          'Pendapatan cair setelah Client mengonfirmasi '
                          'pekerjaan selesai.',
                    )
                  else
                    HelperCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < paid.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                color: HelperStyle.cardBorder,
                              ),
                            _PaidRow(
                              job: paid[i],
                              onTap: () => _open(context, paid[i]),
                            ),
                          ],
                          const Divider(
                            height: 1,
                            color: HelperStyle.cardBorder,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                            child: HelperRow(
                              'Total ${paid.length} pesanan',
                              rupiah(store.paidOutTotal, spaced: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'TD-Wallet adalah simulasi, tanpa penarikan ke bank.',
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.style(
            size: 10,
            weight: AppTypography.regular,
            color: HelperStyle.muted,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTypography.style(
              size: 24,
              weight: AppTypography.bold,
              color: HelperStyle.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.job, required this.onTap});

  final ServerOrder job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fee = job.commission;
    return Material(
      color: HelperStyle.softRed,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Menunggu konfirmasi Client',
                      style: AppTypography.style(
                        size: 11,
                        weight: AppTypography.medium,
                        color: HelperStyle.red,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: HelperStyle.red,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                rupiah(job.netPayout, spaced: false),
                style: AppTypography.style(
                  size: 22,
                  weight: AppTypography.bold,
                  color: HelperStyle.red,
                ),
              ),
              Text(
                '${job.client?.name ?? 'Client'} · '
                '${HelperStyle.categoryName(job.categoryCode)} · '
                '#${job.number}',
                style: AppTypography.style(
                  size: 10,
                  weight: AppTypography.regular,
                  color: HelperStyle.muted,
                  height: 1.5,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${rupiah(job.price, spaced: false)} − '
                      '${rupiah(fee, spaced: false)}',
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        color: HelperStyle.muted,
                      ),
                    ),
                  ),
                  Text(
                    'Lihat detail ›',
                    style: AppTypography.style(
                      size: 11,
                      weight: AppTypography.semiBold,
                      color: HelperStyle.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaidRow extends StatelessWidget {
  const _PaidRow({required this.job, required this.onTap});

  final ServerOrder job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final at = job.enteredAt(OrderStatus.completed) ?? job.createdAt;
    final small = AppTypography.style(
      size: 9,
      weight: AppTypography.regular,
      color: HelperStyle.muted,
      height: 1.5,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${HelperStyle.categoryName(job.categoryCode)} · '
                    '${dateLabel(at)}',
                    style: AppTypography.style(
                      size: 12,
                      weight: AppTypography.semiBold,
                      color: HelperStyle.ink,
                      height: 1.4,
                    ),
                  ),
                  Text('#${job.number} · Sudah cair', style: small),
                  Text(
                    '${rupiah(job.price, spaced: false)} − '
                    '${rupiah(job.commission, spaced: false)}',
                    style: small,
                  ),
                ],
              ),
            ),
            Text(
              rupiah(job.netPayout, spaced: false),
              style: AppTypography.style(
                size: 13,
                weight: AppTypography.semiBold,
                color: HelperStyle.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rincian satu transaksi pesanan: status pencairan, harga, komisi, dan
/// pendapatan bersih.
class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({super.key, required this.orderId});

  final int orderId;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  @override
  void initState() {
    super.initState();
    // Pesanan selesai di daftar belum memuat pemesan dan riwayat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<HelperStore>()
          .load(widget.orderId)
          .then<void>((_) {}, onError: (Object _) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HelperStore>();
    final job = store.byId(widget.orderId);
    final client = job?.client?.name ?? 'Client';
    final finishedAt = job == null
        ? null
        : job.helperFinishedAt ??
              job.enteredAt(OrderStatus.awaitingConfirmation);
    final autoAt = job == null ? null : autoConfirmAt(job);

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          const HelperHeader(
            title: 'Detail transaksi',
            subtitle: 'TD-Wallet · simulasi transaksi',
          ),
          Expanded(
            child: job == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      if (job.status == OrderStatus.completed)
                        HelperBanner(
                          tone: BannerTone.green,
                          title: 'Pendapatan sudah cair',
                          message:
                              '$client mengonfirmasi pekerjaan. Pendapatan '
                              'bersih masuk ke TD-Wallet.',
                        )
                      else if (job.status == OrderStatus.awaitingConfirmation)
                        HelperBanner(
                          title: 'Menunggu konfirmasi Client',
                          message: switch (finishedAt) {
                            final at? =>
                              'Ditandai selesai ${dateLabel(at)}, '
                                  '${clockLabel(at)}. Pendapatan dari $client '
                                  'belum cair.',
                            null => 'Pendapatan dari $client belum cair.',
                          },
                        )
                      else
                        HelperBanner(
                          tone: BannerTone.gray,
                          title: job.status.label,
                        ),
                      const SizedBox(height: 12),
                      HelperCard(
                        child: Column(
                          children: [
                            JobSummary(order: job, details: false),
                            const Divider(
                              height: 22,
                              color: HelperStyle.cardBorder,
                            ),
                            HelperRow(
                              'Kategori',
                              HelperStyle.categoryName(job.categoryCode),
                            ),
                            HelperRow(
                              'Permintaan',
                              '${dateLabel(job.createdAt)}, '
                                  '${clockLabel(job.createdAt)}',
                            ),
                            if (finishedAt != null)
                              HelperRow(
                                'Ditandai selesai',
                                '${dateLabel(finishedAt)}, '
                                    '${clockLabel(finishedAt)}',
                              ),
                            const Divider(
                              height: 22,
                              color: HelperStyle.cardBorder,
                            ),
                            EarningBreakdown(
                              price: job.price,
                              commission: job.commission,
                              netLabel: job.status == OrderStatus.completed
                                  ? 'Bersih · sudah cair'
                                  : 'Estimasi bersih · menunggu',
                            ),
                          ],
                        ),
                      ),
                      if (job.status == OrderStatus.awaitingConfirmation) ...[
                        const SizedBox(height: 12),
                        HelperBanner(
                          title:
                              'Escrow simulasi '
                              '${rupiah(job.price, spaced: false)} masih ditahan',
                          message: autoAt == null
                              ? '${rupiah(job.netPayout, spaced: false)} baru '
                                    'cair setelah konfirmasi $client. Tidak '
                                    'ada pembayaran nyata atau penarikan bank.'
                              : '${rupiah(job.netPayout, spaced: false)} baru '
                                    'cair setelah konfirmasi $client, atau '
                                    'otomatis ${dateLabel(autoAt)}, '
                                    '${clockLabel(autoAt)}. Tidak ada '
                                    'pembayaran nyata atau penarikan bank.',
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
