import 'household_models.dart';

/// Data contoh dari desain Figma untuk alur Household.
///
/// Yang sudah ada padanannya di backend: alamat tersimpan (`GET /addresses`)
/// dan helper per jam (`GET /helpers?category_id=&sort_by=distance`).
/// Riwayat alamat, metode pembayaran selain TD-Wallet, dan field form
/// (ukuran, alat, durasi) belum ada.
class HouseholdSamples {
  const HouseholdSamples._();

  /// Pengganti lokasi GPS. App belum memakai paket lokasi, jadi "Lokasi saat
  /// ini" di pemilih rute Pindahan masih alamat contoh.
  static const currentLocation = SavedAddress(
    label: 'Lokasi saat ini',
    fullAddress:
        'Jl. Salendro Tim. 1 No.5A, Gumuruh, Kec. Batununggal, '
        'Kota Bandung, Jawa Barat',
    kind: AddressKind.current,
  );

  static const recentAddresses = [
    SavedAddress(
      label: 'Komplek Salendro Timur',
      fullAddress:
          'Jl. Salendro Tim. I No.5A, Gumuruh, Kec. Batununggal, '
          'Kota Bandung, Jawa Barat 40265',
      kind: AddressKind.recent,
    ),
    SavedAddress(
      label: 'KOST BUMISAKA',
      fullAddress:
          'Jl. Ciburuy No.147, Ciseureuh, Kec. Regol, Kota Bandung, '
          'Jawa Barat 40255',
      kind: AddressKind.recent,
    ),
    SavedAddress(
      label: 'Ufamily Kost Baleendah',
      fullAddress:
          'Jl. Anggadirejo No.161, Baleendah, Kec. Baleendah, '
          'Kabupaten Bandung, Jawa Barat 40375',
      kind: AddressKind.recent,
    ),
  ];

  static const savedAddresses = [
    SavedAddress(
      label: 'Rumah',
      fullAddress:
          'Jl. Sukaati V No.19, Pasirluyu, Kec. Regol, Kota Bandung, '
          'Jawa Barat 40254',
      kind: AddressKind.home,
    ),
    SavedAddress(
      label: 'KOST BUMISAKA',
      fullAddress:
          'Jl. Ciburuy No.147, Ciseureuh, Kec. Regol, Kota Bandung, '
          'Jawa Barat 40255',
      kind: AddressKind.home,
    ),
    SavedAddress(
      label: 'PT AMERTA INDAH OTSUKA',
      fullAddress:
          'Pondok Indah Office Tower I Lantai 6 Jl. Sultan Iskandar '
          'Muda Kav. V-TA, RT.1/RW.16',
      kind: AddressKind.office,
    ),
  ];

  static const helpers = [
    HourlyHelper(
      id: 'h-1',
      name: 'Agus Nomercy',
      rating: 5.0,
      reviewCount: 421,
      completedCount: 1240,
      hourlyRate: 40000,
      distanceKm: 1,
    ),
    HourlyHelper(
      id: 'h-2',
      name: 'Agus Nomercy',
      rating: 5.0,
      reviewCount: 421,
      completedCount: 620,
      hourlyRate: 30000,
      distanceKm: 4,
    ),
    HourlyHelper(
      id: 'h-3',
      name: 'Agus Nomercy',
      rating: 4.6,
      reviewCount: 421,
      completedCount: 480,
      hourlyRate: 40000,
      distanceKm: 7,
    ),
    HourlyHelper(
      id: 'h-4',
      name: 'Agus Nomercy',
      rating: 4.2,
      reviewCount: 421,
      completedCount: 150,
      hourlyRate: 10000,
      distanceKm: 10,
    ),
    HourlyHelper(
      id: 'h-5',
      name: 'Agus Nomercy',
      rating: 5.0,
      reviewCount: 421,
      completedCount: 90,
      hourlyRate: 20000,
      distanceKm: 12,
    ),
  ];

  static const paymentMethods = [
    PaymentMethod(
      id: 'ovo',
      name: 'OVO',
      group: PaymentGroup.eWallet,
      logo: 'assets/icons/payment/ovo.svg',
    ),
    PaymentMethod(
      id: 'gopay',
      name: 'GoPay',
      group: PaymentGroup.eWallet,
      logo: 'assets/icons/payment/gopay.svg',
    ),
    PaymentMethod(
      id: 'dana',
      name: 'DANA',
      group: PaymentGroup.eWallet,
      logo: 'assets/icons/payment/dana.svg',
    ),
    PaymentMethod(
      id: 'bca',
      name: 'BCA',
      group: PaymentGroup.bank,
      logo: 'assets/icons/payment/bca.svg',
    ),
    PaymentMethod(
      id: 'bni',
      name: 'BNI',
      group: PaymentGroup.bank,
      logo: 'assets/icons/payment/bni.svg',
    ),
    PaymentMethod(
      id: 'mandiri',
      name: 'Mandiri',
      group: PaymentGroup.bank,
      logo: 'assets/icons/payment/mandiri.svg',
    ),
    // Di akhir supaya urutan metode lain (dan indeksnya) tidak berubah;
    // tampilannya tetap paling atas karena urutan grup.
    PaymentMethod(
      id: 'cod',
      name: 'Bayar di Tempat',
      group: PaymentGroup.cashOnDelivery,
    ),
  ];

  /// Pilihan durasi di form dan halaman Tambah Durasi.
  static const durationOptions = [1, 2, 3, 4, 5];

  /// Slot jadwal: tiap jam dari 08.00 sampai 20.00.
  static const firstSlotHour = 8;
  static const lastSlotHour = 20;
}
