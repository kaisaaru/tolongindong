import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../order/order_detail_page.dart';
import '../order/order_repository.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/order_success_page.dart';
import '../order/widgets/order_widgets.dart';
import '../wallet/wallet_check.dart';
import 'address_picker_page.dart';
import 'household_models.dart';
import 'route_picker_page.dart';
import 'widgets/household_widgets.dart';

/// Isi form Household untuk `task_description`: backend belum punya kolom
/// untuk ukuran, alat, jadwal, maupun durasi. Dibaca kembali di
/// [OrderDetailPage] (baris "Durasi" untuk hitung mundur).
String householdOrderDescription(HouseholdOrderDraft draft) {
  final price = PriceBreakdown(
    hourlyRate: draft.helper.hourlyRate,
    baseHours: draft.hours,
    fees: draft.fees,
  );
  return OrderDescription.compose('Household - ${draft.service.label}', [
    if (draft.load case final load?)
      ('Muatan', '${load.label} (${load.detail})'),
    if (draft.isMove) ('Kebutuhan armada', draft.fleet?.label),
    if (draft.widthM != null)
      (
        'Ukuran',
        'L: ${meterLabel(draft.widthM!)} m, '
            'P: ${meterLabel(draft.lengthM ?? 0)} m',
      ),
    if (!draft.isMove) ('Ketersediaan alat', draft.tools?.label),
    ('Waktu pengerjaan', draft.timeLabel),
    if (!draft.isMove) ('Durasi', '${draft.hours} Jam'),
    ('Tarif helper', '${rupiah(draft.helper.hourlyRate)}/jam'),
    ('Biaya helper', rupiah(price.baseCost)),
    for (final fee in price.fees) (fee.label, rupiah(fee.amount)),
    ('Catatan', draft.note),
  ]);
}

/// "Detail Pesanan": ringkasan sebelum memesan, lalu konfirmasi. Dibayar
/// dari TD-Wallet; voucher belum didukung `POST /orders`.
class OrderReviewPage extends StatefulWidget {
  const OrderReviewPage({
    super.key,
    required this.draft,
    required this.category,
  });

  final HouseholdOrderDraft draft;

  /// Kategori Household di server (`category_id`).
  final ServiceCategory category;

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  late final _store = context.read<OrderStore>();

  late HouseholdOrderDraft _draft = widget.draft;
  bool _expanded = false;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    // Saldo di baris metode pembayaran.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => refreshWalletBalance(context),
    );
  }

  PriceBreakdown get _price => PriceBreakdown(
    hourlyRate: _draft.helper.hourlyRate,
    baseHours: _draft.hours,
    fees: _draft.fees,
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

  /// "Pesan": konfirmasi dulu (Frame 407), cek saldo TD-Wallet, lalu
  /// `POST /orders` ke helper pilihan. Berhasil: "Pesanan Berhasil Dibuat",
  /// lalu detail pesanan.
  Future<void> _submit() async {
    final draft = _draft;
    final total = _price.total;
    final pickupId = draft.isMove ? draft.address.id : null;
    final destinationId = draft.isMove
        ? draft.destination?.id
        : draft.address.id;
    if (destinationId == null || (draft.isMove && pickupId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih alamat tersimpan dulu.')),
      );
      return;
    }

    final sure = await showConfirmOrderDialog(context);
    if (sure != true || !mounted) return;
    if (!await ensureWalletBalance(context, total) || !mounted) return;

    setState(() => _placing = true);
    try {
      final order = await _store.place(
        categoryId: widget.category.id,
        helperId: draft.helper.id,
        description: householdOrderDescription(draft),
        price: total,
        pickupAddressId: pickupId,
        destinationAddressId: destinationId,
      );
      if (!mounted) return;
      final slot = draft.slot;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OrderSuccessPage(
            info: OrderSuccessInfo(
              service: 'Household - ${draft.service.label}',
              message: slot == null
                  ? 'Menunggu ${draft.helper.name} menerima pesananmu.'
                  : 'Menunggu ${draft.helper.name} menerima pesanan untuk '
                        '${dateLabel(slot.day)}, pukul ${slot.hourLabel}.',
              payment: 'TD-Wallet',
              total: total,
            ),
            orderPage: (_) => OrderDetailPage(orderId: order.id),
          ),
        ),
        (route) => route.isFirst,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final price = _price;
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
                              // Voucher belum diterima `POST /orders`.
                              const OrderOptionBox(
                                leading: OrderIcon(
                                  OrderStyle.iconVoucher,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                label: 'Voucher belum bisa dipakai',
                                subtitle: 'Segera hadir',
                              ),
                              const SizedBox(height: 11),
                              OrderOptionBox.icon(
                                OrderStyle.iconPaymentCard,
                                label: walletPaymentLabel(context),
                                subtitle: 'Saldo ditahan saat helper menerima',
                                onTap: () => openWallet(context),
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
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 42,
                                child: PrimaryButton(
                                  label: 'Pesan',
                                  isLoading: _placing,
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
