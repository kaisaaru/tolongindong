import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../household/household_models.dart';
import 'order_models.dart';
import 'order_style.dart';
import 'order_success_page.dart';
import 'payment_method_page.dart';
import 'voucher_page.dart';
import 'widgets/order_widgets.dart';

/// Ringkasan pesanan sebelum dibuat: voucher, metode pembayaran, rincian.
///
/// Belum mengirim apa pun ke backend. `POST /orders` belum menerima voucher,
/// metode pembayaran selain TD-Wallet belum ada,
/// dan alur direct booking di sana meminta quote helper dulu sebelum dana
/// ditahan — beda dengan desain yang harganya sudah tetap.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.helper});

  final HelperListing helper;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Voucher? _voucher;
  PaymentMethod? _payment;

  int get _price => widget.helper.price;
  int get _discount => _voucher?.discountFor(_price) ?? 0;
  int get _total => _price - _discount;

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

  void _submit() {
    if (_payment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih metode pembayaran dulu.')),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const OrderSuccessPage()),
      // Sisakan beranda di bawahnya supaya halaman sukses bisa kembali ke sana.
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final helper = widget.helper;
    final voucher = _voucher;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          bottom: false,
          // Jarak diukur dari desain: tiap bagian (judul + pilihan) 87 dp,
          // baris rincian berjarak 32 dp.
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SquareTitleBar(null, shadow: true),
              const SizedBox(height: 21),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _content(helper, voucher),
              ),
            ],
          ),
        ),
        bottomNavigationBar: OrderBottomBar(
          caption: 'Total',
          amount: rupiah(_total),
          button: PrimaryButton(label: 'Pesan Sekarang', onPressed: _submit),
        ),
      ),
    );
  }

  Widget _content(HelperListing helper, Voucher? voucher) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            HelperAvatar(
              name: helper.name,
              photoUrl: helper.photoUrl,
              size: 68,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    helper.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: 18,
                      weight: AppTypography.semiBold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: HelperStats(
                      rating: helper.rating,
                      completedCount: helper.completedCount,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 34),
        const Divider(height: 1),
        _OptionRow(
          title: 'Masukkan vocher',
          icon: OrderStyle.iconVoucher,
          value: voucher == null
              ? 'Gunakan Vocher'
              : '${voucher.title} · ${voucher.description}',
          onTap: _pickVoucher,
        ),
        const Divider(height: 1),
        _OptionRow(
          title: 'Metode Pembayaran',
          icon: OrderStyle.iconPaymentCard,
          value: _payment?.name ?? 'Pilih metode pembayaran',
          onTap: _pickPayment,
        ),
        const Divider(height: 1),
        const SizedBox(height: 21),
        Text(
          'Rincian Pembayaran',
          style: AppTypography.style(size: 14, weight: AppTypography.semiBold),
        ),
        const SizedBox(height: 26),
        _PriceRow(label: 'Jasa', value: rupiah(_price, spaced: false)),
        if (_discount > 0) ...[
          const SizedBox(height: 20),
          _PriceRow(
            label: 'Vocher',
            value: rupiah(-_discount, spaced: false),
            valueColor: AppColors.primary,
          ),
        ],
        const SizedBox(height: 20),
        _PriceRow(
          label: 'Total',
          value: rupiah(_total, spaced: false),
          bold: true,
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.style(
                      size: 14,
                      weight: AppTypography.semiBold,
                    ),
                  ),
                  const SizedBox(height: 19),
                  Row(
                    children: [
                      OrderIcon(icon, size: 14, color: AppColors.textPrimary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            size: 12,
                            weight: AppTypography.regular,
                          ),
                        ),
                      ),
                    ],
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

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final weight = bold ? AppTypography.semiBold : AppTypography.regular;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.style(size: 12, weight: weight),
          ),
        ),
        Text(
          value,
          style: AppTypography.style(
            size: 12,
            weight: weight,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
