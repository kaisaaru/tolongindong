import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../models/auth_user.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../activity/activity_view.dart';
import '../address/address_repository.dart';
import '../auth/session_store.dart';
import '../household/household_models.dart';
import '../household/route_picker_page.dart';
import '../household/widgets/household_widgets.dart';
import '../order/order_repository.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/widgets/order_widgets.dart';
import 'delivery_models.dart';
import 'delivery_review_page.dart';
import 'delivery_sheets.dart';
import 'recipient_form_page.dart';

/// Warna ikon baris "Siapa penerimanya?" (biru), "Mau dianter kapan?"
/// (hijau), dan "Barang apa?" (oranye).
const deliveryRecipientColor = Color(0xFF3FA2F6);
const deliveryTimeColor = Color(0xFF1E9E4A);
const deliveryItemColor = Color(0xFFFF9F43);

/// Kategori Delivery. Sebelum tujuan dipilih: tujuan pengantaran
/// sebelumnya (frame 33). Sesudahnya: penerima, waktu, barang, dan total
/// (frame 42, 67–70). "Lihat Pesanan" aktif setelah semuanya terisi.
///
/// Asal dan tujuan adalah alamat tersimpan (pesanan memakai id alamat).
/// Ongkos dari `POST /orders/estimate`: tarif dasar + Rp2.500/km. Promo dan
/// voucher belum didukung `POST /orders`, jadi bagiannya disembunyikan.
class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key, required this.category, this.clock});

  /// Kategori Delivery di server (`category_id`).
  final ServiceCategory category;

  /// Diisi saat pengujian. Default: jam nyata.
  final DateTime Function()? clock;

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  late final _clock = widget.clock ?? DateTime.now;

  /// Awalnya alamat utama pengguna.
  SavedAddress? _origin;
  SavedAddress? _destination;
  Recipient? _recipient;
  DeliverySchedule? _schedule;
  DeliveryItem? _item;
  bool _expanded = false;

  /// Null selama belum dihitung (asal/tujuan belum lengkap, atau gagal).
  int? _fee;
  bool _estimating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrigin();
      // Tujuan pengantaran sebelumnya diambil dari daftar pesanan.
      context.read<OrderStore>().refresh(quiet: true);
    });
  }

  Future<void> _loadOrigin() async {
    try {
      final addresses = await context.read<AddressRepository>().list();
      if (!mounted || _origin != null) return;
      setState(() => _origin = addresses.firstOrNull);
      // Tujuan bisa sudah dipilih sebelum alamat asal selesai dimuat.
      if (_destination != null) await _estimateFee();
    } on ApiException {
      // Asal tetap bisa dipilih manual.
    }
  }

  /// Ongkos acuan untuk asal-tujuan ini.
  Future<void> _estimateFee() async {
    final pickup = _origin?.id;
    final destination = _destination?.id;
    if (pickup == null || destination == null) return;
    setState(() {
      _estimating = true;
      _fee = null;
    });
    try {
      final fee = await context.read<OrderRepository>().estimate(
        categoryId: widget.category.id,
        pickupAddressId: pickup,
        destinationAddressId: destination,
      );
      if (mounted) setState(() => _fee = fee);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  AuthUser? get _sender => context.read<SessionStore>().user;

  DeliveryDraft? get _draft {
    final origin = _origin;
    final destination = _destination;
    final recipient = _recipient;
    final schedule = _schedule;
    final item = _item;
    final fee = _fee;
    if (origin == null ||
        destination == null ||
        recipient == null ||
        schedule == null ||
        item == null ||
        fee == null) {
      return null;
    }
    return DeliveryDraft(
      // Pengirim = pengguna yang masuk.
      senderName: _sender?.fullName ?? '',
      senderPhone: _sender?.phoneNumber,
      origin: origin,
      destination: destination,
      recipient: recipient,
      schedule: schedule,
      item: item,
      fee: fee,
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
      await _estimateFee();
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

  Future<void> _pickPast(SavedAddress destination) async {
    setState(() => _destination = destination);
    await _estimateFee();
  }

  void _voucherSoon() => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Voucher belum bisa dipakai untuk pesanan.'),
      ),
    );

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

  void _openHistory() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            children: [
              const ArrowTitleBar('Riwayat'),
              Expanded(
                child: ActivityView(startOnHistory: true, showTitle: false),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// Tujuan pengantaran sebelumnya, terbaru di atas, tanpa duplikat.
  static List<({SavedAddress destination, DateTime at})> _pastDestinations(
    OrderStore store,
  ) {
    final seen = <int>{};
    return [
      for (final order in [...store.active, ...store.history])
        if (order.categoryCode == 'delivery')
          if (order.destination case final d? when seen.add(d.id ?? -1))
            (destination: d, at: order.createdAt),
    ].take(3).toList();
  }

  /// "Lihat Pesanan" saat form belum lengkap: beri tahu yang kurang dan
  /// langsung buka langkahnya. Tombolnya tetap abu-abu seperti desain,
  /// tapi tidak diam saja saat diketuk.
  void _completeMissing() {
    if (_origin == null) {
      _pickRoute(editOrigin: true);
      return;
    }
    if (_fee == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _estimating
                  ? 'Ongkos kirim sedang dihitung.'
                  : 'Ongkos kirim belum terhitung. Pilih ulang tujuannya.',
            ),
          ),
        );
      if (!_estimating) _estimateFee();
      return;
    }
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
          category: widget.category,
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
                child: _VoucherCard(onTap: _voucherSoon),
              )
            else
              ListenableBuilder(
                listenable: context.read<OrderStore>(),
                builder: (context, _) => _Landing(
                  now: _clock(),
                  past: _pastDestinations(context.read<OrderStore>()),
                  onPastDelivery: _pickPast,
                ),
              ),
          ],
        ),
        bottomNavigationBar: hasDestination
            ? _TotalCard(
                fee: _fee,
                estimating: _estimating,
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

  /// Pengantaran sebelumnya: 35 dp dari tepi di desain.
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

  final SavedAddress? origin;
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
                          origin?.fullAddress ?? 'Dijemput dari mana',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            size: 11,
                            weight: origin == null
                                ? AppTypography.regular
                                : AppTypography.medium,
                            color: origin == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
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

/// Garis putus-putus mendatar.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => const CustomPaint(
    size: Size(double.infinity, 1),
    painter: _DashPainter(),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cardBorder
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    for (var p = 0.0; p < size.width; p += dash + gap) {
      final end = (p + dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(p, 0), Offset(end, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
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
  const _VoucherCard({required this.onTap});

  /// Voucher belum diterima `POST /orders`: ketukannya memberi tahu.
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
                        'Voucher belum bisa dipakai',
                        style: AppTypography.style(
                          size: 11,
                          weight: AppTypography.medium,
                          color: AppColors.textSecondary,
                        ),
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
  }
}

/// Isi sebelum tujuan dipilih: pengantaran sebelumnya dan promo.
/// Isi sebelum tujuan dipilih: tujuan pengantaran sebelumnya.
class _Landing extends StatelessWidget {
  const _Landing({
    required this.now,
    required this.past,
    required this.onPastDelivery,
  });

  final DateTime now;

  /// Tujuan pengantaran sebelumnya dari pesanan Delivery pengguna.
  final List<({SavedAddress destination, DateTime at})> past;
  final ValueChanged<SavedAddress> onPastDelivery;

  @override
  Widget build(BuildContext context) {
    if (past.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          _Metrics.sectionSide(context),
          33,
          _Metrics.sectionSide(context),
          0,
        ),
        child: Text(
          'Pilih alamat tujuan untuk mulai mengirim barang.',
          textAlign: TextAlign.center,
          style: AppTypography.style(
            size: AppTypography.small,
            weight: AppTypography.regular,
            color: AppColors.textDescription,
          ),
        ),
      );
    }

    // Desain: judul 33 dp di bawah kartu rute, baris riwayat ±62 dp.
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
                                  timeAgoLabel(past[i].at, now),
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
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.fee,
    required this.estimating,
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.onReview,
  });

  /// Null selama belum terhitung.
  final int? fee;
  final bool estimating;
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
                          fee == null
                              ? (estimating ? 'Menghitung...' : 'Rp -')
                              : rupiah(fee!),
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
              InfoRow(
                'Biaya Pengiriman',
                fee == null ? '-' : rupiah(fee!),
                muted: true,
              ),
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
