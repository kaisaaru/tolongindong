import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../order/order_store.dart';
import '../order/order_style.dart';
import '../order/payment_method_page.dart';
import '../order/widgets/order_widgets.dart';
import 'household_models.dart';
import 'household_samples.dart';
import 'widgets/household_widgets.dart';

/// Tambah durasi pesanan yang sedang dikerjakan. Biaya tambahan dibayar
/// dengan metode pembayaran pesanan, kecuali diganti di sini.
///
/// Voucher tidak berlaku untuk tambahan durasi, jadi baris "Gunakan Vocher"
/// dari desain tidak dipasang (lihat catatan di ringkasan pekerjaan).
class ExtendDurationPage extends StatefulWidget {
  const ExtendDurationPage({super.key});

  @override
  State<ExtendDurationPage> createState() => _ExtendDurationPageState();
}

class _ExtendDurationPageState extends State<ExtendDurationPage> {
  late final _store = context.read<OrderStore>();
  int _hours = HouseholdSamples.durationOptions.first;
  late PaymentMethod? _payment = _store.active?.payment;

  int get _rate => _store.active?.draft.helper.hourlyRate ?? 0;
  int get _total => _rate * _hours;

  Future<void> _pickPayment() async {
    final picked = await Navigator.of(context).push<PaymentMethod>(
      MaterialPageRoute(builder: (_) => PaymentMethodPage(selected: _payment)),
    );
    if (picked != null && mounted) setState(() => _payment = picked);
  }

  void _submit() {
    // Saat waktu habis pun durasi masih boleh ditambah (dialog "Tambah").
    final status = _store.status;
    if (status != ActiveStatus.working && status != ActiveStatus.timeUp) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pesanan sudah selesai.')));
      Navigator.of(context).maybePop();
      return;
    }
    _store.addHours(_hours);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final service = _store.active?.draft.service ?? HouseholdService.rumah;

    return Scaffold(
      backgroundColor: AppColors.light,
      body: Column(
        children: [
          ColoredHeader.of(
            service,
            title: 'Tambah Durasi',
            trailing: SupportButton(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pusat bantuan belum tersedia.')),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
              children: [
                const SectionLabel('Tentukan Durasi'),
                const SizedBox(height: 12),
                DurationChips(
                  options: HouseholdSamples.durationOptions,
                  selected: _hours,
                  onSelected: (h) => setState(() => _hours = h),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Biaya tambahan'),
                const SizedBox(height: 10),
                OutlinedBox(
                  child: Column(
                    children: [
                      InfoRow(
                        'Biaya helper x $_hours jam',
                        rupiah(_total),
                        muted: true,
                      ),
                      InfoRow(
                        'Total',
                        rupiah(_total, spaced: false),
                        bold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Detail Pembayaran'),
                const SizedBox(height: 10),
                OutlinedBox(
                  onTap: _pickPayment,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const OrderIcon(
                        OrderStyle.iconPaymentCard,
                        size: 14,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _payment?.name ?? 'Pilih metode pembayaran',
                          style: AppTypography.style(
                            size: 11,
                            weight: AppTypography.regular,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: OrderBottomBar(
        caption: 'Total',
        amount: rupiah(_total),
        enabled: _payment != null,
        button: PrimaryButton(
          label: 'Tambah Durasi',
          onPressed: _payment == null ? null : _submit,
        ),
      ),
    );
  }
}
