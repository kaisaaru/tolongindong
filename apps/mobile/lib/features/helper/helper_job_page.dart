import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/countdown_text.dart';
import '../../widgets/empty_state.dart';
import '../chat/chat_models.dart';
import '../chat/chat_room_page.dart';
import '../chat/chat_store.dart';
import '../household/household_models.dart';
import '../order/order_repository.dart';
import '../order/widgets/order_widgets.dart';
import 'earnings_page.dart';
import 'helper_store.dart';
import 'job_progress_page.dart';
import 'make_offer_page.dart';
import 'proof_page.dart';
import 'widgets/helper_widgets.dart';

/// Satu pekerjaan helper. Isinya mengikuti status:
///
/// - menunggu helper: Detail permintaan (Tolak / Buat Penawaran)
/// - penawaran terkirim: Menunggu keputusan Client
/// - diterima: Pesanan diterima (Mulai Perjalanan)
/// - menuju lokasi / sampai: Menuju lokasi (Mulai Pengerjaan)
/// - dikerjakan: Pengerjaan aktif (Unggah Bukti)
/// - menunggu konfirmasi / selesai: Pekerjaan selesai
///
/// Diperiksa ulang tiap [pollEvery] supaya keputusan Client ikut terlihat.
class HelperJobPage extends StatefulWidget {
  const HelperJobPage({super.key, required this.orderId});

  final int orderId;

  static const pollEvery = Duration(seconds: 8);

  @override
  State<HelperJobPage> createState() => _HelperJobPageState();
}

class _HelperJobPageState extends State<HelperJobPage> {
  late final _store = context.read<HelperStore>();
  Timer? _poll;
  bool _loading = true;
  ApiException? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(HelperJobPage.pollEvery, (_) {
      final job = _store.byId(widget.orderId);
      if (job == null || !job.status.isTerminal) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!mounted) return;
    try {
      await _store.load(widget.orderId);
      if (mounted && !quiet) setState(() => _error = null);
    } on ApiException catch (e) {
      if (mounted && !quiet) setState(() => _error = e);
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(ServerOrder job) async {
    final name = job.client?.name ?? 'Client';
    final sure = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.light,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tolak permintaan ini?',
                style: AppTypography.style(
                  size: 15,
                  weight: AppTypography.semiBold,
                  color: HelperStyle.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$name akan diberi tahu. Permintaan ini tidak akan menjadi '
                'pesanan aktif.',
                style: AppTypography.style(
                  size: 11,
                  weight: AppTypography.regular,
                  color: HelperStyle.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: HelperButton(
                      label: 'Batal',
                      soft: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HelperButton(
                      label: 'Ya, tolak',
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (sure != true || !mounted) return;
    await _run(() => _store.reject(job.id));
  }

  Future<void> _offer(ServerOrder job) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => MakeOfferPage(job: job)));

  Future<void> _proof(ServerOrder job) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => ProofPage(job: job)));

  void _progress(ServerOrder job) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => JobProgressPage(orderId: job.id)),
  );

  void _transaction(ServerOrder job) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TransactionDetailPage(orderId: job.id),
    ),
  );

  Future<void> _chat(ServerOrder job) async {
    final chats = context.read<ChatStore>();
    try {
      await chats.refresh();
      final room = _roomFor(chats.rooms, job);
      if (!mounted) return;
      if (room == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Belum ada obrolan dengan Client untuk pesanan ini.'),
          ),
        );
        return;
      }
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => ChatRoomPage(room: room)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Ruang pesanan ini, atau ruang dengan pemesannya.
  static ChatRoom? _roomFor(List<ChatRoom> rooms, ServerOrder job) {
    for (final r in rooms) {
      if (r.orderId == job.id) return r;
    }
    final name = job.client?.name;
    for (final r in rooms) {
      if (name != null && r.peerName == name) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final job = _store.byId(widget.orderId);
        if (job == null || (_loading && job.history.isEmpty)) {
          return _placeholder();
        }
        return _page(job);
      },
    );
  }

  Widget _placeholder() {
    final error = _error;
    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          const HelperHeader(title: 'Detail pesanan'),
          Expanded(
            child: error == null
                ? const Center(child: CircularProgressIndicator())
                : EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Pesanan gagal dimuat',
                    message: error.message,
                    actionLabel: 'Coba lagi',
                    onAction: () {
                      setState(() => _loading = true);
                      _load();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _page(ServerOrder job) {
    final status = job.status;
    final offer = _store.myOffer(job);
    final waitingDecision =
        status == OrderStatus.awaitingQuote &&
        offer?.status == OfferStatus.submitted;

    if (waitingDecision) return _waiting(job, offer!);
    if (status == OrderStatus.awaitingConfirmation ||
        status == OrderStatus.completed) {
      return _done(job);
    }

    final client = job.client?.name ?? 'Client';
    final price = job.price;
    final (title, subtitle) = switch (status) {
      _ when status.isWaiting => (
        'Detail permintaan',
        '$client memilih kamu secara langsung',
      ),
      OrderStatus.accepted => (
        'Pesanan diterima',
        'Pesanan aktif · #${job.number}',
      ),
      OrderStatus.onTheWay ||
      OrderStatus.arrived => ('Menuju lokasi', 'Perjalanan ke lokasi Client'),
      OrderStatus.inProgress || OrderStatus.priceAdjustment => (
        'Pengerjaan aktif',
        'Tetap perbarui progres pekerjaanmu',
      ),
      _ => ('Detail pesanan', '#${job.number}'),
    };

    final respondBy = job.respondBy;
    final banner = switch (status) {
      _ when status.isWaiting && respondBy != null => HelperBanner(
        title: 'Batas respons 5 menit',
        trailing: CountdownText(until: respondBy, clock: () => _store.now),
      ),
      _ when status.isWaiting => null,
      OrderStatus.accepted => HelperBanner(
        tone: BannerTone.green,
        title: 'Penawaran disetujui',
        message:
            '$client menyetujui ${rupiah(price, spaced: false)}. Kamu bisa '
            'mulai perjalanan.',
      ),
      OrderStatus.onTheWay => const HelperBanner(
        title: 'Dalam perjalanan',
        message: 'Client sudah diberi tahu bahwa kamu menuju lokasi.',
      ),
      OrderStatus.arrived => const HelperBanner(
        title: 'Sudah sampai',
        message: 'Mulai pengerjaan saat kamu siap.',
      ),
      OrderStatus.inProgress ||
      OrderStatus.priceAdjustment => const HelperBanner(
        title: 'Sedang dikerjakan',
        message: 'Kamu sudah tiba dan mulai mengerjakan pesanan.',
      ),
      OrderStatus.cancelledByHelper => const HelperBanner(
        tone: BannerTone.gray,
        title: 'Permintaan ditolak',
        message: 'Client sudah diberi tahu.',
      ),
      _ when status.isCancelled => HelperBanner(
        tone: BannerTone.gray,
        title: status.label,
        message: 'Pesanan ini tidak dilanjutkan.',
      ),
      _ => HelperBanner(tone: BannerTone.gray, title: status.label),
    };

    final working =
        status == OrderStatus.onTheWay ||
        status == OrderStatus.arrived ||
        status == OrderStatus.inProgress ||
        status == OrderStatus.priceAdjustment;

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          HelperHeader(title: title, subtitle: subtitle),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  ?banner,
                  if (banner != null) const SizedBox(height: 12),
                  HelperCard(
                    child: JobSummary(
                      order: job,
                      onChat: working ? () => _chat(job) : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (status.isWaiting)
                    HelperCard(
                      child: HelperRow(
                        'Estimasi Client · belum disepakati',
                        rupiah(job.estimatedPrice, spaced: false),
                      ),
                    )
                  else if (status == OrderStatus.accepted)
                    HelperCard(
                      child: Column(
                        children: [
                          EarningBreakdown(
                            price: price,
                            commission: job.commission,
                          ),
                          const SizedBox(height: 10),
                          HelperBanner(
                            title: 'TD-Wallet · dana ditahan',
                            message:
                                'Simulasi escrow ${rupiah(price, spaced: false)} '
                                'sudah ditahan dari saldo Client. Belum menjadi '
                                'pendapatan cair.',
                          ),
                        ],
                      ),
                    )
                  else if (working)
                    _WorkStep(
                      job: job,
                      onProgress:
                          status == OrderStatus.inProgress ||
                              status == OrderStatus.priceAdjustment
                          ? () => _progress(job)
                          : null,
                    ),
                  if (status == OrderStatus.onTheWay ||
                      status == OrderStatus.arrived) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Tekan tombol di bawah hanya setelah kamu tiba dan siap '
                      'memulai pengerjaan.',
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        color: HelperStyle.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _actions(job),
    );
  }

  Widget? _actions(ServerOrder job) {
    final status = job.status;
    if (status.isWaiting) {
      return HelperBottomBar(
        children: [
          HelperButton(
            label: 'Tolak Permintaan',
            soft: true,
            onPressed: _busy ? null : () => _reject(job),
          ),
          HelperButton(
            label: 'Buat Penawaran',
            isLoading: _busy,
            onPressed: () => _offer(job),
          ),
        ],
      );
    }
    final (label, action) = switch (status) {
      OrderStatus.accepted => (
        'Mulai Perjalanan',
        () => _run(() => _store.advance(job.id, OrderStatus.onTheWay)),
      ),
      OrderStatus.onTheWay || OrderStatus.arrived => (
        'Mulai Pengerjaan',
        () => _run(() => _store.startWork(job.id)),
      ),
      OrderStatus.inProgress => ('Unggah Bukti', () => _proof(job)),
      _ => (null, null),
    };
    if (label == null || action == null) return null;
    return HelperBottomBar(
      children: [
        HelperButton(label: label, isLoading: _busy, onPressed: action),
      ],
    );
  }

  /// Penawaran terkirim, menunggu Client.
  Widget _waiting(ServerOrder job, OrderOffer offer) {
    final client = job.client?.name ?? 'Client';
    final validUntil = offer.validUntil;

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          HelperHeader(
            title: 'Menunggu keputusan',
            subtitle: 'Penawaran berhasil dikirim ke $client',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: HelperStyle.softRed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const OrderIcon(HelperStyle.iconHourglass, size: 26),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Menunggu persetujuan Client',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    size: 17,
                    weight: AppTypography.semiBold,
                    color: HelperStyle.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$client sedang meninjau harga penawaranmu.',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.regular,
                    color: HelperStyle.muted,
                  ),
                ),
                const SizedBox(height: 20),
                HelperBanner(
                  title: 'Batas persetujuan 5 menit',
                  message: 'Pesanan belum aktif selama menunggu persetujuan.',
                  trailing: validUntil == null
                      ? null
                      : CountdownText(
                          until: validUntil,
                          clock: () => _store.now,
                        ),
                ),
                const SizedBox(height: 12),
                HelperCard(
                  child: Column(
                    children: [
                      JobSummary(order: job, details: false),
                      const Divider(height: 22, color: HelperStyle.cardBorder),
                      EarningBreakdown(
                        price: offer.price,
                        priceLabel: 'Penawaran Helper',
                      ),
                      if (job.estimatedPrice > 0 &&
                          job.estimatedPrice != offer.price) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Estimasi awal Client '
                          '${rupiah(job.estimatedPrice, spaced: false)}, '
                          'berbeda dari penawaranmu '
                          '${rupiah(offer.price, spaced: false)}.',
                          style: AppTypography.style(
                            size: 9,
                            weight: AppTypography.regular,
                            color: HelperStyle.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Halaman ini ikut berubah setelah Client memutuskan. Jangan '
                  'mulai perjalanan sebelum disetujui.',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    size: 10,
                    weight: AppTypography.regular,
                    color: HelperStyle.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: HelperBottomBar(
        children: [
          HelperButton(
            label: 'Kembali ke pesanan',
            soft: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  /// Ditandai selesai (menunggu konfirmasi) atau sudah dikonfirmasi.
  Widget _done(ServerOrder job) {
    final client = job.client?.name ?? 'Client';
    final completed = job.status == OrderStatus.completed;
    final finishedAt =
        job.helperFinishedAt ?? job.enteredAt(OrderStatus.awaitingConfirmation);

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          HelperHeader(
            title: 'Pekerjaan selesai',
            subtitle: completed
                ? 'Dikonfirmasi $client'
                : 'Menunggu konfirmasi $client',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: HelperStyle.softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: HelperStyle.green,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tugasmu sudah selesai!',
                    textAlign: TextAlign.center,
                    style: AppTypography.style(
                      size: 17,
                      weight: AppTypography.semiBold,
                      color: HelperStyle.ink,
                    ),
                  ),
                  if (finishedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ditandai selesai pada ${dateLabel(finishedAt)}, '
                      '${clockLabel(finishedAt)}',
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        color: HelperStyle.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (completed)
                    HelperBanner(
                      tone: BannerTone.green,
                      title: 'Pendapatan sudah cair',
                      message:
                          '$client sudah mengonfirmasi. Pendapatan bersih '
                          'masuk ke TD-Wallet.',
                    )
                  else
                    HelperBanner(
                      title: 'Menunggu konfirmasi Client',
                      message:
                          'Pendapatan cair setelah $client mengonfirmasi '
                          'pekerjaan selesai.',
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
                        EarningBreakdown(
                          price: job.price,
                          commission: job.commission,
                          netLabel: completed
                              ? 'Pendapatan bersih · cair'
                              : 'Estimasi bersih · menunggu',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: HelperBottomBar(
        children: [
          HelperButton(
            label: 'Kembali ke pesanan',
            soft: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          HelperButton(
            label: 'Lihat transaksi',
            onPressed: () => _transaction(job),
          ),
        ],
      ),
    );
  }
}

/// Langkah saat ini selama perjalanan dan pengerjaan.
class _WorkStep extends StatelessWidget {
  const _WorkStep({required this.job, this.onProgress});

  final ServerOrder job;
  final VoidCallback? onProgress;

  @override
  Widget build(BuildContext context) {
    final pickup = job.pickup;
    final destination = job.destination;
    final onProgress = this.onProgress;
    final working = onProgress != null;

    final title = working
        ? 'Selesaikan, lalu dokumentasikan'
        : pickup != null
        ? 'Jemput di ${pickup.label}'
        : 'Menuju ${destination?.label ?? 'lokasi Client'}';
    final message = working
        ? 'Kerjakan sesuai catatan Client. Ambil foto bukti sebelum menandai '
              'selesai.'
        : 'Pastikan detail pesanan sesuai sebelum mulai mengerjakan.';

    return HelperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: HelperStyle.softRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: OrderIcon(
                  working
                      ? HelperStyle.categoryIcon(job.categoryCode)
                      : HelperStyle.iconDropoff,
                  size: 16,
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
                        size: 12,
                        weight: AppTypography.semiBold,
                        color: HelperStyle.ink,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        color: HelperStyle.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: HelperStyle.cardBorder),
          HelperRow('Harga disepakati', rupiah(job.price, spaced: false)),
          Text(
            'Dana simulasi TD-Wallet tetap ditahan sampai pekerjaan '
            'dikonfirmasi selesai.',
            style: AppTypography.style(
              size: 9,
              weight: AppTypography.regular,
              color: HelperStyle.muted,
              height: 1.5,
            ),
          ),
          if (working) ...[
            const SizedBox(height: 12),
            HelperButton(
              label: 'Lihat Progres',
              soft: true,
              onPressed: onProgress,
            ),
          ],
        ],
      ),
    );
  }
}
