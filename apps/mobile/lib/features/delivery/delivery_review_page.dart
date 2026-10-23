import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../household/order_review_page.dart';
import '../household/route_picker_page.dart';
import '../household/widgets/household_widgets.dart';
import '../order/helper_repository.dart';
import '../order/order_detail_page.dart';
import '../order/order_repository.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/order_success_page.dart';
import '../order/widgets/order_widgets.dart';
import '../wallet/wallet_check.dart';
import 'delivery_models.dart';
import 'delivery_page.dart' show deliveryItemColor, deliveryTimeColor;
import 'delivery_sheets.dart';
import 'recipient_form_page.dart';

/// Isi form Delivery untuk `task_description`: backend belum punya kolom
/// untuk penerima, barang, maupun jadwal antar. Dibaca kembali di
/// [OrderDetailPage].
String deliveryOrderDescription(DeliveryDraft draft, DateTime orderedAt) {
  final recipient = draft.recipient;
  return OrderDescription.compose('Delivery - ${draft.item.type.label}', [
    ('Penerima', recipient.name),
    ('Kontak penerima', recipient.phone),
    ('Lantai/no. rumah', recipient.floor),
    ('Barang', draft.item.type.label),
    ('Ukuran', draft.item.summary),
    ('Waktu antar', scheduleLabels(draft.schedule, orderedAt).subtitle),
    ('Catatan pengemudi', recipient.note),
  ]);
}

/// "Detail Pesanan" Delivery: pengirim, penerima, waktu, barang, lalu
/// "Pesan" (konfirmasi → cek saldo TD-Wallet → berhasil).
///
/// Pesanan langsung ditujukan ke kurir terdekat (`booking_type` direct);
/// setelah dibuat, statusnya diikuti di [OrderDetailPage].
class DeliveryReviewPage extends StatefulWidget {
  const DeliveryReviewPage({
    super.key,
    required this.draft,
    required this.category,
    this.clock,
  });

  final DeliveryDraft draft;
  final ServiceCategory category;

  /// Diisi saat pengujian. Default: jam nyata.
  final DateTime Function()? clock;

  @override
  State<DeliveryReviewPage> createState() => _DeliveryReviewPageState();
}

class _DeliveryReviewPageState extends State<DeliveryReviewPage> {
  late final _store = context.read<OrderStore>();
  late final _clock = widget.clock ?? DateTime.now;

  late DeliveryDraft _draft = widget.draft;
  bool _expanded = false;
  bool _estimating = false;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    // Saldo di baris metode pembayaran.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => refreshWalletBalance(context),
    );
  }

  Future<void> _pickOrigin() async {
    final picked = await Navigator.of(context).push<MoveRoute>(
      MaterialPageRoute(
        builder: (_) => RoutePickerPage(
          origin: _draft.origin,
          destination: _draft.destination,
          editOrigin: true,
        ),
      ),
    );
    final origin = picked?.origin;
    final destination = picked?.destination;
    if (origin == null || destination == null || !mounted) return;

    // Ongkos kirim bergantung rute, jadi dihitung ulang.
    setState(() => _estimating = true);
    try {
      final fee = await context.read<OrderRepository>().estimate(
        categoryId: widget.category.id,
        pickupAddressId: origin.id,
        destinationAddressId: destination.id,
      );
      if (!mounted) return;
      setState(
        () => _draft = _draft.copyWith(
          origin: origin,
          destination: destination,
          fee: fee,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _editRecipient() async {
    final picked = await Navigator.of(context).push<Recipient>(
      MaterialPageRoute(
        builder: (_) => RecipientFormPage(
          address: _draft.destination,
          initial: _draft.recipient,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _draft = _draft.copyWith(recipient: picked));
    }
  }

  Future<void> _pickSchedule() async {
    final picked = await showDeliveryTimeSheet(
      context,
      initial: _draft.schedule,
      now: _clock(),
    );
    if (picked != null && mounted) {
      setState(() => _draft = _draft.copyWith(schedule: picked));
    }
  }

  Future<void> _pickItem() async {
    final picked = await showItemSheet(context, initial: _draft.item);
    if (picked != null && mounted) {
      setState(() => _draft = _draft.copyWith(item: picked));
    }
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit() async {
    final draft = _draft;
    final pickupId = draft.origin.id;
    final destinationId = draft.destination.id;
    if (pickupId == null || destinationId == null) {
      return _show('Pilih alamat tersimpan dulu.');
    }

    final sure = await showConfirmOrderDialog(context);
    if (sure != true || !mounted) return;
    if (!await ensureWalletBalance(context, draft.fee) || !mounted) return;

    setState(() => _placing = true);
    try {
      final couriers = await context.read<HelperRepository>().hourly(
        widget.category.id,
      );
      if (!mounted) return;
      if (couriers.isEmpty) {
        return _show('Belum ada kurir di sekitarmu. Coba lagi nanti.');
      }
      final courier = couriers.first;
      final orderedAt = _clock();
      final order = await _store.place(
        categoryId: widget.category.id,
        helperId: courier.id,
        description: deliveryOrderDescription(draft, orderedAt),
        price: draft.fee,
        pickupAddressId: pickupId,
        destinationAddressId: destinationId,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OrderSuccessPage(
            info: OrderSuccessInfo(
              service: 'Delivery - ${draft.item.type.label}',
              message:
                  'Menunggu ${courier.name} menerima paket untuk '
                  '${draft.recipient.name}.',
              payment: 'TD-Wallet',
              total: draft.fee,
            ),
            orderPage: (_) => OrderDetailPage(orderId: order.id),
          ),
        ),
        (route) => route.isFirst,
      );
    } on ApiException catch (e) {
      if (mounted) _show(e.message);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final labels = scheduleLabels(draft.schedule, _clock());
    final cardSide = OrderStyle.inset(context, 40);
    final totalSide = OrderStyle.inset(context, 37);

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
                              // Desain menulis "Pengataran" (salah ketik).
                              const SectionLabel('Detail Pengantaran'),
                              const SizedBox(height: 14),
                              OutlinedBox(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    _PartyRow(
                                      color: const Color(0xFF3FA2F6),
                                      title: 'Pengiriman',
                                      contact: draft.senderContact,
                                      address: draft.origin.fullAddress,
                                      onTap: _pickOrigin,
                                    ),
                                    _PartyRow(
                                      color: AppColors.primary,
                                      title: 'Penerima',
                                      contact:
                                          '${draft.recipient.name} - '
                                          '${draft.recipient.phone}',
                                      address: [
                                        ?draft.recipient.floor,
                                        draft.destination.fullAddress,
                                      ].join(', '),
                                      onTap: _editRecipient,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 21),
                              const SectionLabel('Pilihan Pengantaran'),
                              const SizedBox(height: 14),
                              OrderOptionBox(
                                leading: const Icon(
                                  Icons.moped_outlined,
                                  size: 18,
                                  color: deliveryTimeColor,
                                ),
                                label: labels.title,
                                subtitle: labels.subtitle,
                                onTap: _pickSchedule,
                              ),
                              const SizedBox(height: 11),
                              OrderOptionBox(
                                leading: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 16,
                                  color: deliveryItemColor,
                                ),
                                label: draft.item.type.label,
                                subtitle: draft.item.summary,
                                onTap: _pickItem,
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
                                subtitle: 'Saldo ditahan saat kurir menerima',
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
                                total: draft.fee,
                                expanded: _expanded,
                                onTap: () =>
                                    setState(() => _expanded = !_expanded),
                              ),
                              if (_expanded) ...[
                                const SizedBox(height: 14),
                                InfoRow(
                                  'Biaya Pengiriman',
                                  rupiah(draft.fee),
                                  muted: true,
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 42,
                                child: PrimaryButton(
                                  label: _estimating
                                      ? 'Menghitung ongkos...'
                                      : 'Pesan',
                                  isLoading: _placing,
                                  onPressed: _estimating ? null : _submit,
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

/// Pengirim atau penerima: belah ketupat berwarna, judul, kontak, alamat.
class _PartyRow extends StatelessWidget {
  const _PartyRow({
    required this.color,
    required this.title,
    required this.contact,
    required this.address,
    required this.onTap,
  });

  final Color color;
  final String title;
  final String contact;
  final String address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final detail = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      color: AppColors.textDescription,
      height: 1.5,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(width: 8, height: 8, color: color),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.style(
                      size: 11,
                      weight: AppTypography.medium,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(contact, style: detail),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: detail,
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
      ),
    );
  }
}
