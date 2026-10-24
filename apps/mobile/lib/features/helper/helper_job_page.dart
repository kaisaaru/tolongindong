import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/countdown_text.dart';
import '../../widgets/empty_state.dart';
import '../household/household_models.dart';
import '../order/order_repository.dart';
import '../order/widgets/order_widgets.dart';
import 'earnings_page.dart';
import 'helper_store.dart';
import 'job_chat.dart';
import 'job_progress_page.dart';
import 'make_offer_page.dart';
import 'proof_page.dart';
import 'widgets/helper_widgets.dart';

/// Satu pekerjaan helper. Isinya mengikuti status:
///
/// - menunggu helper: Detail permintaan (Tolak / Buat Penawaran)
/// - penawaran terkirim: Menunggu keputusan Client (kirim ulang kalau
///   batas 5 menit lewat)
/// - diterima: Pesanan diterima (Mulai Perjalanan)
/// - menuju lokasi: Menuju lokasi (Tiba di Lokasi; Delivery langsung
///   Mulai Pengerjaan)
/// - sampai: Tiba di lokasi (Mulai Pengerjaan)
/// - dikerjakan: Pengerjaan aktif (Delivery: Unggah Bukti; lainnya: Lihat
///   Progres Pekerjaan, lalu Selesaikan Pekerjaan)
/// - menunggu konfirmasi / selesai: Pekerjaan selesai
///
/// Delivery mengikuti desain Helper Delivery (tanpa tahap tiba, bukti
/// foto); Household dan Personal mengikuti alur bernomor 01-17.
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

  Future<void> _offer(ServerOrder job, {int? price}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MakeOfferPage(job: job, initialPrice: price),
        ),
      );

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

  void _earnings() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const EarningsPage()));

  Future<void> _chat(ServerOrder job) => openJobChat(context, job);

  /// "Chat dengan Nadia" selebar kartu.
  Widget _chatButton(ServerOrder job) => HelperButton(
    label: 'Chat dengan ${_firstName(job)}',
    soft: true,
    onPressed: () => _chat(job),
  );

  static String _firstName(ServerOrder job) =>
      (job.client?.name ?? 'Client').trim().split(' ').first;

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

    final delivery = job.categoryCode == 'delivery';
    final client = job.client?.name ?? 'Client';
    final first = _firstName(job);
    final price = job.price;
    final working =
        status == OrderStatus.inProgress ||
        status == OrderStatus.priceAdjustment;
    // Delivery tidak punya tahap tiba sendiri: sampai = masih menuju.
    final arrived = status == OrderStatus.arrived && !delivery;
    final travelling =
        status == OrderStatus.onTheWay ||
        (status == OrderStatus.arrived && delivery);

    final (title, subtitle) = switch (status) {
      _ when status.isWaiting => (
        'Detail permintaan',
        '$client memilih kamu secara langsung',
      ),
      OrderStatus.accepted => (
        'Pesanan diterima',
        'Pesanan aktif · #${job.number}',
      ),
      _ when arrived => (
        'Tiba di lokasi',
        'Siap memulai pekerjaan di lokasi $first',
      ),
      _ when travelling => ('Menuju lokasi', 'Perjalanan ke lokasi Client'),
      _ when working => (
        'Pengerjaan aktif',
        'Tetap perbarui progres pekerjaanmu',
      ),
      _ => ('Detail pesanan', '#${job.number}'),
    };

    final respondBy = job.respondBy;
    final departedAt = job.enteredAt(OrderStatus.onTheWay);
    final arrivedAt = job.enteredAt(OrderStatus.arrived);
    final startedAt = job.enteredAt(OrderStatus.inProgress);
    final banner = switch (status) {
      _ when status.isWaiting && respondBy != null => HelperBanner(
        title: 'Batas respons 5 menit',
        message:
            'Masuk ${clockLabel(job.createdAt)} · respons paling lambat '
            '${clockLabel(respondBy)}',
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
      _ when arrived => HelperBanner(
        tone: BannerTone.green,
        title: arrivedAt == null
            ? 'Tiba di lokasi'
            : 'Tiba di lokasi · ${clockLabel(arrivedAt)}',
        message: arrivedAt == null
            ? '$client tahu kamu sudah sampai.'
            : '${dateLabel(arrivedAt)} · $client tahu kamu sudah sampai.',
      ),
      _ when travelling => HelperBanner(
        title: 'Dalam perjalanan',
        message: departedAt == null
            ? 'Client sudah diberi tahu bahwa kamu menuju lokasi.'
            : 'Berangkat ${dateLabel(departedAt)}, '
                  '${clockLabel(departedAt)}. Client sudah diberi tahu '
                  'bahwa kamu menuju lokasi.',
      ),
      _ when working => HelperBanner(
        title: 'Sedang dikerjakan',
        message: switch ((startedAt, arrivedAt)) {
          (final s?, final a?) when !delivery =>
            'Dimulai ${dateLabel(s)}, ${clockLabel(s)}. Tiba di lokasi '
                '${clockLabel(a)}.',
          (final s?, _) => 'Dimulai ${dateLabel(s)}, ${clockLabel(s)}.',
          _ => 'Kamu sudah tiba dan mulai mengerjakan pesanan.',
        },
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

    final note = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      color: HelperStyle.muted,
      height: 1.5,
    );

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
                      onChat: status.isTerminal ? null : () => _chat(job),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (status.isWaiting) ...[
                    HelperCard(
                      child: HelperRow(
                        'Estimasi Client · belum disepakati',
                        rupiah(job.estimatedPrice, spaced: false),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Data kebutuhan diisi oleh Client. Tinjau dahulu '
                      'sebelum menentukan upah jasa dalam penawaran.',
                      style: note,
                    ),
                  ] else if (status == OrderStatus.accepted)
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
                  else if (travelling && delivery) ...[
                    _StepCard(
                      icon: HelperStyle.iconDropoff,
                      title: switch (job.pickup) {
                        final p? => 'Jemput di ${p.label}',
                        null =>
                          'Menuju ${job.destination?.label ?? 'lokasi Client'}',
                      },
                      message:
                          'Pastikan detail pesanan sesuai sebelum mulai '
                          'mengerjakan.',
                      price: price,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tekan tombol di bawah hanya setelah kamu tiba dan siap '
                      'memulai pengerjaan.',
                      style: note,
                    ),
                  ] else if (travelling)
                    _StepCard(
                      icon: HelperStyle.iconDropoff,
                      title: 'Perbarui status secara manual',
                      message:
                          'Tidak ada peta atau pelacakan GPS langsung. Tekan '
                          '"Tiba di Lokasi" hanya setelah sampai di alamat '
                          '$first.',
                      price: price,
                      children: [_chatButton(job)],
                    )
                  else if (arrived)
                    HelperBanner(
                      title: 'Pengerjaan belum dimulai',
                      message:
                          'Pastikan kebutuhan $first sudah dipahami. Tombol di '
                          'bawah memulai pengerjaan, bukan menandai selesai.',
                    )
                  else if (working && delivery)
                    _StepCard(
                      icon: HelperStyle.categoryIcon(job.categoryCode),
                      title: 'Antar, serahkan, dokumentasikan',
                      message:
                          'Serahkan sesuai catatan Client. Ambil foto bukti '
                          'sebelum menandai selesai.',
                      price: price,
                      children: [
                        HelperButton(
                          label: 'Lihat Progres',
                          soft: true,
                          onPressed: () => _progress(job),
                        ),
                      ],
                    )
                  else if (working)
                    _StepCard(
                      icon: HelperStyle.categoryIcon(job.categoryCode),
                      title: 'Kerjakan sesuai kebutuhan $first',
                      message:
                          'Buka progres untuk melihat tahapan pesanan dan '
                          'menandai penyelesaian saat pekerjaan sudah '
                          'selesai.',
                      price: price,
                      children: [_chatButton(job)],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _actions(job, delivery: delivery),
    );
  }

  Widget? _actions(ServerOrder job, {required bool delivery}) {
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
      OrderStatus.onTheWay when !delivery => (
        'Tiba di Lokasi',
        () => _run(() => _store.advance(job.id, OrderStatus.arrived)),
      ),
      OrderStatus.onTheWay || OrderStatus.arrived => (
        'Mulai Pengerjaan',
        () => _run(() => _store.startWork(job.id)),
      ),
      OrderStatus.inProgress when delivery => (
        'Unggah Bukti',
        () => _proof(job),
      ),
      OrderStatus.inProgress => (
        'Lihat Progres Pekerjaan',
        () => _progress(job),
      ),
      _ => (null, null),
    };
    if (label == null || action == null) return null;
    return HelperBottomBar(
      children: [
        HelperButton(label: label, isLoading: _busy, onPressed: action),
      ],
    );
  }

  /// Penawaran terkirim, menunggu Client. Lewat 5 menit, helper bisa
  /// mengirim ulang supaya Client mendapat waktu baru.
  Widget _waiting(ServerOrder job, OrderOffer offer) {
    final client = job.client?.name ?? 'Client';
    final validUntil = offer.validUntil;
    final expired = validUntil != null && !validUntil.isAfter(_store.now);

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          HelperHeader(
            title: 'Menunggu keputusan',
            subtitle: 'Penawaran berhasil dikirim ke $client',
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
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: HelperStyle.softRed,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const OrderIcon(
                        HelperStyle.iconHourglass,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    expired
                        ? 'Belum ada keputusan Client'
                        : 'Menunggu persetujuan Client',
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
                  if (expired)
                    HelperBanner(
                      title: 'Batas persetujuan 5 menit sudah lewat',
                      message:
                          'Kirim ulang penawaran supaya $client mendapat '
                          'waktu 5 menit lagi. Pesanan belum aktif.',
                    )
                  else
                    HelperBanner(
                      title: 'Batas persetujuan 5 menit',
                      message:
                          'Pesanan belum aktif selama menunggu persetujuan.',
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
                        JobSummary(
                          order: job,
                          details: false,
                          onChat: () => _chat(job),
                        ),
                        const Divider(
                          height: 22,
                          color: HelperStyle.cardBorder,
                        ),
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
                  const SizedBox(height: 12),
                  _chatButton(job),
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
          if (expired)
            HelperButton(
              label: 'Kirim Ulang',
              onPressed: () => _offer(job, price: offer.price),
            ),
        ],
      ),
    );
  }

  /// Ditandai selesai (menunggu konfirmasi) atau sudah dikonfirmasi.
  Widget _done(ServerOrder job) {
    final client = job.client?.name ?? 'Client';
    final completed = job.status == OrderStatus.completed;
    final delivery = job.categoryCode == 'delivery';
    final finishedAt =
        job.helperFinishedAt ?? job.enteredAt(OrderStatus.awaitingConfirmation);
    final autoAt = autoConfirmAt(job);

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
                      message: autoAt == null
                          ? 'Pendapatan cair setelah $client mengonfirmasi '
                                'pekerjaan selesai.'
                          : '$client dapat mengonfirmasi pekerjaan. Jika '
                                'tidak, konfirmasi otomatis setelah 24 jam '
                                'pada ${dateLabel(autoAt)}, '
                                '${clockLabel(autoAt)}.',
                    ),
                  const SizedBox(height: 12),
                  HelperCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CategoryTag(
                          completed ? 'Dikonfirmasi' : 'Pekerjaan selesai',
                          tone: BannerTone.green,
                        ),
                        const SizedBox(height: 10),
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
                  if (!completed) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${rupiah(job.netPayout, spaced: false)} masih '
                      'tertunda dan belum masuk pendapatan cair. Dana '
                      'simulasi TD-Wallet tetap ditahan sampai penyelesaian '
                      'dikonfirmasi.',
                      textAlign: TextAlign.center,
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
      bottomNavigationBar: HelperBottomBar(
        children: [
          if (delivery)
            HelperButton(
              label: 'Kembali ke pesanan',
              soft: true,
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            HelperButton(
              label: 'Lihat pendapatan',
              soft: true,
              onPressed: _earnings,
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

/// Langkah saat ini selama perjalanan dan pengerjaan: ikon, judul,
/// penjelasan, harga disepakati, lalu tombol tambahan.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.price,
    this.children = const [],
  });

  final String icon;
  final String title;
  final String message;
  final int price;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
                child: OrderIcon(icon, size: 16),
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
          HelperRow('Harga disepakati', rupiah(price, spaced: false)),
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
          for (final child in children) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}
