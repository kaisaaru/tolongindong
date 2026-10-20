import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import 'order_models.dart';
import 'order_style.dart';
import 'order_success_page.dart';
import 'voucher_page.dart';
import 'widgets/order_widgets.dart';

/// Ringkasan pesanan sebelum dibuat: voucher, metode pembayaran, rincian.
///
/// Belum mengirim apa pun ke backend. `POST /orders` belum menerima voucher,
/// dan alur direct booking di sana meminta quote helper dulu sebelum dana
/// ditahan — beda dengan desain yang harganya sudah tetap.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.helper});

  final HelperListing helper;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  /// Backend hanya punya TD-Wallet (saldo ditahan sebagai escrow).
  static const _paymentMethods = ['TD-Wallet'];

  Voucher? _voucher;
  String? _payment;

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
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.light,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Metode Pembayaran',
                style: AppTypography.style(
                  size: 15,
                  weight: AppTypography.semiBold,
                ),
              ),
            ),
            for (final method in _paymentMethods)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const OrderIcon(
                  OrderStyle.iconPaymentCard,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                title: Text(
                  method,
                  style: AppTypography.style(
                    size: AppTypography.small,
                    weight: AppTypography.medium,
                  ),
                ),
                trailing: method == _payment
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(method),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _ShadowBox(child: SquareIconButton.back(context, size: 32)),
              ),
              const SizedBox(height: 22),
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
                            size: 17,
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
              const SizedBox(height: 24),
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
                value: _payment ?? 'Pilih metode pembayaran',
                onTap: _pickPayment,
              ),
              const Divider(height: 1),
              const SizedBox(height: 18),
              Text(
                'Rincian Pembayaran',
                style: AppTypography.style(
                  size: 14,
                  weight: AppTypography.semiBold,
                ),
              ),
              const SizedBox(height: 18),
              _PriceRow(label: 'Jasa', value: rupiah(_price, spaced: false)),
              if (_discount > 0) ...[
                const SizedBox(height: 12),
                _PriceRow(
                  label: 'Vocher',
                  value: rupiah(-_discount, spaced: false),
                  valueColor: AppColors.primary,
                ),
              ],
              const SizedBox(height: 12),
              _PriceRow(
                label: 'Total',
                value: rupiah(_total, spaced: false),
                bold: true,
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
}

/// Tombol kembali di halaman putih diberi bayangan tipis supaya terlihat.
class _ShadowBox extends StatelessWidget {
  const _ShadowBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: OrderStyle.shadow, blurRadius: 6, offset: Offset(0, 1)),
        ],
      ),
      child: child,
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
        padding: const EdgeInsets.symmetric(vertical: 18),
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
                  const SizedBox(height: 14),
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
            style: AppTypography.style(size: 11, weight: weight),
          ),
        ),
        Text(
          value,
          style: AppTypography.style(size: 11, weight: weight, color: valueColor),
        ),
      ],
    );
  }
}
