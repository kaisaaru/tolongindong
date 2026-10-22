import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../household/household_models.dart';
import '../household/household_samples.dart';
import 'order_style.dart';
import 'widgets/order_widgets.dart';

/// Pilih metode pembayaran, dikelompokkan (Bayar di Tempat,) E-Wallet, dan
/// Bank. Mengetuk satu metode langsung kembali membawa metode itu.
///
/// Isinya contoh: backend baru punya TD-Wallet (saldo ditahan sebagai
/// escrow), belum ada payment gateway untuk e-wallet maupun bank.
class PaymentMethodPage extends StatelessWidget {
  const PaymentMethodPage({
    super.key,
    this.selected,
    this.methods,
    this.allowCashOnDelivery = false,
  });

  final PaymentMethod? selected;

  /// Diisi saat pengujian. Default: data contoh.
  final List<PaymentMethod>? methods;

  /// "Bayar di Tempat" hanya ada di desain Delivery (frame 114).
  final bool allowCashOnDelivery;

  @override
  Widget build(BuildContext context) {
    final all = methods ?? HouseholdSamples.paymentMethods;
    final groups = [
      for (final group in PaymentGroup.values)
        if (allowCashOnDelivery || group != PaymentGroup.cashOnDelivery) group,
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ArrowTitleBar('Metode Pembayaran'),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(23, 0, 23, 16),
                  padding: const EdgeInsets.fromLTRB(20, 19, 20, 16),
                  decoration: OrderStyle.card(),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final group in groups) ...[
                        if (group != groups.first) const SizedBox(height: 8),
                        Text(
                          group.label,
                          style: AppTypography.style(
                            size: 13,
                            weight: AppTypography.semiBold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final m in all)
                          if (m.group == group)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MethodTile(
                                method: m,
                                selected: m == selected,
                                onTap: () => Navigator.of(context).pop(m),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Logo diekspor selebar 44 (OVO 28 x 28); slot tetap supaya
                // nama metode sejajar.
                SizedBox(
                  width: 44,
                  height: 28,
                  child: switch (method.logo) {
                    final logo? => SvgPicture.asset(logo),
                    null => const Icon(
                      Icons.storefront_outlined,
                      size: 22,
                      color: AppColors.textDescription,
                    ),
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.name,
                        style: AppTypography.style(
                          size: 12,
                          weight: AppTypography.semiBold,
                          height: 1.4,
                        ),
                      ),
                      Text(
                        method.group.description,
                        style: AppTypography.style(
                          size: 8,
                          weight: AppTypography.regular,
                          color: AppColors.textDescription,
                        ),
                      ),
                    ],
                  ),
                ),
                // Radio di kanan, seperti frame 114.
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : null,
                    border: selected
                        ? null
                        : Border.all(color: AppColors.textDescription),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: AppColors.light,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
