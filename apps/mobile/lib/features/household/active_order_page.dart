import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../chat/chat_room_page.dart';
import '../chat/chat_store.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/widgets/helper_rating_view.dart';
import '../order/widgets/order_widgets.dart';
import 'extend_duration_page.dart';
import 'household_models.dart';
import 'widgets/household_widgets.dart';

/// Satu kalimat status pesanan aktif, dipakai juga di beranda dan Aktifitas.
String activeStatusLabel(OrderStore store) {
  final order = store.active;
  if (order == null) return '';
  return switch (store.status!) {
    ActiveStatus.onTheWay =>
      'Tiba dalam ${_minutesUntil(store.now, order.arriveAt)} menit',
    ActiveStatus.working =>
      'Selesai dalam ${_minutesUntil(store.now, order.finishAt)} menit',
    ActiveStatus.timeUp => 'Waktu helper sudah habis',
    ActiveStatus.finished => 'Beri rating helper',
  };
}

int _minutesUntil(DateTime now, DateTime then) {
  final minutes = then.difference(now).inSeconds / 60;
  return minutes <= 0 ? 0 : minutes.ceil();
}

/// 54 menit 23 detik -> "54:23"; lebih dari sejam -> "1:04:23".
String countdownLabel(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Pesanan Household yang sedang berjalan. Isinya mengikuti status:
/// menuju lokasi (bisa batal sebentar), bekerja (hitung mundur + tambah
/// durasi), lalu selesai (beri rating).
class ActiveOrderPage extends StatefulWidget {
  const ActiveOrderPage({super.key, this.store, this.chatStore});

  /// Diisi saat pengujian. Default: [OrderStore.instance] dan
  /// [ChatStore.instance].
  final OrderStore? store;
  final ChatStore? chatStore;

  @override
  State<ActiveOrderPage> createState() => _ActiveOrderPageState();
}

class _ActiveOrderPageState extends State<ActiveOrderPage> {
  late final _store = widget.store ?? OrderStore.instance;

  /// Saat bekerja: false = hitung mundur, true = detail pesanan.
  bool _showDetail = false;

  /// Dialog waktu habis sedang terbuka atau dijadwalkan.
  bool _askingTimeUp = false;

  /// Chat dengan helper, misal menjelaskan patokan rumah. Nanti: ruang
  /// chat milik pesanan (`POST /chats/orders/{id}`).
  void _chat(HourlyHelper helper) {
    final chats = widget.chatStore ?? ChatStore.instance;
    final room = chats.openWithHelper(
      helperId: helper.id,
      name: helper.name,
      photoUrl: helper.photoUrl,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomPage(room: room, store: chats),
      ),
    );
  }

  void _support() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Pusat bantuan belum tersedia.')),
  );

  Future<void> _extend() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ExtendDurationPage(store: _store)),
  );

  /// Waktu habis: tanya tambah waktu atau selesai. Hanya saat halaman ini
  /// yang tampil; kalau tertutup halaman lain (misal Tambah Durasi), dialog
  /// muncul begitu pelanggan kembali ke sini (store berdetak tiap detik).
  void _askTimeUp() {
    if (_askingTimeUp || ModalRoute.of(context)?.isCurrent != true) return;
    _askingTimeUp = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _store.status != ActiveStatus.timeUp) {
        _askingTimeUp = false;
        return;
      }
      final extend = await showTimeUpDialog(context);
      if (!mounted) return;
      if (extend) {
        await _extend();
      } else {
        _store.endWork();
      }
      _askingTimeUp = false;
    });
  }

  Future<void> _cancel() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text(
          'Helper yang sedang menuju lokasi akan dibatalkan.',
        ),
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
    // Batas waktu bisa lewat selama dialog terbuka.
    if (!_store.canCancel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batas waktu pembatalan sudah lewat.')),
      );
      return;
    }
    _store.cancel();
    Navigator.of(context).maybePop();
  }

  void _rate(int stars) {
    _store.complete(rating: stars);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terima kasih atas ratingnya!')),
    );
    Navigator.of(context).maybePop();
  }

  /// Rating tidak wajib: pesanan tetap ditutup dan masuk riwayat.
  void _skipRating() {
    _store.complete();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final order = _store.active;
        if (order == null) {
          // Pesanan sudah ditutup (dibatalkan/dinilai) dari tempat lain.
          return const OrderEndedView();
        }

        final status = _store.status!;
        if (status == ActiveStatus.finished) {
          final helper = order.draft.helper;
          return HelperRatingView(
            name: helper.name,
            photoUrl: helper.photoUrl,
            onRate: _rate,
            onSkip: _skipRating,
          );
        }

        final draft = order.draft;
        final header = ColoredHeader.of(
          draft.service,
          title: 'Household',
          trailing: SupportButton(onTap: _support),
        );

        final timeUp = status == ActiveStatus.timeUp;
        if (timeUp) _askTimeUp();

        if (timeUp || (status == ActiveStatus.working && !_showDetail)) {
          return _CountdownView(
            header: header,
            order: order,
            remaining: _store.remaining,
            onExtend: _extend,
            onShowDetail: () => setState(() => _showDetail = true),
            onChat: () => _chat(order.draft.helper),
          );
        }

        final working = status == ActiveStatus.working;
        return Scaffold(
          backgroundColor: AppColors.light,
          body: Column(
            children: [
              header,
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  children: [
                    // Saat jendela batal habis, bar memudar dan ruangnya
                    // menyusut, bukan hilang mendadak.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _store.canCancel
                            ? Padding(
                                key: const ValueKey('cancel'),
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _CancelBar(
                                  fraction: () => _cancelFraction(order),
                                  onTap: _cancel,
                                  // Bangun ulang begitu bar habis, tanpa
                                  // menunggu tick store berikutnya.
                                  onExpired: () => setState(() {}),
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey('no-cancel'),
                                width: double.infinity,
                              ),
                      ),
                    ),
                    _OrderCard(order: order),
                    if (working) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _showDetail = false),
                        child: const Text('Lihat durasi tersisa'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: HelperFooter(
            helper: draft.helper,
            onChat: () => _chat(draft.helper),
            caption: working ? 'Selesai di jam' : 'Estimasi sampai',
            time: clockLabel(working ? order.finishAt : order.arriveAt),
          ),
        );
      },
    );
  }

  /// Sisa jendela batal, 1 = baru dibuat, 0 = habis.
  double _cancelFraction(ActiveOrder order) {
    final left = order.cancelDeadline.difference(_store.now).inMilliseconds;
    return (left / OrderStore.cancelWindow.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// Tombol batal berbentuk bar yang menyusut selama jendela pembatalan.
///
/// Digambar ulang tiap frame lewat [Ticker], bukan tiap detik dari
/// [OrderStore]: dengan jam simulasi 60x, satu detik sama dengan 10% jendela
/// batal, jadi bar akan terlihat melompat-lompat.
class _CancelBar extends StatefulWidget {
  const _CancelBar({
    required this.fraction,
    required this.onTap,
    required this.onExpired,
  });

  /// Dibaca ulang tiap frame: 1 = baru dibuat, 0 = habis.
  final double Function() fraction;
  final VoidCallback onTap;

  /// Dipanggil sekali saat bar mencapai 0.
  final VoidCallback onExpired;

  @override
  State<_CancelBar> createState() => _CancelBarState();
}

class _CancelBarState extends State<_CancelBar>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_onTick);

  void _onTick(Duration _) {
    if (widget.fraction() <= 0) {
      _ticker.stop();
      widget.onExpired();
    }
    setState(() {});
  }

  static const _width = 190.0;
  static const _height = 30.0;
  static const _radius = BorderRadius.all(Radius.circular(20));

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Widget _label(Color color) => Center(
    child: Text(
      'Batal',
      style: AppTypography.style(
        size: 11,
        weight: AppTypography.medium,
        color: color,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fraction = widget.fraction();

    return Center(
      child: Semantics(
        button: true,
        label: 'Batalkan pesanan',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: _radius,
              border: Border.all(color: AppColors.primary),
            ),
            child: ClipRRect(
              borderRadius: _radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Lapis bawah: teks merah di atas latar putih.
                  _label(AppColors.primary),
                  // Lapis atas: bagian merah berisi teks putih, dipotong
                  // selebar sisa waktu. Batas warna teks ikut bergeser
                  // bersama bar, jadi tidak ada perubahan warna mendadak.
                  ClipRect(
                    clipper: _WidthClipper(fraction),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: _radius,
                      ),
                      child: _label(AppColors.light),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Memotong anak dari kiri selebar [fraction] dari lebarnya.
class _WidthClipper extends CustomClipper<Rect> {
  const _WidthClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_WidthClipper old) => old.fraction != fraction;
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final ActiveOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: OrderStyle.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Alamat'),
          const SizedBox(height: 10),
          ...orderAddressBoxes(order.draft),
          const SizedBox(height: 16),
          const SectionLabel('Detail Pengerjaan'),
          const SizedBox(height: 10),
          OutlinedBox(
            child: Column(
              children: workDetailRows(
                order.draft,
                totalHours: order.totalHours,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Rincian harga'),
          const SizedBox(height: 10),
          OutlinedBox(child: Column(children: priceRows(order.price))),
        ],
      ),
    );
  }
}

class _CountdownView extends StatelessWidget {
  const _CountdownView({
    required this.header,
    required this.order,
    required this.remaining,
    required this.onExtend,
    required this.onShowDetail,
    required this.onChat,
  });

  final Widget header;
  final ActiveOrder order;
  final Duration remaining;
  final VoidCallback onExtend;
  final VoidCallback onShowDetail;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final helper = order.draft.helper;

    return Scaffold(
      backgroundColor: AppColors.light,
      body: Column(
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: OrderStyle.card(radius: 14),
                  child: Column(
                    children: [
                      Text(
                        'Durasi tersisa',
                        style: AppTypography.style(
                          size: 11,
                          weight: AppTypography.regular,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        countdownLabel(remaining),
                        style: AppTypography.style(
                          size: 52,
                          weight: AppTypography.regular,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedBox(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      HelperAvatar(
                        name: helper.name,
                        photoUrl: helper.photoUrl,
                        size: 46,
                      ),
                      const SizedBox(width: 18),
                      // Expanded: nama panjang dipotong, bukan meluap.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              helper.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                size: 12,
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
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 230,
            child: PrimaryButton(label: 'Tambah Durasi', onPressed: onExtend),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onShowDetail,
            child: Text(
              'Lihat detail pesanan',
              style: AppTypography.style(
                size: 13,
                weight: AppTypography.regular,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

/// "Waktu helper sudah habis, mau tambah waktu?" — true kalau "Tambah",
/// false kalau "Selesai". Wajib memilih: tidak bisa ditutup dengan tombol
/// kembali atau mengetuk di luar dialog.
Future<bool> showTimeUpDialog(BuildContext context) async {
  final extend = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.light,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ilustrasi jam weker di desain belum diekspor; ikon sementara.
              Container(
                width: 96,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(36),
                ),
                child: const Icon(
                  Icons.alarm_rounded,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Waktu helper sudah habis, mau\ntambah waktu?',
                textAlign: TextAlign.center,
                style: AppTypography.style(
                  size: 13,
                  weight: AppTypography.medium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: DialogButton(
                      label: 'Tambah',
                      color: AppColors.primary,
                      outlined: true,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogButton(
                      label: 'Selesai',
                      color: AppColors.primary,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return extend ?? false;
}
