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

/// Warna ikon baris "Mau dianter kapan?" (hijau) dan "Barang apa?" (oranye).
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
    final (message, open) = switch (null) {
      _ when _recipient == null => (
        'Isi detail penerima dulu.',
        _editRecipient,
      ),
      _ when _schedule == null => (
        'Pilih kapan barang diantar dulu.',
        _pickSchedule,
      ),
      _ => ('Pilih barang yang dikirim dulu.', _pickItem),
    };
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
                _Header(height: top + 150, onHistory: _openHistory),
                Padding(
                  padding: EdgeInsets.fromLTRB(36, top + 100, 36, 0),
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
            const SizedBox(height: 18),
            if (hasDestination)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Ilustrasi kardus di desain belum diekspor; ikon sementara,
          // lebih pudar supaya tidak bersaing dengan tombol riwayat.
          Positioned(
            right: 76,
            top: top + 18,
            child: Icon(
              Icons.inventory_2_outlined,
              size: 72,
              color: AppColors.light.withValues(alpha: 0.25),
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
                Material(
                  color: AppColors.light,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Riwayat pengiriman',
                    onPressed: onHistory,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
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

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
      decoration: OrderStyle.card(radius: 14),
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
                      const SizedBox(width: 14),
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
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Divider(height: 1, indent: 28, color: cardBorder),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _LineButton(
              onTap: onDestination,
              child: Row(
                children: [
                  const OrderIcon(OrderStyle.iconLocationPin, size: 14),
                  const SizedBox(width: 14),
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
                  if (destination != null && recipient == null)
                    _DetailPill(onTap: onRecipient),
                ],
              ),
            ),
          ),
          if (recipient != null)
            GestureDetector(
              onTap: onRecipient,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 8, 8),
                child: Text(
                  recipient.contact,
                  style: AppTypography.style(
                    size: 9,
                    weight: AppTypography.regular,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          if (destination != null) ...[
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

/// Satu baris yang bisa diketuk, setinggi minimal 44 dp.
class _LineButton extends StatelessWidget {
  const _LineButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            '+ Detail',
            style: AppTypography.style(
              size: 10,
              weight: AppTypography.medium,
              color: AppColors.light,
            ),
          ),
        ),
      ),
    );
  }
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
        padding: const EdgeInsets.fromLTRB(0, 12, 4, 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const SectionLabel('Pengantaran sebelumnya'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: OrderStyle.card(radius: 14),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
          const SizedBox(height: 26),
          const SectionLabel('Promo pengiriman'),
          const SizedBox(height: 12),
          for (final voucher in OrderSamples.vouchers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Gambar promo di desain masih kotak abu-abu.
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.title,
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.semiBold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        voucher.description,
                        style: AppTypography.style(
                          size: 9,
                          weight: AppTypography.regular,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Text(
                    'Dipakai',
                    style: AppTypography.style(
                      size: 10,
                      weight: AppTypography.semiBold,
                      color: AppColors.primary,
                    ),
                  ),
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
        margin: const EdgeInsets.fromLTRB(36, 8, 36, 16),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
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
