import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
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
  const ActiveOrderPage({super.key, this.store});

  /// Diisi saat pengujian. Default: [OrderStore.instance].
  final OrderStore? store;

  @override
  State<ActiveOrderPage> createState() => _ActiveOrderPageState();
}

class _ActiveOrderPageState extends State<ActiveOrderPage> {
  late final _store = widget.store ?? OrderStore.instance;

  /// Saat bekerja: false = hitung mundur, true = detail pesanan.
  bool _showDetail = false;

  void _support() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Pusat bantuan belum tersedia.')),
  );

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final order = _store.active;
        if (order == null) {
          // Pesanan sudah ditutup (dibatalkan/dinilai) dari tempat lain.
          return const Scaffold(body: SizedBox.shrink());
        }

        final status = _store.status!;
        if (status == ActiveStatus.finished) {
          return _RatingView(helper: order.draft.helper, onRate: _rate);
        }

        final draft = order.draft;
        final header = ColoredHeader(
          title: 'Household',
          color: draft.service.headerColor,
          trailing: SupportButton(onTap: _support),
        );

        if (status == ActiveStatus.working && !_showDetail) {
          return _CountdownView(
            header: header,
            order: order,
            remaining: _store.remaining,
            onExtend: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ExtendDurationPage(store: _store),
              ),
            ),
            onShowDetail: () => setState(() => _showDetail = true),
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
          AddressBox(address: order.draft.address),
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
  });

  final Widget header;
  final ActiveOrder order;
  final Duration remaining;
  final VoidCallback onExtend;
  final VoidCallback onShowDetail;

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            helper.name,
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

/// Halaman "Beri reting helper".
///
/// Ukuran diukur dari desain (frame 412 dp, status bar 52 dp): kartu mulai
/// 180 dp di bawah status bar, 37 dp dari tepi layar; cincin kiri berpusat
/// 86 dp dari kiri dan 155 dp di bawah tepi atas kartu, sebagian tertutup
/// kartu.
class _RatingView extends StatelessWidget {
  const _RatingView({required this.helper, required this.onRate});

  final HourlyHelper helper;
  final ValueChanged<int> onRate;

  static const _cardTop = 180.0; // di bawah status bar
  static const _cardSide = 37.0;

  @override
  Widget build(BuildContext context) {
    final cardTop = MediaQuery.paddingOf(context).top + _cardTop;

    return Scaffold(
      backgroundColor: AppColors.light,
      body: CustomPaint(
        painter: _RatingRingsPainter(cardTop: cardTop),
        child: Stack(
          children: [
            Positioned(
              top: cardTop,
              left: _cardSide,
              right: _cardSide,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000), // hitam 20%
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Beri reting helper',
                      style: AppTypography.style(
                        size: 14,
                        weight: AppTypography.semiBold,
                      ),
                    ),
                    const SizedBox(height: 23),
                    HelperAvatar(
                      name: helper.name,
                      photoUrl: helper.photoUrl,
                      size: 48,
                    ),
                    const SizedBox(height: 11),
                    Text(
                      helper.name,
                      style: AppTypography.style(
                        size: 14,
                        weight: AppTypography.regular,
                      ),
                    ),
                    const SizedBox(height: 17),
                    _StarPicker(onPicked: onRate),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dua cincin merah bergradasi (merah di kiri bawah, memudar ke putih di
/// kanan atas), sama seperti cincin SVG di Detail Pesanan.
class _RatingRingsPainter extends CustomPainter {
  const _RatingRingsPainter({required this.cardTop});

  final double cardTop;

  void _ring(Canvas canvas, Offset center, double radius, double stroke) {
    final rect = Rect.fromCircle(center: center, radius: radius + stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFFFF4B4B), Color(0xFFFFFFFF)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Cincin kiri: diameter luar 232 dp, tebal 45 dp.
    _ring(canvas, Offset(86, cardTop + 155), 93.5, 45);
    // Cincin besar di kanan bawah, berpusat di luar layar.
    final w = size.width;
    _ring(canvas, Offset(w * 0.98, size.height + 55), w * 0.55, w * 0.17);
  }

  @override
  bool shouldRepaint(_RatingRingsPainter old) => old.cardTop != cardTop;
}

/// Lima bintang abu-abu; mengetuk bintang ke-n memberi rating n.
class _StarPicker extends StatefulWidget {
  const _StarPicker({required this.onPicked});

  final ValueChanged<int> onPicked;

  @override
  State<_StarPicker> createState() => _StarPickerState();
}

class _StarPickerState extends State<_StarPicker> {
  int _value = 0;

  Future<void> _pick(int value) async {
    setState(() => _value = value);
    // Jeda singkat supaya bintang terisi sempat terlihat.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) widget.onPicked(value);
  }

  @override
  Widget build(BuildContext context) {
    // Bintang 39 dp berjarak 8 dp, memakai aset bintang yang sama dengan
    // komponen "Rating / Bintang" di desain. Di layar 320 dp kartu lebih
    // sempit dari 235 dp, jadi deretan bintang diperkecil utuh.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Semantics(
              button: true,
              label: 'Beri $i bintang',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: _value == 0 ? () => _pick(i) : null,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OrderIcon(
                    OrderStyle.iconStar,
                    size: 39,
                    color: i <= _value
                        ? AppColors.primary
                        : const Color(0xFFD9D9D9),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
