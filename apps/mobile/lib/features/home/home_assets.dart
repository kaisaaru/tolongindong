import 'dart:ui' show Color;

/// Pemetaan aset beranda.
///
/// Ilustrasi kategori di `assets/icons/categories/` dipotong dari satu lembar
/// sprite ekspor Figma. Latar kotak-kotak "transparan" di lembar itu ternyata
/// piksel sungguhan, jadi saat dipotong latarnya dibuat benar-benar
/// transparan. Berkas sprite aslinya (~10 MB) sudah dihapus.
class HomeAssets {
  const HomeAssets._();

  /// Ilustrasi kategori, dikunci ke `code` dari backend — bukan ke nama
  /// tampilan, supaya tidak rusak kalau admin mengubah nama kategori.
  ///
  /// Backend tinggal punya tiga kategori: delivery, personal, household.
  /// Household = mesin cuci, mengikuti Figma.
  static const _categoryIcons = <String, String>{
    'delivery': 'assets/icons/categories/delivery.png',
    'personal': 'assets/icons/categories/personal.png',
    'household': 'assets/icons/categories/household.png',
  };

  /// Null berarti belum ada ilustrasinya — ubin menggambar penanda.
  static String? categoryIcon(String code) => _categoryIcons[code];

  /// Urutan tampil mengikuti Figma, yang berbeda dari urutan id di backend.
  /// Kode yang tidak dikenal ditaruh paling akhir.
  static const displayOrder = ['personal', 'delivery', 'household'];

  static int orderOf(String code) {
    final index = displayOrder.indexOf(code);
    return index < 0 ? displayOrder.length : index;
  }

  /// Ubin terakhir bukan kategori layanan: "Helper" membuka pencarian helper.
  static const helperTile = 'assets/icons/categories/helper.png';

  /// Warna latar kartu pada ilustrasi PNG, dipakai juga untuk ubin yang
  /// belum punya ilustrasi supaya semua ubin tampak seragam.
  static const tileCardColor = Color(0xFFFEF7F8);

  /// Banner utuh hasil ekspor Figma, termasuk teks dan tombol
  /// "Lihat Voucher" — jadi seluruh banner yang bisa diketuk.
  static const promoVoucher = 'assets/images/promo/promo_voucher.png';

  /// Ikon bilah navigasi bawah, ekspor Figma. Garisnya hitam (Beranda merah)
  /// dan diwarnai ulang sesuai keadaan tab; isi putihnya dibiarkan.
  static const navHome = 'assets/icons/nav/home.svg';
  static const navActivity = 'assets/icons/nav/activity.svg';
  static const navChat = 'assets/icons/nav/chat.svg';
  static const navProfile = 'assets/icons/nav/profile.svg';
}
