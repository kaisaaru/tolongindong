import 'package:flutter/painting.dart';

/// Aset dan warna alur pesanan. Ukuran diambil dari screenshot desain
/// (Android Compact, lebar 412 dp).
class OrderStyle {
  const OrderStyle._();

  /// Pusat tombol kembali, diukur dari tepi bawah status bar. Sama di semua
  /// halaman desain (Personal, Checkout, Vocher, Detail Pesanan, Household).
  static const backCenter = 33.0;
  static const backSize = 34.0;
  static const pageTitleSize = 24.0;

  /// Kartu putih besar (Vocher, Metode Pembayaran, Detail Pesanan, pesanan
  /// aktif): garis tepi tipis dan bayangan yang cukup terlihat di atas
  /// latar putih.
  static BoxDecoration card({double radius = 18}) => BoxDecoration(
    color: const Color(0xFFFFFFFF),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFEDEDED)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x29000000), // hitam 16%
        blurRadius: 10,
        offset: Offset(0, 3),
      ),
    ],
  );

  /// Latar pink pucat halaman daftar dan detail helper.
  static const background = Color(0xFFFFF5F4);

  /// Label keahlian di kartu: latar pink muda, teks merah.
  static const tagBackground = Color(0xFFFFE4E4);

  /// Label di bagian "Jasa" halaman detail: latar salem, teks putih.
  static const skillBackground = Color(0xFFFF7B7B);

  /// Kotak ikon voucher.
  static const voucherTile = Color(0xFFFF9999);

  static const shadow = Color(0x1A000000); // hitam 10%

  static const iconStar = 'assets/icons/ui/star.svg';
  static const iconHeart = 'assets/icons/ui/heart.svg';
  static const iconChat = 'assets/icons/ui/chat_text.svg';
  static const iconClipboard = 'assets/icons/ui/clipboard.svg';
  static const iconVoucher = 'assets/icons/ui/voucher.svg';
  static const iconVoucherWhite = 'assets/icons/ui/voucher_white.svg';
  static const iconPaymentCard = 'assets/icons/ui/payment_card.svg';

  // Ikon alamat membawa warnanya sendiri (merah, merah tua, biru).
  static const iconLocationPin = 'assets/icons/ui/location_pin.svg';

  /// Belah ketupat biru penanda lokasi awal Pindahan. Belum diekspor dari
  /// Figma; digambar ulang dari screenshot.
  static const iconLocationOrigin = 'assets/icons/ui/location_origin.svg';
  static const iconAddressHome = 'assets/icons/ui/address_home.svg';
  static const iconAddressOffice = 'assets/icons/ui/address_office.svg';
  static const iconAddressRecent = 'assets/icons/ui/address_recent.svg';

  /// Cincin merah bergradasi di latar Detail Pesanan, potongan dari Figma.
  static const ringLeft = 'assets/images/order/ring_left.svg';
  static const ringRight = 'assets/images/order/ring_right.svg';

  static const successIllustration =
      'assets/images/order/success_illustration.png';
  static const successBackground = 'assets/images/order/success_background.png';
  static const successStar1 = 'assets/images/order/success_star_1.png';
  static const successStar2 = 'assets/images/order/success_star_2.png';
}
