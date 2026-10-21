import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'order_models.dart';
import 'order_samples.dart';
import 'order_style.dart';
import 'widgets/order_widgets.dart';

/// Pilih voucher. Mengetuk satu voucher langsung kembali ke checkout
/// membawa voucher itu.
///
/// Isinya contoh. `GET /vouchers` sudah ada (voucher yang sudah diklaim
/// user), tapi `POST /orders` belum menerima voucher.
class VoucherPage extends StatelessWidget {
  const VoucherPage({super.key, this.selected, this.vouchers});

  final Voucher? selected;

  /// Diisi saat pengujian. Default: data contoh.
  final List<Voucher>? vouchers;

  @override
  Widget build(BuildContext context) {
    final items = vouchers ?? OrderSamples.vouchers;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ArrowTitleBar('Vocher'),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(23, 0, 23, 16),
                  padding: const EdgeInsets.fromLTRB(24, 19, 24, 0),
                  decoration: OrderStyle.card(),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Text(
                        'Vocher Ongkir',
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.semiBold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (items.isEmpty)
                        Text(
                          'Belum ada voucher.',
                          style: AppTypography.style(
                            size: AppTypography.small,
                            weight: AppTypography.regular,
                            color: AppColors.textDescription,
                          ),
                        ),
                      for (final voucher in items) ...[
                        _VoucherTile(
                          voucher: voucher,
                          selected: voucher.id == selected?.id,
                          onTap: () => Navigator.of(context).pop(voucher),
                        ),
                        const SizedBox(height: 10),
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

class _VoucherTile extends StatelessWidget {
  const _VoucherTile({
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: OrderStyle.voucherTile,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: const OrderIcon(OrderStyle.iconVoucherWhite, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.title,
                      style: AppTypography.style(
                        size: 13,
                        weight: AppTypography.semiBold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      voucher.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sampai ${voucher.validUntil}',
                      style: AppTypography.style(
                        size: 8,
                        weight: AppTypography.regular,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Garis putus-putus pemisah seperti sobekan tiket.
              const _DashedDivider(),
              SizedBox(
                width: 28,
                child: Center(child: _Radio(selected: selected)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  /// Terpilih: lingkaran merah penuh dengan centang putih (Frame 410).
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : null,
        border: selected ? null : Border.all(color: AppColors.textDescription),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 12, color: AppColors.light)
          : null,
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(1, double.infinity),
      painter: _DashPainter(),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    for (var y = 0.0; y < size.height; y += dash + gap) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}
