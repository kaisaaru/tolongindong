import 'dart:ui' show Color;

/// Aset dan warna alur pesanan. Ukuran diambil dari screenshot desain
/// (Android Compact, lebar 412 dp).
class OrderStyle {
  const OrderStyle._();

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

  static const successIllustration =
      'assets/images/order/success_illustration.png';
  static const successBackground = 'assets/images/order/success_background.png';
  static const successStar1 = 'assets/images/order/success_star_1.png';
  static const successStar2 = 'assets/images/order/success_star_2.png';
}
