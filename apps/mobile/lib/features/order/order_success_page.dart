import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'order_style.dart';

/// Ringkasan pesanan yang baru dibuat, untuk halaman sukses.
class OrderSuccessInfo {
  const OrderSuccessInfo({
    required this.service,
    required this.message,
    required this.payment,
    required this.total,
  });

  /// Misal "Household - Rumah".
  final String service;

  /// Langkah berikutnya, misal "Agus menuju lokasimu, tiba ±30 menit lagi."
  final String message;

  /// Nama metode pembayaran.
  final String payment;
  final int total;
}

/// Konfirmasi pesanan berhasil dibuat: ringkasan, lalu "Lihat Pesanan"
/// (diganti halaman [orderPage]) atau "Kembali ke Beranda".
///
/// Tidak tertutup sendiri: pelanggan biasanya sedang membaca ringkasannya,
/// dan halaman yang hilang tiba-tiba terasa seperti error.
class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({
    super.key,
    required this.info,
    required this.orderPage,
  });

  final OrderSuccessInfo info;

  /// Halaman pesanan yang baru dibuat.
  final WidgetBuilder orderPage;

  /// Ilustrasi 1236 x 1509 px.
  static const _artRatio = 1509 / 1236;

  void _viewOrder(BuildContext context) => Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute<void>(builder: orderPage));

  void _home(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Jarak dan judul ikut tinggi layar (frame desain 917 dp).
    final k = (size.height / 917).clamp(0.7, 1.0);

    // HP pendek (±568–700 dp): judul sebaris dan tombol berdampingan, supaya
    // ilustrasi tetap kebagian ruang dan tidak mengecil berlebihan.
    final compact = size.height < 700;

    final viewButton = ElevatedButton(
      onPressed: () => _viewOrder(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.light,
        foregroundColor: AppColors.primary,
      ),
      child: const Text('Lihat Pesanan'),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(OrderStyle.successBackground, fit: BoxFit.cover),
            Positioned(
              left: -size.width * 0.08,
              bottom: -size.height * 0.02,
              width: size.width * 0.3,
              child: Image.asset(OrderStyle.successStar1),
            ),
            Positioned(
              right: -size.width * 0.08,
              bottom: size.height * 0.07,
              width: size.width * 0.26,
              child: Image.asset(OrderStyle.successStar2),
            ),
            Column(
              children: [
                const Expanded(child: _Art(ratio: _artRatio)),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 364),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        12 * k,
                        24,
                        (compact ? 16 : 8) + bottom,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              compact
                                  ? 'Pesanan Berhasil Dibuat'
                                  : 'Pesanan Berhasil\nDibuat',
                              textAlign: TextAlign.center,
                              style: AppTypography.style(
                                size: compact ? 24 : 32 * k,
                                weight: AppTypography.bold,
                                color: AppColors.light,
                                height: 1.3,
                              ),
                            ),
                          ),
                          SizedBox(height: 8 * k),
                          Text(
                            info.message,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              size: 13,
                              weight: AppTypography.medium,
                              color: AppColors.light,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 18 * k),
                          _SummaryCard(info: info),
                          SizedBox(height: 20 * k),
                          if (compact)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _home(context),
                                    // Isi merah, bukan garis putih: garis
                                    // putih hilang di atas hiasan bintang
                                    // putih di kiri bawah.
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.light,
                                      side: BorderSide.none,
                                      minimumSize: const Size(0, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Beranda'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(flex: 2, child: viewButton),
                              ],
                            )
                          else ...[
                            SizedBox(width: double.infinity, child: viewButton),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => _home(context),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.light,
                                textStyle: AppTypography.style(
                                  size: AppTypography.caption,
                                  weight: AppTypography.semiBold,
                                ),
                              ),
                              child: const Text('Kembali ke Beranda'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lingkaran ilustrasi yang separuh atasnya menyatu dengan latar putih,
/// mengisi ruang di atas ringkasan. Bagian atas lingkaran (polos) boleh
/// terpotong sedikit; kalau ruangnya masih kurang, ilustrasi mengecil.
class _Art extends StatelessWidget {
  const _Art({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final full = box.maxWidth * ratio;
        final scale = math.min(1.0, box.maxHeight / (full * 0.88));
        final artWidth = box.maxWidth * scale;
        final artHeight = full * scale;
        final artTop = box.maxHeight - artHeight;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: math.max(0.0, artTop + artHeight * 0.45),
              child: const ColoredBox(color: AppColors.light),
            ),
            Positioned(
              top: artTop,
              left: (box.maxWidth - artWidth) / 2,
              width: artWidth,
              height: artHeight,
              child: Image.asset(
                OrderStyle.successIllustration,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Kartu putih ringkasan: layanan, pembayaran, total.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.info});

  final OrderSuccessInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000), // hitam 12%
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _Row('Layanan', info.service),
          _Row('Pembayaran', info.payment),
          const Divider(height: 14),
          _Row('Total', rupiah(info.total, spaced: false), bold: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.style(
              size: 12,
              weight: bold ? AppTypography.semiBold : AppTypography.regular,
              color: bold ? AppColors.textPrimary : AppColors.textDescription,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                size: bold ? 14 : 12,
                weight: AppTypography.semiBold,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
