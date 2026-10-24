import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_typography.dart';
import '../household/household_models.dart';
import '../order/order_repository.dart';
import 'finish_confirm_page.dart';
import 'helper_store.dart';
import 'proof_page.dart';
import 'widgets/helper_widgets.dart';

/// Progres pekerjaan: tahap pesanan dari riwayat status, lalu catatan
/// aktivitas. Isinya dari detail pekerjaan yang sudah dimuat.
///
/// Delivery lanjut ke unggah bukti; Household dan Personal ke konfirmasi
/// penyelesaian.
class JobProgressPage extends StatelessWidget {
  const JobProgressPage({super.key, required this.orderId});

  final int orderId;

  /// Tahap yang ditampilkan, dengan keterangan untuk helper. Delivery
  /// tidak punya tahap "Tiba di lokasi" sendiri.
  static List<(OrderStatus, String, String)> _steps({
    required bool delivery,
  }) => [
    (OrderStatus.accepted, 'Diterima', 'Penawaran disetujui'),
    (OrderStatus.onTheWay, 'Dalam perjalanan', 'Menuju lokasi'),
    if (!delivery) (OrderStatus.arrived, 'Tiba di lokasi', 'Sampai di lokasi'),
    (OrderStatus.inProgress, 'Sedang dikerjakan', 'Mulai mengerjakan'),
    (
      OrderStatus.awaitingConfirmation,
      'Selesai',
      delivery ? 'Menunggu bukti dan konfirmasi' : 'Menunggu konfirmasi',
    ),
  ];

  /// Keterangan satu baris riwayat status.
  static String activity(OrderStatus status) => switch (status) {
    OrderStatus.awaitingQuote => 'Permintaan masuk dari Client.',
    OrderStatus.accepted => 'Penawaran disetujui, dana Client ditahan.',
    OrderStatus.onTheWay => 'Berangkat menuju lokasi.',
    OrderStatus.arrived => 'Tiba di lokasi.',
    OrderStatus.inProgress => 'Mulai mengerjakan pesanan.',
    OrderStatus.awaitingConfirmation => 'Ditandai selesai, menunggu Client.',
    OrderStatus.completed => 'Client mengonfirmasi, pendapatan cair.',
    _ => status.label,
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HelperStore>();
    final job = store.byId(orderId);
    final delivery = job?.categoryCode == 'delivery';
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
            title: 'Progres pekerjaan',
            subtitle: 'Pantau setiap tahap pesanan',
          ),
          Expanded(
            child: job == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      HelperCard(child: JobSummary(order: job, details: false)),
                      const SizedBox(height: 12),
                      HelperCard(
                        child: _Timeline(
                          job: job,
                          steps: _steps(delivery: delivery),
                        ),
                      ),
                      const SizedBox(height: 12),
                      HelperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Catatan aktivitas',
                              style: AppTypography.style(
                                size: 13,
                                weight: AppTypography.semiBold,
                                color: HelperStyle.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final h in job.history)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Text(
                                  '${clockLabel(h.at)} · ${activity(h.status)}',
                                  style: muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (job.status == OrderStatus.inProgress &&
                          !delivery) ...[
                        const SizedBox(height: 12),
                        const HelperBanner(
                          title: 'Sudah selesai mengerjakan?',
                          message:
                              'Lanjutkan ke konfirmasi penyelesaian setelah '
                              'seluruh pekerjaan selesai.',
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: job?.status == OrderStatus.inProgress
          ? HelperBottomBar(
              children: [
                HelperButton(
                  label: delivery
                      ? 'Unggah Bukti Penyelesaian'
                      : 'Selesaikan Pekerjaan',
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => delivery
                          ? ProofPage(job: job!)
                          : FinishConfirmPage(job: job!),
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.job, required this.steps});

  final ServerOrder job;
  final List<(OrderStatus, String, String)> steps;

  @override
  Widget build(BuildContext context) {
    // Tahap terakhir yang sudah dilewati menjadi tahap aktif.
    final reached = [
      for (final (status, _, _) in steps) job.enteredAt(status) != null,
    ];
    final current = reached.lastIndexWhere((r) => r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perjalanan pesanan',
          style: AppTypography.style(
            size: 13,
            weight: AppTypography.semiBold,
            color: HelperStyle.ink,
          ),
        ),
        const SizedBox(height: 12),
        for (final (i, (status, title, caption)) in steps.indexed)
          _TimelineStep(
            title: title,
            caption: switch (job.enteredAt(status)) {
              final at? => '${clockLabel(at)} · $caption',
              null => caption,
            },
            reached: reached[i],
            current: i == current,
            last: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.caption,
    required this.reached,
    required this.current,
    required this.last,
  });

  final String title;
  final String caption;
  final bool reached;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = reached ? HelperStyle.red : const Color(0xFFE5D5D5);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: current ? 14 : 10,
                  height: current ? 14 : 10,
                  margin: EdgeInsets.only(top: current ? 2 : 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.style(
                      size: 12,
                      weight: current
                          ? AppTypography.semiBold
                          : AppTypography.regular,
                      color: current
                          ? HelperStyle.red
                          : reached
                          ? HelperStyle.ink
                          : HelperStyle.muted,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    caption,
                    style: AppTypography.style(
                      size: 9,
                      weight: AppTypography.regular,
                      color: HelperStyle.muted,
                      height: 1.4,
                    ),
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
