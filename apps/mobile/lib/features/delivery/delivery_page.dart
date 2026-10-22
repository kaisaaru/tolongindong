import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../activity/activity_view.dart';
import '../household/household_models.dart';
import '../household/household_samples.dart';
import '../household/route_picker_page.dart';
import '../household/widgets/household_widgets.dart';
import '../order/order_models.dart';
import '../order/order_samples.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/voucher_page.dart';
import '../order/widgets/order_widgets.dart';
import 'delivery_models.dart';
import 'delivery_review_page.dart';
import 'delivery_samples.dart';
import 'delivery_sheets.dart';
import 'recipient_form_page.dart';

/// Warna ikon baris "Siapa penerimanya?" (biru), "Mau dianter kapan?"
/// (hijau), dan "Barang apa?" (oranye).
const deliveryRecipientColor = Color(0xFF3FA2F6);
const deliveryTimeColor = Color(0xFF1E9E4A);
const deliveryItemColor = Color(0xFFFF9F43);

/// Kategori Delivery. Sebelum tujuan dipilih: pengantaran sebelumnya dan
/// promo (frame 33). Sesudahnya: penerima, waktu, barang, voucher, dan total
/// (frame 42, 67–70). "Lihat Pesanan" aktif setelah semuanya terisi.
class DeliveryPage extends StatefulWidget {
  const DeliveryPage({
    super.key,
    required this.senderName,
    this.senderPhone,
    this.store,
    this.clock,
  });

  /// Pengirim = pengguna yang masuk.
  final String senderName;
  final String? senderPhone;

  /// Diisi saat pengujian. Default: [OrderStore.instance] dan jam nyata.
  final OrderStore? store;
  final DateTime Function()? clock;

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  late final _store = widget.store ?? OrderStore.instance;
  late final _clock = widget.clock ?? DateTime.now;

  SavedAddress _origin = HouseholdSamples.currentLocation;
  SavedAddress? _destination;
  Recipient? _recipient;
  DeliverySchedule? _schedule;
  DeliveryItem? _item;
  Voucher? _voucher;
  bool _expanded = false;

  static const _fee = DeliverySamples.fee;
  int get _discount => _voucher?.discountFor(_fee) ?? 0;

  DeliveryDraft? get _draft {
    final destination = _destination;
    final recipient = _recipient;
    final schedule = _schedule;
    final item = _item;
    if (destination == null ||
        recipient == null ||
        schedule == null ||
        item == null) {
      return null;
    }
    return DeliveryDraft(
      senderName: widget.senderName,
      senderPhone: widget.senderPhone,
      origin: _origin,
      destination: destination,
      recipient: recipient,
      schedule: schedule,
      item: item,
      fee: _fee,
    );
  }

  Future<void> _pickRoute({required bool editOrigin}) async {
    final picked = await Navigator.of(context).push<MoveRoute>(
      MaterialPageRoute(
        builder: (_) => RoutePickerPage(
          origin: _origin,
          destination: _destination,
          editOrigin: editOrigin,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _origin = picked.origin;
        _destination = picked.destination;
      });
    }
  }

  void _swap() {
    final destination = _destination;
    if (destination == null) return;
    setState(() {
      _destination = _origin;
      _origin = destination;
    });
  }

  Future<void> _editRecipient() async {
    final destination = _destination;
    if (destination == null) return;
    final picked = await Navigator.of(context).push<Recipient>(
      MaterialPageRoute(
        builder: (_) =>
            RecipientFormPage(address: destination, initial: _recipient),
      ),
    );
    if (picked != null && mounted) setState(() => _recipient = picked);
  }

  Future<void> _pickSchedule() async {
    final picked = await showDeliveryTimeSheet(
      context,
      initial: _schedule,
      now: _clock(),
    );
    if (picked != null && mounted) setState(() => _schedule = picked);
  }

  Future<void> _pickItem() async {
    final picked = await showItemSheet(context, initial: _item);
    if (picked != null && mounted) setState(() => _item = picked);
  }

  Future<void> _pickVoucher() async {
    final picked = await Navigator.of(context).push<Voucher>(
      MaterialPageRoute(builder: (_) => VoucherPage(selected: _voucher)),
    );
    if (picked != null && mounted) setState(() => _voucher = picked);
  }

  void _togglePromo(Voucher voucher) {
    final using = _voucher?.id == voucher.id;
    setState(() => _voucher = using ? null : voucher);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            using
                ? '${voucher.title} batal dipakai.'
                : '${voucher.title} dipakai untuk pengiriman ini.',
          ),
        ),
      );
  }

  void _openHistory() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            children: [
              const ArrowTitleBar('Riwayat'),
              Expanded(
                child: ActivityView(
                  store: _store,
                  startOnHistory: true,
                  showTitle: false,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// "Lihat Pesanan" saat form belum lengkap: beri tahu yang kurang dan
  /// langsung buka langkahnya. Tombolnya tetap abu-abu seperti desain,
  /// tapi tidak diam saja saat diketuk.
  void _completeMissing() {
    final String message;
    final Future<void> Function() open;
    if (_recipient == null) {
      message = 'Isi detail penerima dulu.';
      open = _editRecipient;
    } else if (_schedule == null) {
      message = 'Pilih kapan barang diantar dulu.';
      open = _pickSchedule;
    } else {
      message = 'Pilih barang yang dikirim dulu.';
      open = _pickItem;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    open();
  }

  void _review() {
    final draft = _draft;
    if (draft == null) return _completeMissing();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryReviewPage(
          draft: draft,
          voucher: _voucher,
          store: _store,
          clock: _clock,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final cardSide = _Metrics.cardSide(context);
    final hasDestination = _destination != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Header dan kartu rute ikut tergulir; kartu menumpuk di bagian
            // bawah header seperti desain.
            Stack(
              children: [
                _Header(
                  height: top + _Metrics.headerHeight,
                  onHistory: _openHistory,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    cardSide,
                    top + _Metrics.cardTop,
                    cardSide,
                    0,
                  ),
                  child: _RouteCard(
                    origin: _origin,
                    destination: _destination,
                    recipient: _recipient,
                    schedule: _schedule,
                    item: _item,
                    now: _clock(),
                    onOrigin: () => _pickRoute(editOrigin: true),
                    onDestination: () => _pickRoute(editOrigin: false),
                    onSwap: hasDestination ? _swap : null,
                    onRecipient: _editRecipient,
                    onSchedule: _pickSchedule,
                    onItem: _pickItem,
                  ),
                ),
              ],
            ),
            if (hasDestination)
              Padding(
                padding: EdgeInsets.fromLTRB(cardSide, 19, cardSide, 0),
                child: _VoucherCard(voucher: _voucher, onTap: _pickVoucher),
              )
            else ...[
              _Landing(
                now: _clock(),
                selectedVoucher: _voucher,
                onPastDelivery: (destination) =>
                    setState(() => _destination = destination),
                onPromo: _togglePromo,
              ),
            ],
          ],
        ),
        bottomNavigationBar: hasDestination
            ? _TotalCard(
                fee: _fee,
                discount: _discount,
                expanded: _expanded,
                enabled: _draft != null,
                onToggle: () => setState(() => _expanded = !_expanded),
                onReview: _review,
              )
            : null,
      ),
    );
  }
}

/// Ukuran diukur dari desain Delivery (frame Android Compact 412 dp, status
/// bar 52 dp). Jarak tepi diskalakan dengan lebar layar supaya proporsinya
/// sama di HP yang lebih sempit atau lebar.
class _Metrics {
  const _Metrics._();

  /// Tinggi header dan posisi atas kartu rute, di bawah status bar.
  static const headerHeight = 125.0;
  static const cardTop = 94.0;

  static const _designWidth = 412.0;

  /// Kartu rute, vocher, dan total: 54 dp dari tepi di desain.
  static double cardSide(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 54 / _designWidth;

  /// Pengantaran sebelumnya dan promo: 35 dp dari tepi di desain.
  static double sectionSide(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 35 / _designWidth;
}

/// Header merah bergradasi dengan sudut bawah membulat, tombol kembali,
/// judul, dan tombol riwayat.
class _Header extends StatelessWidget {
  const _Header({required this.height, required this.onHistory});

  final double height;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF9A9A), AppColors.primary],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          // Ilustrasi kardus di desain belum diekspor; ikon sementara di
          // posisi yang sama (tengah-kanan, ±110 dp) dengan garis gerak.
          Positioned(
            right: 64,
            top: top + 4,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final w in [16.0, 24.0, 16.0])
                      Container(
                        width: w,
                        height: 3,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.light.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 110,
                  color: AppColors.light.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
          Positioned(
            top: top + 33 - 17,
            left: 22,
            right: 22,
            height: 34,
            child: Row(
              children: [
                SquareIconButton.back(context, size: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Delivery',
                    style: AppTypography.style(
                      size: 24,
                      weight: AppTypography.semiBold,
                      color: AppColors.light,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Riwayat pengiriman',
                  excludeSemantics: true,
                  child: Material(
                    color: AppColors.light,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onHistory,
                      child: const SizedBox.square(
                        dimension: 34,
                        child: Icon(
                          Icons.history_rounded,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.origin,
    required this.destination,
    required this.recipient,
    required this.schedule,
    required this.item,
    required this.now,
    required this.onOrigin,
    required this.onDestination,
    required this.onSwap,
    required this.onRecipient,
    required this.onSchedule,
    required this.onItem,
  });

  final SavedAddress origin;
  final SavedAddress? destination;
  final Recipient? recipient;
  final DeliverySchedule? schedule;
  final DeliveryItem? item;
  final DateTime now;
  final VoidCallback onOrigin;
  final VoidCallback onDestination;
  final VoidCallback? onSwap;
  final VoidCallback onRecipient;
  final VoidCallback onSchedule;
  final VoidCallback onItem;

  @override
  Widget build(BuildContext context) {
    final destination = this.destination;
    final recipient = this.recipient;
    final schedule = this.schedule;
    final item = this.item;
    final labels = schedule == null ? null : scheduleLabels(schedule, now);

    // Ukuran dari desain: isi 21 dp dari tepi kartu, teks alamat 44 dp,
    // baris alamat ±47 dp, baris pilihan ±60 dp.
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 4, 8, 4),
      decoration: OrderStyle.card(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _LineButton(
                  onTap: onOrigin,
                  child: Row(
                    children: [
                      const OrderIcon(OrderStyle.iconLocationOrigin, size: 14),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          origin.fullAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            size: 11,
                            weight: AppTypography.medium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tukar asal dan tujuan',
                onPressed: onSwap,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.swap_vert_rounded, size: 20),
              ),
            ],
          ),
          const _RouteConnector(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _LineButton(
              onTap: onDestination,
              child: Row(
                children: [
                  const OrderIcon(OrderStyle.iconLocationPin, size: 14),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      destination?.label ?? 'Mau dianter kemana',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        size: 11,
                        weight: destination == null
                            ? AppTypography.regular
                            : AppTypography.medium,
                        color: destination == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (destination != null) ...[
            // Desain memakai tombol kecil "+ Detail" di samping alamat
            // tujuan; mudah terlewat, jadi penerima dibuat baris sendiri
            // seperti waktu dan barang (disetujui, beda dari desain).
            const Divider(height: 1, endIndent: 8, color: cardBorder),
            _ChoiceRow(
              icon: Icons.person_outline_rounded,
              iconColor: deliveryRecipientColor,
              title: recipient?.name ?? 'Siapa penerimanya?',
              subtitle: recipient == null
                  ? 'Isi nama dan nomor penerima'
                  : recipient.phone,
              onTap: onRecipient,
            ),
            const Divider(height: 1, endIndent: 8, color: cardBorder),
            _ChoiceRow(
              icon: Icons.moped_outlined,
              iconColor: deliveryTimeColor,
              title: labels?.title ?? 'Mau dianter kapan?',
              subtitle: labels == null
                  ? 'Pilih pengantaran disini'
                  : schedule!.isNow
                  ? 'Barang akan segera diambil'
                  : labels.subtitle,
              onTap: onSchedule,
            ),
            const Divider(height: 1, endIndent: 8, color: cardBorder),
            _ChoiceRow(
              icon: Icons.inventory_2_outlined,
              iconColor: deliveryItemColor,
              title: item?.type.label ?? 'Barang apa yang ingin dikirim?',
              subtitle: item?.summary ?? 'Pilih jenis barang disini',
              onTap: onItem,
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris alamat yang bisa diketuk. Bersama [_RouteConnector], dua
/// baris alamat berjarak ±47 dp seperti desain.
class _LineButton extends StatelessWidget {
  const _LineButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }
}

/// Di antara alamat asal dan tujuan: titik-titik di bawah ikon asal dan
/// garis putus-putus di bawah teks alamat.
class _RouteConnector extends StatelessWidget {
  const _RouteConnector();

  static const _color = Color(0xFFB9C9D9);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: OverflowBox(
              maxHeight: 22,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < 3; i++)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: _color,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 2.5),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 12),
              child: _DashedLine(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Garis putus-putus, mendatar atau tegak.
class _DashedLine extends StatelessWidget {
  const _DashedLine({this.axis = Axis.horizontal});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    return CustomPaint(
      size: horizontal
          ? const Size(double.infinity, 1)
          : const Size(1, double.infinity),
      painter: _DashPainter(horizontal: horizontal),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.horizontal});

  final bool horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cardBorder
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    final length = horizontal ? size.width : size.height;
    for (var p = 0.0; p < length; p += dash + gap) {
      final end = (p + dash).clamp(0.0, length);
      canvas.drawLine(
        horizontal ? Offset(p, 0) : Offset(0, p),
        horizontal ? Offset(end, 0) : Offset(0, end),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.horizontal != horizontal;
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 4, 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: 11,
                      weight: AppTypography.medium,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: 9,
                      weight: AppTypography.regular,
                      color: AppColors.textSecondary,
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
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher, required this.onTap});

  final Voucher? voucher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: OrderStyle.card(radius: 14),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Masukkan vocher'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const OrderIcon(
                      OrderStyle.iconVoucher,
                      size: 14,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        voucher?.title ?? 'Gunakan Vocher',
                        style: AppTypography.style(
                          size: 11,
                          weight: AppTypography.medium,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Isi sebelum tujuan dipilih: pengantaran sebelumnya dan promo.
class _Landing extends StatelessWidget {
  const _Landing({
    required this.now,
    required this.selectedVoucher,
    required this.onPastDelivery,
    required this.onPromo,
  });

  final DateTime now;
  final Voucher? selectedVoucher;
  final ValueChanged<SavedAddress> onPastDelivery;
  final ValueChanged<Voucher> onPromo;

  @override
  Widget build(BuildContext context) {
    const past = DeliverySamples.pastDeliveries;

    // Desain: judul 33 dp di bawah kartu rute, baris riwayat ±62 dp, kartu
    // promo ±87 dp berjarak 15 dp.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _Metrics.sectionSide(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 33),
          const SectionLabel('Pengantaran sebelumnya'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            decoration: OrderStyle.card(radius: 12),
            child: Column(
              children: [
                for (var i = 0; i < past.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 24,
                      endIndent: 24,
                      color: cardBorder,
                    ),
                  InkWell(
                    onTap: () => onPastDelivery(past[i].destination),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  past[i].destination.fullAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.style(
                                    size: 11,
                                    weight: AppTypography.medium,
                                    height: 1.4,
                                  ),
                                ),
                                Text(
                                  timeAgoLabel(
                                    now.subtract(
                                      Duration(days: past[i].daysAgo),
                                    ),
                                    now,
                                  ),
                                  style: AppTypography.style(
                                    size: 9,
                                    weight: AppTypography.regular,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),
          const SectionLabel('Promo pengiriman'),
          const SizedBox(height: 14),
          for (final voucher in OrderSamples.vouchers)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _PromoCard(
                voucher: voucher,
                selected: voucher.id == selectedVoucher?.id,
                onTap: () => onPromo(voucher),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.voucher,
    required this.selected,
    required this.onTap,
  });

  final Voucher voucher;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedFill : AppColors.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.primary : cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          // Seperti tiket: garis putus-putus tegak ±31 dp dari tepi kanan.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 13, 8, 13),
                    child: Row(
                      children: [
                        // Gambar promo di desain masih kotak abu-abu.
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D9D9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                voucher.title,
                                style: AppTypography.style(
                                  size: 13,
                                  weight: AppTypography.semiBold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selected ? 'Dipakai' : voucher.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.style(
                                  size: 9,
                                  weight: selected
                                      ? AppTypography.semiBold
                                      : AppTypography.regular,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: _DashedLine(axis: Axis.vertical),
                ),
                const SizedBox(width: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kotak bergaris di bawah: total (bisa dibuka rinciannya) dan tombol
/// "Lihat Pesanan". Pudar selama form belum lengkap.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.fee,
    required this.discount,
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.onReview,
  });

  final int fee;
  final int discount;
  final bool expanded;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final text = enabled ? AppColors.textPrimary : AppColors.disabled;

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          _Metrics.cardSide(context),
          8,
          _Metrics.cardSide(context),
          16,
        ),
        padding: const EdgeInsets.fromLTRB(26, 18, 26, 20),
        decoration: BoxDecoration(
          color: AppColors.light,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.textPrimary),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: expanded ? 'Sembunyikan rincian' : 'Lihat rincian',
              child: InkWell(
                onTap: onToggle,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: AppTypography.style(
                        size: 11,
                        weight: AppTypography.medium,
                        color: text,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Mengecil sendiri kalau tidak muat (layar sempit, font
                    // HP diperbesar).
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          rupiah(fee - discount),
                          style: AppTypography.style(
                            size: 20,
                            weight: AppTypography.semiBold,
                            color: text,
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: text,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              InfoRow('Biaya Pengiriman', rupiah(fee), muted: true),
              if (discount > 0)
                InfoRow('Potongan vocher', rupiah(-discount), muted: true),
            ],
            const SizedBox(height: 18),
            // Saat belum lengkap tombol tampil mati (desain), tapi ketukannya
            // tetap diteruskan ke [onReview] yang menunjukkan yang kurang.
            GestureDetector(
              onTap: enabled ? null : onReview,
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: PrimaryButton(
                  label: 'Lihat Pesanan',
                  onPressed: enabled ? onReview : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
