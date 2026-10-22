import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../household/household_models.dart';
import '../household/order_review_page.dart';
import '../household/route_picker_page.dart';
import '../household/widgets/household_widgets.dart';
import '../order/order_models.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/order_success_page.dart';
import '../order/payment_method_page.dart';
import '../order/voucher_page.dart';
import '../order/widgets/order_widgets.dart';
import 'delivery_models.dart';
import 'delivery_page.dart' show deliveryItemColor, deliveryTimeColor;
import 'delivery_sheets.dart';
import 'recipient_form_page.dart';

/// "Detail Pesanan" Delivery: pengirim, penerima, waktu, barang, voucher,
/// metode pembayaran, lalu "Pesan" (konfirmasi → pembayaran → berhasil).
///
/// [DeliveryReviewPage.placed]: pesanan yang sudah dibuat, hanya dibaca
/// (dibuka dari Aktifitas). Desain pelacakan kurir belum ada, jadi
/// pelanggan sendiri yang menandai "Pesanan Diterima".
class DeliveryReviewPage extends StatefulWidget {
  const DeliveryReviewPage({
    super.key,
    required DeliveryDraft this.draft,
    this.voucher,
    this.store,
    this.clock,
  }) : order = null;

  const DeliveryReviewPage.placed({
    super.key,
    required DeliveryOrder this.order,
    this.store,
  }) : draft = null,
       voucher = null,
       clock = null;

  final DeliveryDraft? draft;
  final Voucher? voucher;
  final DeliveryOrder? order;

  /// Diisi saat pengujian. Default: [OrderStore.instance] dan jam nyata.
  final OrderStore? store;
  final DateTime Function()? clock;

  @override
  State<DeliveryReviewPage> createState() => _DeliveryReviewPageState();
}

class _DeliveryReviewPageState extends State<DeliveryReviewPage> {
  late final _store = widget.store ?? OrderStore.instance;
  late final _clock = widget.clock ?? DateTime.now;

  late DeliveryDraft _draft = widget.draft ?? widget.order!.draft;
  late Voucher? _voucher = widget.voucher ?? widget.order?.voucher;
  late PaymentMethod? _payment = widget.order?.payment;
  bool _expanded = false;

  bool get _readOnly => widget.order != null;

  /// Jam untuk "Diantar sebelum jam ...": saat dipesan, atau sekarang.
  DateTime get _orderedAt => widget.order?.placedAt ?? _clock();

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
    if (picked != null && mounted) {
      setState(
        () => _draft = _draft.copyWith(
          origin: picked.origin,
          destination: picked.destination,
        ),
      );
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

  Future<void> _pickVoucher() async {
    final picked = await Navigator.of(context).push<Voucher>(
      MaterialPageRoute(builder: (_) => VoucherPage(selected: _voucher)),
    );
    if (picked != null && mounted) setState(() => _voucher = picked);
  }

  Future<void> _pickPayment() async {
    final picked = await Navigator.of(context).push<PaymentMethod>(
      MaterialPageRoute(
        builder: (_) =>
            PaymentMethodPage(selected: _payment, allowCashOnDelivery: true),
      ),
    );
    if (picked != null && mounted) setState(() => _payment = picked);
  }

  /// Sama seperti Household: konfirmasi dulu, lalu metode pembayaran kalau
  /// belum dipilih.
  Future<void> _submit() async {
    final sure = await showConfirmOrderDialog(context);
    if (sure != true || !mounted) return;

    if (_payment == null) await _pickPayment();
    final payment = _payment;
    if (payment == null || !mounted) return;

    final draft = _draft;
    final order = _store.placeDelivery(
      draft: draft,
      payment: payment,
      voucher: _voucher,
    );
    // Jam yang sama dengan "Diantar sebelum jam ..." yang baru dilihat.
    final when = scheduleLabels(draft.schedule, _orderedAt).subtitle;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => OrderSuccessPage(
          info: OrderSuccessInfo(
            service: 'Delivery - ${draft.item.type.label}',
            message: 'Paket untuk ${draft.recipient.name}. $when.',
            payment: payment.name,
            total: order.total,
          ),
          orderPage: (_) =>
              DeliveryReviewPage.placed(order: order, store: _store),
        ),
      ),
      (route) => route.isFirst,
    );
  }

  /// Pesanan yang sudah dibuat: paket sudah sampai, pindahkan ke riwayat.
  Future<void> _markReceived() async {
    final order = widget.order;
    if (order == null) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paket sudah diterima?'),
        content: const Text(
          'Pesanan akan dipindah ke Riwayat dan tidak bisa diubah lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Belum'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sudah diterima'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    _store.completeDelivery(order);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengantaran selesai. Terima kasih!')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final discount = draft.discountWith(_voucher);
    final total = draft.fee - discount;
    final labels = scheduleLabels(draft.schedule, _orderedAt);
    final edit = !_readOnly;
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
                              if (!edit) ...[
                                OrderStatusBanner(
                                  icon: Icons.moped_outlined,
                                  title: 'Dalam pengantaran',
                                  subtitle: labels.subtitle,
                                ),
                                const SizedBox(height: 21),
                              ],
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
                                      onTap: edit ? _pickOrigin : null,
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
                                      onTap: edit ? _editRecipient : null,
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
                                onTap: edit ? _pickSchedule : null,
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
                                onTap: edit ? _pickItem : null,
                              ),
                              const SizedBox(height: 21),
                              const SectionLabel('Detail Pembayaran'),
                              const SizedBox(height: 14),
                              OrderOptionBox.icon(
                                OrderStyle.iconVoucher,
                                label:
                                    _voucher?.title ??
                                    (edit ? 'Gunakan Vocher' : 'Tanpa vocher'),
                                onTap: edit ? _pickVoucher : null,
                              ),
                              const SizedBox(height: 11),
                              OrderOptionBox.icon(
                                OrderStyle.iconPaymentCard,
                                label:
                                    _payment?.name ?? 'Pilih metode pembayaran',
                                onTap: edit ? _pickPayment : null,
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
                                total: total,
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
                                if (discount > 0)
                                  InfoRow(
                                    'Potongan vocher',
                                    rupiah(-discount),
                                    muted: true,
                                  ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 42,
                                child: edit
                                    ? PrimaryButton(
                                        label: 'Pesan',
                                        onPressed: _submit,
                                      )
                                    : PrimaryButton(
                                        label: 'Pesanan Diterima',
                                        onPressed: _markReceived,
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
