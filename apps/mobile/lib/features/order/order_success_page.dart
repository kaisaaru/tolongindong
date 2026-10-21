import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'order_style.dart';

/// Konfirmasi pesanan berhasil dibuat. Kembali ke beranda otomatis setelah
/// [duration], atau lebih cepat kalau layar diketuk.
class OrderSuccessPage extends StatefulWidget {
  const OrderSuccessPage({super.key});

  static const duration = Duration(seconds: 3);

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(OrderSuccessPage.duration, _close);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    _timer.cancel();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;

              // Ilustrasi 1236 x 1509 px selebar layar, mulai 12% dari atas
              // (posisi di desain). Separuh atasnya menyatu dengan latar putih.
              final artTop = h * 0.12;
              final artHeight = w * 1509 / 1236;

              // Di layar pendek (360x640) atau font HP besar, judul bisa
              // melewati tepi bawah. Ruangnya dibatasi sampai atas bilah
              // sistem dan judul mengecil kalau tidak muat.
              final textTop = artTop + artHeight + h * 0.04;
              final textRoom = math.max(
                0.0,
                h - MediaQuery.paddingOf(context).bottom - 16 - textTop,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(OrderStyle.successBackground, fit: BoxFit.cover),
                  Positioned(
                    left: -w * 0.08,
                    bottom: -h * 0.02,
                    width: w * 0.3,
                    child: Image.asset(OrderStyle.successStar1),
                  ),
                  Positioned(
                    right: -w * 0.08,
                    bottom: h * 0.07,
                    width: w * 0.26,
                    child: Image.asset(OrderStyle.successStar2),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: artTop + artHeight * 0.45,
                    child: const ColoredBox(color: AppColors.light),
                  ),
                  Positioned(
                    top: artTop,
                    left: 0,
                    width: w,
                    height: artHeight,
                    child: Image.asset(
                      OrderStyle.successIllustration,
                      fit: BoxFit.fill,
                    ),
                  ),
                  Positioned(
                    top: textTop,
                    left: 24,
                    right: 24,
                    height: textRoom,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: Text(
                        'Pesanan Berhasil\nDibuat',
                        textAlign: TextAlign.center,
                        style: AppTypography.style(
                          size: 32,
                          weight: AppTypography.bold,
                          color: AppColors.light,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
