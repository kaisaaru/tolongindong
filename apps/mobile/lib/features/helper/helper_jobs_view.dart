import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/countdown_text.dart';
import '../../widgets/empty_state.dart';
import '../household/household_models.dart';
import '../order/order_repository.dart';
import 'helper_dashboard_view.dart';
import 'helper_job_page.dart';
import 'helper_shell.dart';
import 'helper_store.dart';
import 'widgets/helper_widgets.dart';

enum _JobsTab { review, active, done }

/// Tab Pesanan mode Helper: permintaan yang perlu ditinjau (termasuk
/// penawaran yang menunggu Client), pekerjaan berjalan, dan riwayat.
class HelperJobsView extends StatefulWidget {
  const HelperJobsView({super.key});

  @override
  State<HelperJobsView> createState() => _HelperJobsViewState();
}

class _HelperJobsViewState extends State<HelperJobsView> {
  _JobsTab _tab = _JobsTab.review;

  void _open(ServerOrder job) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => HelperJobPage(orderId: job.id)),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HelperStore>();

    return Column(
      children: [
        const HelperHeader(
          title: 'Pesanan',
          subtitle: 'Kelola permintaan dan pekerjaanmu',
          back: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _Segmented(
            current: _tab,
            onSelected: (tab) => setState(() => _tab = tab),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: store.refresh,
            child: _content(store),
          ),
        ),
      ],
    );
  }

  Widget _content(HelperStore store) {
    if (store.jobs.isEmpty && store.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = store.error;
    if (store.jobs.isEmpty && error != null) {
      return _scrollable(
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Pesanan gagal dimuat',
          message: helperErrorText(error),
          actionLabel: 'Coba lagi',
          onAction: store.refresh,
        ),
      );
    }

    return switch (_tab) {
      _JobsTab.review => _review(store),
      _JobsTab.active => _list(
        store.active,
        empty: const EmptyState(
          icon: Icons.directions_run_rounded,
          title: 'Belum ada pekerjaan berjalan',
          message: 'Pekerjaan aktif setelah Client menyetujui penawaranmu.',
        ),
        item: (job) => ActiveJobCard(job: job),
      ),
      _JobsTab.done => _list(
        store.done,
        empty: const EmptyState(
          icon: Icons.history_rounded,
          title: 'Belum ada riwayat',
          message: 'Pekerjaan yang selesai atau dibatalkan tersimpan di sini.',
        ),
        item: (job) => _DoneRow(job: job, onTap: () => _open(job)),
      ),
    };
  }

  Widget _scrollable(Widget child) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(height: box.maxHeight, child: child),
    ),
  );

  Widget _list(
    List<ServerOrder> jobs, {
    required Widget empty,
    required Widget Function(ServerOrder) item,
  }) {
    if (jobs.isEmpty) return _scrollable(empty);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => item(jobs[i]),
    );
  }

  Widget _review(HelperStore store) {
    final requests = store.toReview;
    final waiting = store.waitingDecision;
    final running = store.active.length;
    final muted = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      color: HelperStyle.muted,
      height: 1.5,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Permintaan masuk',
                style: AppTypography.style(
                  size: 15,
                  weight: AppTypography.semiBold,
                  color: HelperStyle.ink,
                ),
              ),
            ),
            if (requests.isNotEmpty)
              Text(
                '${requests.length} perlu ditinjau',
                style: AppTypography.style(
                  size: 10,
                  weight: AppTypography.medium,
                  color: HelperStyle.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (requests.isEmpty && waiting.isEmpty)
          HelperCard(
            child: Text(
              'Belum ada permintaan baru. Pastikan status kerjamu tersedia '
              'supaya Client bisa memilihmu.',
              style: muted,
            ),
          ),
        for (final job in requests) ...[
          _RequestCard(
            job: job,
            clock: () => store.now,
            onTap: () => _open(job),
          ),
          const SizedBox(height: 12),
        ],
        for (final job in waiting) ...[
          _WaitingCard(
            job: job,
            offer: store.myOffer(job)!,
            clock: () => store.now,
            onTap: () => _open(job),
          ),
          const SizedBox(height: 12),
        ],
        const HelperBanner(
          title: 'Belum menjadi pesanan aktif',
          message:
              'Harga dari Client hanya estimasi. Pekerjaan aktif setelah '
              'Client menyetujui penawaranmu.',
        ),
        if (running > 0) ...[
          const SizedBox(height: 16),
          Text(
            '$running pesanan berjalan ada di tab Berjalan.',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ],
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.current, required this.onSelected});

  final _JobsTab current;
  final ValueChanged<_JobsTab> onSelected;

  static const _labels = {
    _JobsTab.review: 'Perlu ditinjau',
    _JobsTab.active: 'Berjalan',
    _JobsTab.done: 'Selesai',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HelperStyle.cardBorder),
      ),
      child: Row(
        children: [
          for (final tab in _JobsTab.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab == current,
                child: GestureDetector(
                  onTap: () => onSelected(tab),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: tab == current
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _labels[tab]!,
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        size: 11,
                        weight: AppTypography.medium,
                        color: tab == current
                            ? AppColors.light
                            : HelperStyle.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Permintaan baru: batas respons, ringkasan, estimasi Client.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.job,
    required this.clock,
    required this.onTap,
  });

  final ServerOrder job;
  final DateTime Function() clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final respondBy = job.respondBy;
    return HelperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (respondBy != null) ...[
            HelperBanner(
              title: 'Batas respons 5 menit',
              trailing: CountdownText(until: respondBy, clock: clock),
            ),
            const SizedBox(height: 12),
          ],
          JobSummary(order: job, details: false),
          const SizedBox(height: 6),
          Text(
            'Memilih kamu secara langsung · Belum ditanggapi',
            style: AppTypography.style(
              size: 9,
              weight: AppTypography.regular,
              color: HelperStyle.muted,
            ),
          ),
          const SizedBox(height: 6),
          HelperRow(
            'Estimasi harga dari Client',
            job.estimatedPrice > 0
                ? rupiah(job.estimatedPrice, spaced: false)
                : '-',
          ),
          const SizedBox(height: 10),
          HelperButton(label: 'Lihat detail', onPressed: onTap),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Tinjau permintaan, lalu buat penawaran atau tolak.',
              style: AppTypography.style(
                size: 9,
                weight: AppTypography.regular,
                color: HelperStyle.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Penawaran terkirim, menunggu Client.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.job,
    required this.offer,
    required this.clock,
    required this.onTap,
  });

  final ServerOrder job;
  final OrderOffer offer;
  final DateTime Function() clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final validUntil = offer.validUntil;
    final expired = validUntil != null && !validUntil.isAfter(clock());
    return HelperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelperBanner(
            title: expired
                ? 'Batas persetujuan lewat · kirim ulang'
                : 'Menunggu keputusan Client',
            trailing: validUntil == null || expired
                ? null
                : CountdownText(until: validUntil, clock: clock),
          ),
          const SizedBox(height: 12),
          JobSummary(order: job, details: false),
          const SizedBox(height: 6),
          HelperRow('Penawaranmu', rupiah(offer.price, spaced: false)),
          const SizedBox(height: 10),
          HelperButton(label: 'Lihat detail', soft: true, onPressed: onTap),
        ],
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.job, required this.onTap});

  final ServerOrder job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = job.status == OrderStatus.completed;
    return Material(
      color: AppColors.light,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HelperStyle.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        size: 12,
                        weight: AppTypography.semiBold,
                        color: HelperStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${job.number} · ${dateLabel(job.createdAt)}',
                      style: AppTypography.style(
                        size: 9,
                        weight: AppTypography.regular,
                        color: HelperStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CategoryTag(
                    completed ? 'Selesai' : job.status.label,
                    tone: completed ? BannerTone.green : BannerTone.gray,
                  ),
                  if (completed) ...[
                    const SizedBox(height: 4),
                    Text(
                      rupiah(job.netPayout, spaced: false),
                      style: AppTypography.style(
                        size: 12,
                        weight: AppTypography.semiBold,
                        color: HelperStyle.green,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
