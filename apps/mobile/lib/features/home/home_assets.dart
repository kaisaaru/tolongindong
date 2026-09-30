import 'dart:ui' show Color;

/// Pemetaan aset beranda.
///
/// Ilustrasi kategori di `assets/icons/categories/` dipotong dari satu lembar
/// sprite ekspor Figma berisi enam ikon. Latar kotak-kotak "transparan" di
/// lembar itu ternyata piksel sungguhan, jadi saat dipotong latarnya dibuat
/// benar-benar transparan. Berkas sprite aslinya (~10 MB) sudah dihapus.
class HomeAssets {
  const HomeAssets._();

  /// Ilustrasi kategori, dikunci ke `code` dari backend — bukan ke nama
  /// tampilan, supaya tidak rusak kalau admin mengubah nama kategori.
  ///
  /// Laundry = mesin cuci, Household = keranjang berisi deterjen dan tisu.
  /// Label di Figma untuk dua ubin ini tertukar, jadi jangan dicocokkan ke
  /// label di desain.
  static const _categoryIcons = <String, String>{
    'food_run': 'assets/icons/categories/ic_food_run.png',
    'delivery': 'assets/icons/categories/ic_delivery.png',
    'moving': 'assets/icons/categories/ic_moving.png',
    'personal': 'assets/icons/categories/ic_personal.png',
    'household': 'assets/icons/categories/ic_household.png',
    'laundry': 'assets/icons/categories/ic_laundry.png',
  };

  /// Null berarti belum ada ilustrasinya — ubin menggambar penanda.
  static String? categoryIcon(String code) => _categoryIcons[code];

  /// Urutan tampil sesuai FR-HLP-001 (Household sebelum Laundry). Ditulis
  /// eksplisit supaya tidak bergantung pada urutan balasan server. Kode yang
  /// tidak dikenal ditaruh paling akhir.
  static const displayOrder = [
    'food_run',
    'delivery',
    'moving',
    'personal',
    'household',
    'laundry',
  ];

  static int orderOf(String code) {
    final index = displayOrder.indexOf(code);
    return index < 0 ? displayOrder.length : index;
  }

  /// Dua ubin terakhir bukan kategori layanan: "Helper" membuka pencarian
  /// helper, "Lainnya" membuka daftar kategori penuh.
  static const helperTile = 'assets/icons/categories/ic_helper.png';
  static const lainnyaTile = 'assets/icons/Group 71.svg';

  /// Warna latar kartu pada ilustrasi PNG. Dipakai juga untuk ubin "Lainnya"
  /// supaya delapan ubin tampak seragam.
  static const tileCardColor = Color(0xFFFEF7F8);

  static const promoBanner = 'assets/images/Rectangle 22522.png';

  /// Ikon bilah navigasi bawah. Tab "Cari Helper" dan lonceng notifikasi
  /// belum ada asetnya, jadi memakai ikon Material.
  static const navHome = 'assets/icons/Vector.svg';
  static const navChat = 'assets/icons/Group 119.svg';
  static const navProfile = 'assets/icons/Group 120.svg';
  static const navCreateOrder = 'assets/icons/Group 115.svg';
}
