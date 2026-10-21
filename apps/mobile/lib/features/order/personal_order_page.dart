import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../household/widgets/household_widgets.dart' show SupportButton;
import 'checkout_page.dart';
import 'order_store.dart';
import 'order_style.dart';
import 'widgets/helper_rating_view.dart';
import 'widgets/order_widgets.dart';

/// Pesanan Personal yang sedang dikerjakan (frame 202): helper, voucher,
/// metode pembayaran, dan rincian. "Selesai" saat tugas sudah diterima,
/// lalu beri rating; pesanan baru masuk riwayat setelah rating.
///
/// Voucher dan metode pembayaran hanya dibaca: sudah ditetapkan saat
/// checkout, jadi panah di desain tidak dipasang.
class PersonalOrderPage extends StatefulWidget {
  const PersonalOrderPage({super.key, this.store});

  /// Diisi saat pengujian. Default: [OrderStore.instance].
  final OrderStore? store;

  @override
  State<PersonalOrderPage> createState() => _PersonalOrderPageState();
}

class _PersonalOrderPageState extends State<PersonalOrderPage> {
  late final _store = widget.store ?? OrderStore.instance;

  /// True setelah "Selesai": tampilkan halaman rating.
  bool _rating = false;

  void _rate(int stars) {
    _store.completePersonal(rating: stars);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terima kasih atas ratingnya!')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final order = _store.personal;
    if (order == null) {
      // Pesanan sudah ditutup dari tempat lain.
      return const Scaffold(body: SizedBox.shrink());
    }

    final helper = order.helper;
    if (_rating) {
      return HelperRatingView(
        name: helper.name,
        photoUrl: helper.photoUrl,
        onRate: _rate,
      );
    }

    final voucher = order.voucher;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SquareTitleBar(
                null,
                shadow: true,
                trailing: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: OrderStyle.shadow,
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SupportButton(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pusat bantuan belum tersedia.'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 21),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: PersonalOrderSummary(
                  helper: helper,
                  // Desain: "Diskon Rp 2.000" — besar potongannya.
                  voucherLabel: voucher == null
                      ? 'Tanpa vocher'
                      : 'Diskon ${rupiah(order.discount)}',
                  paymentLabel: order.payment.name,
                  price: order.price,
                  discount: order.discount,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.light,
            border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 22, 18),
              // Row, bukan Align: Align di bottomNavigationBar melebar
              // setinggi layar dan menutupi isi halaman.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 160,
                    child: PrimaryButton(
                      label: 'Selesai',
                      onPressed: () => setState(() => _rating = true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
