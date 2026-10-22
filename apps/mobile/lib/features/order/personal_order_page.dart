import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../chat/chat_room_page.dart';
import '../chat/chat_store.dart';
import '../household/household_models.dart' show clockLabel;
import '../household/widgets/household_widgets.dart' show SupportButton;
import 'checkout_page.dart';
import 'order_store.dart';
import 'order_style.dart';
import 'widgets/helper_rating_view.dart';
import 'widgets/order_widgets.dart';

/// Pesanan Personal yang sedang dikerjakan (frame 202): status, helper,
/// voucher, metode pembayaran, dan rincian. Tugas dikirim dan diterima lewat
/// chat; "Selesai" saat tugas sudah diterima, lalu beri rating.
///
/// Voucher dan metode pembayaran hanya dibaca: sudah ditetapkan saat
/// checkout, jadi panah di desain tidak dipasang.
class PersonalOrderPage extends StatefulWidget {
  const PersonalOrderPage({super.key});

  @override
  State<PersonalOrderPage> createState() => _PersonalOrderPageState();
}

class _PersonalOrderPageState extends State<PersonalOrderPage> {
  late final _store = context.read<OrderStore>();

  /// True setelah "Selesai": tampilkan halaman rating.
  bool _rating = false;

  /// Ruang chat dengan helper; sudah dibuat saat checkout.
  void _chat(PersonalOrder order) {
    final chats = context.read<ChatStore>();
    final helper = order.helper;
    final room = chats.openWithHelper(
      helperId: helper.id,
      name: helper.name,
      photoUrl: helper.photoUrl,
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ChatRoomPage(room: room)));
  }

  void _rate(int stars) {
    _store.completePersonal(rating: stars);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terima kasih atas ratingnya!')),
    );
    _close();
  }

  /// Rating tidak wajib: pesanan tetap selesai dan masuk riwayat.
  void _skipRating() {
    _store.completePersonal();
    _close();
  }

  /// `pop`, bukan `maybePop`: PopScope di halaman rating menahan
  /// `maybePop` — penahan itu hanya untuk tombol kembali sistem.
  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final order = _store.personal;
    if (order == null) {
      // Pesanan sudah ditutup dari tempat lain.
      return const OrderEndedView();
    }

    final helper = order.helper;
    if (_rating) {
      // Tombol kembali membatalkan "Selesai" (misal salah ketuk) dan
      // kembali ke rincian pesanan, bukan menutup halaman.
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _rating = false);
        },
        child: HelperRatingView(
          name: helper.name,
          photoUrl: helper.photoUrl,
          onRate: _rate,
          onSkip: _skipRating,
        ),
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
                child: OrderStatusBanner(
                  icon: Icons.edit_note_rounded,
                  title: 'Sedang dikerjakan ${helper.name}',
                  subtitle:
                      'Dipesan pukul ${clockLabel(order.placedAt)}. '
                      'Kirim detail tugas lewat chat.',
                ),
              ),
              const SizedBox(height: 24),
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
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _chat(order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const OrderIcon(
                        OrderStyle.iconChat,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Chat Helper'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
