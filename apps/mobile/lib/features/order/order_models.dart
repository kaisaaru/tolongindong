/// Model alur pesanan Personal: daftar helper per kategori dan detailnya.
///
/// Backend belum punya detail helper (bio, review), sub-kategori, maupun
/// harga tetap per jasa — `GET /helpers` hanya memberi nama, foto, rating,
/// jumlah tugas selesai, dan tarif per jam.
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

  /// Satu helper dari `GET /helpers`. Backend belum punya bio, keahlian,
  /// sub-kategori, review, maupun harga per jasa: harga memakai tarif per
  /// jam, keahlian memakai kategori layanan helper.
  factory HelperListing.fromJson(Map<String, dynamic> json) => HelperListing(
    id: json['id'] as String,
    name: json['full_name'] as String? ?? 'Helper',
    photoUrl: json['photo_url'] as String?,
    rating: double.tryParse('${json['rating_average']}') ?? 0,
    reviewCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    completedCount: (json['completed_order_count'] as num?)?.toInt() ?? 0,
    price: (json['hourly_rate'] as num?)?.toInt() ?? 0,
    unit: 'jam',
    subcategory: '',
    tags: [
      for (final c in json['categories'] as List? ?? const [])
        (c as Map)['name'] as String? ?? '',
    ],
    about: '',
  );

  /// `helper_profiles.id`, dipakai sebagai `helper_id` pesanan dan untuk
  /// membuka chat.
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
