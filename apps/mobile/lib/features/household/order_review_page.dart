import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../order/order_models.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/order_success_page.dart';
import '../order/payment_method_page.dart';
import '../order/voucher_page.dart';
import '../order/widgets/order_widgets.dart';
import 'active_order_page.dart';
import 'address_picker_page.dart';
import 'household_models.dart';
import 'route_picker_page.dart';
import 'widgets/household_widgets.dart';

/// "Detail Pesanan": ringkasan sebelum memesan, pilih voucher dan metode
/// pembayaran, lalu konfirmasi.
class OrderReviewPage extends StatefulWidget {
  const OrderReviewPage({super.key, required this.draft, this.store});

  final HouseholdOrderDraft draft;

  /// Diisi saat pengujian. Default: [OrderStore.instance].
  final OrderStore? store;

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  late final _store = widget.store ?? OrderStore.instance;

  late HouseholdOrderDraft _draft = widget.draft;
  Voucher? _voucher;
  PaymentMethod? _payment;
  bool _expanded = false;

  PriceBreakdown get _price => PriceBreakdown(
    hourlyRate: _draft.helper.hourlyRate,
    baseHours: _draft.hours,
    extraHours: const [],
    fees: _draft.fees,
    voucher: _voucher,
  );

  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => const AddressPickerPage()),
    );
    if (picked != null && mounted) {
      setState(() => _draft = _draft.copyWith(address: picked));
    }
  }

  Future<void> _pickRoute({required bool editOrigin}) async {
    final picked = await Navigator.of(context).push<MoveRoute>(
      MaterialPageRoute(
        builder: (_) => RoutePickerPage(
          origin: _draft.address,
          destination: _draft.destination,
          editOrigin: editOrigin,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(
        () => _draft = _draft.copyWith(
          address: picked.origin,
          destination: picked.destination,
        ),
      );
    }
  }

  Future<void> _pickVoucher() async {
    final picked = await Navigator.of(context).push<Voucher>(
      MaterialPageRoute(builder: (_) => VoucherPage(selected: _voucher)),
    );
    if (picked != null && mounted) setState(() => _voucher = picked);
  }

  Future<void> _pickPayment() async {
    final picked = await Navigator.of(context).push<PaymentMethod>(
      MaterialPageRoute(builder: (_) => PaymentMethodPage(selected: _payment)),
    );
    if (picked != null && mounted) setState(() => _payment = picked);
  }

  /// "Pesan": konfirmasi dulu (Frame 407), lalu metode pembayaran kalau
  /// belum dipilih, lalu "Pesanan Berhasil Dibuat" dan pesanan aktif.
  ///
  /// Desain (frame 185) menampilkan dialog konfirmasi walau metode
  /// pembayaran belum dipilih, jadi pemilihannya dipindah ke sesudah
  /// "Sudah".
  Future<void> _submit() async {
    if (_store.active != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Masih ada pesanan yang berjalan. Selesaikan dulu di Aktifitas.',
          ),
        ),
      );
      return;
    }

    final sure = await showConfirmOrderDialog(context);
    if (sure != true || !mounted) return;

    if (_payment == null) await _pickPayment();
    final payment = _payment;
    if (payment == null || !mounted) return;

    final draft = _draft;
    _store.place(draft: draft, payment: payment, voucher: _voucher);
    final helper = draft.helper.name;
    final slot = draft.slot;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => OrderSuccessPage(
          info: OrderSuccessInfo(
            service: 'Household - ${draft.service.label}',
            message: slot == null
                ? '$helper menuju lokasimu, tiba sekitar '
                      '${OrderStore.travelTime.inMinutes} menit lagi.'
                : '$helper datang ${dateLabel(slot.day)}, '
                      'pukul ${slot.hourLabel}.',
            payment: payment.name,
            total: _price.total,
          ),
          orderPage: (_) => ActiveOrderPage(store: _store),
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final price = _price;
    final voucher = _voucher;
    final cardSide = OrderStyle.inset(context, 40);
    final totalSide = OrderStyle.inset(context, 37);

    // Ukuran diukur dari desain (frame 412 dp): kartu 40 dp dari tepi layar,
    // isi kartu 22 dp dari tepi kartu, bagian Total 37 dp.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: RingBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ArrowTitleBar('Detail Pesanan'),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    // 40 dp dari tepi di desain; menyempit seimbang di HP
                    // yang lebih kecil supaya isi kartu tidak terjepit.
                    margin: EdgeInsets.fromLTRB(cardSide, 0, cardSide, 30),
                    decoration: OrderStyle.card(),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(22, 25, 22, 25),
                            children: [
                              const SectionLabel('Alamat'),
                              const SizedBox(height: 14),
                              ...orderAddressBoxes(
                                draft,
                                onTapOrigin: draft.isMove
                                    ? () => _pickRoute(editOrigin: true)
                                    : _pickAddress,
                                onTapDestination: () =>
                                    _pickRoute(editOrigin: false),
                              ),
                              const SizedBox(height: 23),
                              const SectionLabel('Detail Pengerjaan'),
                              const SizedBox(height: 14),
                              OutlinedBox(
                                padding: const EdgeInsets.fromLTRB(
                                  11,
                                  10,
                                  12,
                                  15,
                                ),
                                child: Column(children: workDetailRows(draft)),
                              ),
                              const SizedBox(height: 21),
                              const SectionLabel('Detail Pembayaran'),
                              const SizedBox(height: 14),
                              OrderOptionBox.icon(
                                OrderStyle.iconVoucher,
                                label: voucher?.title ?? 'Gunakan Vocher',
                                onTap: _pickVoucher,
                              ),
                              const SizedBox(height: 11),
                              OrderOptionBox.icon(
                                OrderStyle.iconPaymentCard,
                                label:
                                    _payment?.name ?? 'Pilih metode pembayaran',
                                onTap: _pickPayment,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            totalSide,
                            16,
                            totalSide,
                            27,
                          ),
                          child: Column(
                            children: [
                              TotalToggleRow(
                                total: price.total,
                                expanded: _expanded,
                                onTap: () =>
                                    setState(() => _expanded = !_expanded),
                              ),
                              if (_expanded) ...[
                                const SizedBox(height: 14),
                                InfoRow(
                                  'Biaya Helper',
                                  thousands(price.baseCost),
                                  muted: true,
                                ),
                                for (final fee in price.fees)
                                  InfoRow(
                                    fee.label,
                                    thousands(fee.amount),
                                    muted: true,
                                  ),
                                if (price.discount > 0)
                                  InfoRow(
                                    'Potongan vocher',
                                    thousands(-price.discount),
                                    muted: true,
                                  ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 42,
                                child: PrimaryButton(
                                  label: 'Pesan',
                                  onPressed: _submit,
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Kotak pilihan di Detail Pesanan (voucher, metode pembayaran, waktu antar,
/// jenis barang): ikon, judul, keterangan opsional, panah.
class OrderOptionBox extends StatelessWidget {
  const OrderOptionBox({
    super.key,
    required this.leading,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  /// Ikon SVG satu warna, seperti di Detail Pesanan Household.
  OrderOptionBox.icon(
    String asset, {
    Key? key,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
  }) : this(
         key: key,
         leading: OrderIcon(asset, size: 14, color: AppColors.textPrimary),
         label: label,
         subtitle: subtitle,
         onTap: onTap,
       );

  final Widget leading;
  final String label;
  final String? subtitle;

  /// Null: hanya dibaca, tanpa panah.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;

    // Kotak setinggi 41 dp, ikon di 11 dp, teks 12 dp di 49 dp dari tepi.
    return OutlinedBox(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(11, 11.5, 12, 11.5),
      child: Row(
        children: [
          SizedBox(width: 14, child: Center(child: leading)),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    size: 12,
                    weight: AppTypography.medium,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: 10,
                      weight: AppTypography.regular,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }
}

/// "Total  Rp 110.000 ⌄": mengetuknya membuka/menutup rincian harga.
class TotalToggleRow extends StatelessWidget {
  const TotalToggleRow({
    super.key,
    required this.total,
    required this.expanded,
    required this.onTap,
  });

  final int total;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: expanded ? 'Sembunyikan rincian' : 'Lihat rincian',
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Text(
              'Total',
              style: AppTypography.style(
                size: 14,
                weight: AppTypography.medium,
              ),
            ),
            const SizedBox(width: 12),
            // Total besar mengecil sendiri kalau tidak muat.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  rupiah(total, spaced: !expanded),
                  style: AppTypography.style(
                    size: 23,
                    weight: AppTypography.semiBold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Apakah kamu sudah yakin dengan pesananmu?" — true kalau "Sudah".
Future<bool?> showConfirmOrderDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.light,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Di Frame 407 ilustrasi selebar ±35% dialog.
            Image.asset(
              OrderStyle.confirmIllustration,
              width: 104,
              height: 104,
            ),
            const SizedBox(height: 16),
            Text(
              'Apakah kamu sudah yakin\ndengan pesananmu?',
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
                    label: 'Kembali',
                    color: const Color(0xFFFFC9C9),
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DialogButton(
                    label: 'Sudah',
                    color: AppColors.primary,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
