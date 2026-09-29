import 'dart:ui' show Color;

/// Pemetaan aset beranda.
///
/// Ilustrasi kategori aslinya satu lembar sprite 1536x1024 berisi enam ikon
/// (`Group 56.svg`, `Group 56-1.svg`, `Rectangle 22518.svg`,
/// `Rectangle 22518-1.svg`, dan `Rectangle 22520.svg` semuanya memuat lembar
/// yang sama, masing-masing ~1,5 MB). Latar kotak-kotak "transparan" di lembar
/// itu ternyata piksel sungguhan, jadi kartu-kartunya sudah dipotong ulang ke
/// `assets/icons/categories/` dengan latar yang benar-benar transparan.
class HomeAssets {
  const HomeAssets._();

  /// Ilustrasi kategori, dikunci ke `code` dari backend — bukan ke nama
  /// tampilan, supaya tidak rusak kalau admin mengubah nama kategori.
  ///
  /// Catatan: di desain, **Laundry** memakai keranjang dan **Household**
  /// memakai mesin cuci. Pemetaan ini mengikuti desain.
  static const _categoryIcons = <String, String>{
    'food_run': 'assets/icons/categories/ic_food_run.png',
    'delivery': 'assets/icons/categories/ic_delivery.png',
    'moving': 'assets/icons/categories/ic_moving.png',
    'personal': 'assets/icons/categories/ic_personal.png',
    'laundry': 'assets/icons/categories/ic_laundry.png',
    'household': 'assets/icons/categories/ic_household.png',
  };

  /// Null berarti belum ada ilustrasinya — ubin menggambar penanda.
  static String? categoryIcon(String code) => _categoryIcons[code];

  /// Urutan tampil mengikuti desain (Laundry sebelum Household), yang berbeda
  /// dari urutan id di backend. Kode yang tidak dikenal ditaruh paling akhir.
  static const displayOrder = [
    'food_run',
    'delivery',
    'moving',
    'personal',
    'laundry',
    'household',
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
