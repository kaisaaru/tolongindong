import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../chat/chat_room_page.dart';
import '../chat/chat_store.dart';
import '../household/household_models.dart';
import '../household/widgets/household_widgets.dart';
import 'order_repository.dart';
import 'order_store.dart';
import 'order_style.dart';
import 'widgets/helper_rating_view.dart';
import 'widgets/order_widgets.dart';

/// 54 menit 23 detik -> "54:23"; lebih dari sejam -> "1:04:23".
String countdownLabel(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Detail satu pesanan dari server, untuk ketiga kategori: status, helper,
/// alamat, isi pesanan, rincian harga, dan aksi pelanggan (batal, selesai,
/// beri rating).
///
/// Helper memajukan status dari aplikasinya sendiri. Belum ada push
/// notification, jadi selama halaman terbuka pesanan dimuat ulang tiap
/// [pollEvery].
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId, this.clock});

  final int orderId;

  /// Diisi saat pengujian. Default: jam nyata.
  final DateTime Function()? clock;

  static const pollEvery = Duration(seconds: 8);

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late final _store = context.read<OrderStore>();
  late final _clock = widget.clock ?? DateTime.now;
  Timer? _poll;

  /// Hitung mundur durasi Household; hanya berdetak selama dikerjakan.
  Timer? _tick;

  bool _loading = true;
  ApiException? _error;

  /// Aksi (batal, selesai, rating) sedang dikirim.
  bool _busy = false;

  /// Setelah "Pesanan Selesai": tampilkan halaman rating.
  bool _askRating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(OrderDetailPage.pollEvery, (_) {
      final order = _store.byId(widget.orderId);
      if (order == null || !order.status.isTerminal) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
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

  /// Jalankan aksi ke server; gagal tampil sebagai snackbar.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(ServerOrder order) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: Text(_cancelNote(order.status)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _run(() => _store.cancel(order.id));
  }

  /// Aturan biaya batal backend (SettlementCalculator).
  static String _cancelNote(OrderStatus status) => switch (status) {
    OrderStatus.accepted =>
      'Gratis kalau kurang dari 2 menit sejak helper menerima. Setelah itu '
          'ada biaya pembatalan Rp5.000.',
    OrderStatus.onTheWay || OrderStatus.arrived =>
      'Helper sudah berangkat. Ada biaya pembatalan 25% dari harga untuk '
          'helper.',
    _ => 'Helper belum menerima pesanan, jadi tidak ada biaya pembatalan.',
  };

  Future<void> _confirm(ServerOrder order) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pekerjaan sudah selesai?'),
        content: const Text(
          'Pembayaran dari TD-Wallet diteruskan ke helper dan tidak bisa '
          'dibatalkan lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Belum'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sudah selesai'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    if (await _run(() => _store.confirm(order.id)) && mounted) {
      setState(() => _askRating = true);
    }
  }

  Future<void> _rate(int stars) async {
    final ok = await _run(() => _store.rate(widget.orderId, stars));
    if (!ok || !mounted) return;
    setState(() => _askRating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terima kasih atas ratingnya!')),
    );
  }

  void _skipRating() {
    _store.skipRating(widget.orderId);
    setState(() => _askRating = false);
  }

  Future<void> _chat(OrderHelper helper) async {
    final chats = context.read<ChatStore>();
    try {
      final room = await chats.openWithHelper(
        helperId: helper.id,
        name: helper.name,
        photoUrl: helper.photoUrl,
      );
      if (!mounted) return;
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

  /// Sisa durasi Household yang sedang dikerjakan; null kalau tidak ada
  /// hitung mundur (bukan Household, belum mulai, durasi tidak diketahui).
  Duration? _remaining(ServerOrder order) {
    final working =
        order.status == OrderStatus.inProgress ||
        order.status == OrderStatus.priceAdjustment;
    final start = order.enteredAt(OrderStatus.inProgress);
    final hours = order.parsed.durationHours;
    if (!working || start == null || hours == null) return null;
    final left = start.add(Duration(hours: hours)).difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  void _syncTick(bool needed) {
    if (needed && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needed) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final order = _store.byId(widget.orderId);
        if (order == null) return _buildPlaceholder();

        final helper = order.helper;
        final rateNow =
            _askRating &&
            order.status == OrderStatus.completed &&
            helper != null;
        if (rateNow) {
          return HelperRatingView(
            name: helper.name,
            photoUrl: helper.photoUrl,
            onRate: _rate,
            onSkip: _skipRating,
          );
        }

        final remaining = _remaining(order);
        _syncTick(remaining != null && remaining > Duration.zero);
        return _buildOrder(order, remaining);
      },
    );
  }

  /// Sebelum pesanan pertama kali dimuat, atau gagal dimuat.
  Widget _buildPlaceholder() {
    final error = _error;
    return Scaffold(
      backgroundColor: AppColors.light,
      body: SafeArea(
        child: Column(
          children: [
            const ArrowTitleBar('Detail Pesanan'),
            Expanded(
              child: error == null || _loading
                  ? const Center(child: CircularProgressIndicator())
                  : EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Pesanan gagal dimuat',
                      message: error.message,
                      actionLabel: 'Coba lagi',
                      onAction: _load,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrder(ServerOrder order, Duration? remaining) {
    final helper = order.helper;
    final parsed = order.parsed;

    return Scaffold(
      backgroundColor: AppColors.light,
      body: Column(
        children: [
          _header(order),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                children: [
                  OrderStatusBanner(
                    icon: _statusIcon(order.status),
                    title: order.status.label,
                    subtitle: _statusHint(order),
                  ),
                  if (remaining != null) ...[
                    const SizedBox(height: 14),
                    _CountdownCard(remaining: remaining),
                  ],
                  if (helper != null) ...[
                    const SizedBox(height: 18),
                    _HelperCard(helper: helper, onChat: () => _chat(helper)),
                  ],
                  if (order.pickup != null || order.destination != null) ...[
                    const SizedBox(height: 18),
                    const SectionLabel('Alamat'),
                    const SizedBox(height: 10),
                    if (order.pickup case final pickup?) ...[
                      AddressBox(
                        address: pickup,
                        title: 'Lokasi jemput',
                        icon: OrderStyle.iconLocationOrigin,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (order.destination case final destination?)
                      AddressBox(
                        address: destination,
                        title: order.pickup == null ? null : 'Lokasi tujuan',
                      ),
                  ],
                  const SizedBox(height: 18),
                  SectionLabel(parsed.title ?? 'Detail Pesanan'),
                  const SizedBox(height: 10),
                  OutlinedBox(
                    child: parsed.rows.isEmpty
                        ? Text(
                            parsed.freeText ?? order.description,
                            style: AppTypography.style(
                              size: 12,
                              weight: AppTypography.regular,
                              height: 1.5,
                            ),
                          )
                        : Column(
                            children: [
                              for (final row in parsed.rows)
                                InfoRow('${row.label}:', row.value),
                            ],
                          ),
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel('Rincian harga'),
                  const SizedBox(height: 10),
                  OutlinedBox(
                    child: Column(
                      children: [
                        InfoRow('No. pesanan', order.number, muted: true),
                        const InfoRow('Pembayaran', 'TD-Wallet', muted: true),
                        if (order.cancellationFee > 0)
                          InfoRow(
                            'Biaya pembatalan',
                            rupiah(order.cancellationFee),
                            muted: true,
                          ),
                        InfoRow(
                          'Total',
                          rupiah(order.price, spaced: false),
                          bold: true,
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
      bottomNavigationBar: _actions(order),
    );
  }

  /// Household: warna dan nama layanannya (dari judul "Household - Rumah").
  /// Lainnya merah dengan nama kategori.
  Widget _header(ServerOrder order) {
    final title = order.parsed.title ?? '';
    for (final service in HouseholdService.values) {
      if (title == 'Household - ${service.label}') {
        return ColoredHeader.of(service);
      }
    }
    return ColoredHeader(title: order.categoryName, color: AppColors.primary);
  }

  Widget? _actions(ServerOrder order) {
    final status = order.status;
    final Widget button;
    if (status.canConfirm) {
      button = PrimaryButton(
        label: 'Pesanan Selesai',
        isLoading: _busy,
        onPressed: () => _confirm(order),
      );
    } else if (status == OrderStatus.completed &&
        order.helper != null &&
        !_store.isRated(order.id)) {
      button = PrimaryButton(
        label: 'Beri Rating',
        onPressed: () => setState(() => _askRating = true),
      );
    } else if (!status.isTerminal &&
        status != OrderStatus.inProgress &&
        status != OrderStatus.priceAdjustment &&
        status != OrderStatus.disputed) {
      button = OutlinedButton(
        onPressed: _busy ? null : () => _cancel(order),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
        child: const Text('Batalkan Pesanan'),
      );
    } else {
      return null;
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.light,
        border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          child: button,
        ),
      ),
    );
  }

  static IconData _statusIcon(OrderStatus status) => switch (status) {
    _ when status.isWaiting => Icons.hourglass_top_rounded,
    OrderStatus.accepted || OrderStatus.onTheWay => Icons.directions_run,
    OrderStatus.arrived => Icons.location_on_outlined,
    OrderStatus.inProgress ||
    OrderStatus.priceAdjustment => Icons.handyman_outlined,
    OrderStatus.awaitingConfirmation => Icons.task_alt_rounded,
    OrderStatus.completed => Icons.check_circle_outline_rounded,
    _ when status.isCancelled => Icons.cancel_outlined,
    _ => Icons.info_outline_rounded,
  };

  String _statusHint(ServerOrder order) {
    final helper = order.helper?.name ?? 'Helper';
    return switch (order.status) {
      _ when order.status.isWaiting =>
        '$helper akan menerima atau menolak pesananmu. Saldo baru ditahan '
            'setelah diterima.',
      OrderStatus.accepted => '$helper sudah menerima pesananmu.',
      OrderStatus.onTheWay => '$helper sedang menuju lokasimu.',
      OrderStatus.arrived => '$helper sudah sampai di lokasi.',
      OrderStatus.inProgress || OrderStatus.priceAdjustment =>
        'Tekan "Pesanan Selesai" kalau pekerjaan sudah beres.',
      OrderStatus.awaitingConfirmation =>
        '$helper menandai pekerjaan selesai. Cek hasilnya, lalu konfirmasi.',
      OrderStatus.completed => 'Dipesan ${dateLabel(order.createdAt)}.',
      OrderStatus.cancelledByHelper => '$helper tidak bisa menerima pesanan.',
      _ when order.status.isCancelled =>
        'Saldo yang ditahan sudah dikembalikan ke TD-Wallet.',
      _ => 'Dipesan ${dateLabel(order.createdAt)}.',
    };
  }
}

/// "Durasi tersisa 54:23", seperti hitung mundur di desain Household.
class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final timeUp = remaining == Duration.zero;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: OrderStyle.card(radius: 14),
      child: Column(
        children: [
          Text(
            timeUp ? 'Waktu helper sudah habis' : 'Durasi tersisa',
            style: AppTypography.style(size: 11, weight: AppTypography.regular),
          ),
          const SizedBox(height: 4),
          Text(
            countdownLabel(remaining),
            style: AppTypography.style(
              size: 44,
              weight: AppTypography.regular,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelperCard extends StatelessWidget {
  const _HelperCard({required this.helper, required this.onChat});

  final OrderHelper helper;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return OutlinedBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          HelperAvatar(name: helper.name, photoUrl: helper.photoUrl, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  helper.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    size: 13,
                    weight: AppTypography.medium,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                StarRow(rating: helper.rating, size: 12, gap: 1),
              ],
            ),
          ),
          ChatHelperButton(onTap: onChat),
        ],
      ),
    );
  }
}
