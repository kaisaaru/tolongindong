import 'order_models.dart';

/// Data contoh dari desain Figma, dipakai sampai backend punya endpoint
/// detail helper, sub-kategori, dan voucher etalase.
class OrderSamples {
  const OrderSamples._();

  /// Sub-kategori per `code` kategori. Baru Personal yang ada desainnya.
  static const subcategories = <String, List<String>>{
    'personal': ['Desain', 'Website', 'Tugas Kuliah', 'Skripsi'],
  };

  static const _aboutDesign =
      'Halo! Saya bantu desain UI/UX aplikasi dan website, dari wireframe '
      'sampai mockup siap pakai. Revisi jelas, file rapi, dan tepat waktu.';

  static const _aboutTask =
      'Halo! Saya siap bantu asistensi tugas Kalkulus, Matdis, dan Logmat. '
      'Pengerjaan terstruktur langkah demi langkah, tulisan rapi, dan selalu '
      'tepat waktu sebelum deadline.';

  static const _review = HelperReview(
    author: 'Jarwo',
    timeAgo: '4h lalu',
    rating: 5,
    text: 'Harganya terjangkau untuk mahasiswa, kerjanya teliti per nomor, '
        'dan nggak asal ngasih jawaban. Bakal repeat order lagi buat tugas '
        'minggu depan.',
  );

  static const _listings = <String, List<HelperListing>>{
    'personal': [
      HelperListing(
        id: 'sample-1',
        name: 'Agus Nomercy',
        rating: 5.0,
        reviewCount: 421,
        completedCount: 421,
        price: 30000,
        unit: 'page',
        subcategory: 'Desain',
        tags: ['UI/UX', 'Desain', 'Logo'],
        about: _aboutDesign,
        reviews: [_review, _review],
      ),
      HelperListing(
        id: 'sample-2',
        name: 'Agus Nomercy',
        rating: 5.0,
        reviewCount: 421,
        completedCount: 421,
        price: 30000,
        unit: 'page',
        subcategory: 'Website',
        tags: ['UI Website', 'UI Mobile', 'Website'],
        about: _aboutDesign,
        reviews: [_review, _review],
      ),
      HelperListing(
        id: 'sample-3',
        name: 'Reomeo Asgar',
        rating: 5.0,
        reviewCount: 421,
        completedCount: 421,
        price: 40000,
        subcategory: 'Tugas Kuliah',
        tags: ['Kalkulus', 'Matdis', 'Logmat'],
        about: _aboutTask,
        reviews: [_review, _review],
      ),
      HelperListing(
        id: 'sample-4',
        name: 'Reomeo Asgar',
        rating: 4.8,
        reviewCount: 210,
        completedCount: 198,
        price: 40000,
        subcategory: 'Tugas Kuliah',
        tags: ['Statistika', 'Fisika', 'Kimia'],
        about: _aboutTask,
        reviews: [_review],
      ),
    ],
  };

  static List<HelperListing> listingsFor(String categoryCode) =>
      _listings[categoryCode] ?? const [];

  static const vouchers = [
    Voucher(
      id: 'voucher-1',
      title: 'Diskon 20%',
      description: 'Diskon untuk pengguna baru',
      validUntil: '07-11-2026',
      percent: 20,
      maxDiscount: 2000,
    ),
    Voucher(
      id: 'voucher-2',
      title: 'Diskon 20%',
      description: 'Diskon untuk pengguna baru',
      validUntil: '07-12-2026',
      percent: 20,
      maxDiscount: 2000,
    ),
  ];
}
