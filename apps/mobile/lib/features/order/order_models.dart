/// Model alur pesanan: daftar helper per kategori, detail helper, voucher.
///
/// Semua masih diisi data contoh dari `order_samples.dart`. Backend belum
/// punya detail helper (bio, review), sub-kategori, maupun harga tetap per
/// jasa — `GET /helpers` hanya memberi nama, foto, rating, jumlah tugas
/// selesai, dan tarif per jam.
class HelperListing {
  const HelperListing({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.completedCount,
    required this.price,
    required this.subcategory,
    required this.tags,
    required this.about,
    this.unit,
    this.photoUrl,
    this.reviews = const [],
  });

  final String id;
  final String name;
  final String? photoUrl;

  final double rating;
  final int reviewCount;

  /// Jumlah tugas selesai (`completed_order_count` di backend).
  final int completedCount;

  /// Harga mulai, dalam rupiah.
  final int price;

  /// Satuan harga, misal "page". Null berarti harga per pesanan.
  final String? unit;

  /// Sub-kategori untuk filter chip, misal "Desain" atau "Tugas Kuliah".
  final String subcategory;

  /// Keahlian yang tampil sebagai label kecil di kartu dan bagian "Jasa".
  final List<String> tags;

  final String about;
  final List<HelperReview> reviews;
}

class HelperReview {
  const HelperReview({
    required this.author,
    required this.timeAgo,
    required this.rating,
    required this.text,
  });

  final String author;

  /// Sudah berupa teks relatif ("4h lalu"). Kalau nanti dari server,
  /// hitung dari `created_at`.
  final String timeAgo;
  final int rating;
  final String text;
}

/// Voucher persentase dengan batas potongan, sama seperti kolom
/// `discount_value` + `max_discount_amount` di tabel voucher backend.
class Voucher {
  const Voucher({
    required this.id,
    required this.title,
    required this.description,
    required this.validUntil,
    required this.percent,
    required this.maxDiscount,
  });

  final String id;
  final String title;
  final String description;

  /// Sudah diformat untuk tampilan, misal "07-11-2026".
  final String validUntil;

  final int percent;
  final int maxDiscount;

  /// Potongan untuk [price], tidak melebihi [maxDiscount] maupun harganya.
  int discountFor(int price) {
    final raw = price * percent ~/ 100;
    final capped = raw > maxDiscount ? maxDiscount : raw;
    return capped > price ? price : capped;
  }
}
