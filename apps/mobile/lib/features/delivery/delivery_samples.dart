import '../household/household_models.dart';

/// Pengantaran sebelumnya: alamat tujuan dan kapan dikirim.
class PastDelivery {
  const PastDelivery({required this.destination, required this.daysAgo});

  final SavedAddress destination;
  final int daysAgo;
}

/// Data contoh dari desain Delivery (frame 33 dan 71).
class DeliverySamples {
  const DeliverySamples._();

  /// Biaya pengiriman di semua frame desain. Backend menghitungnya dari
  /// jarak, tapi app belum bisa menghitung jarak (belum ada geocoding).
  static const fee = 20000;

  static const _reog = SavedAddress(
    label: 'Jl. Reog',
    fullAddress: 'Jl. Reog, Turangga, Kec. Lengkong, Kota Bandung, Jawa Barat',
    kind: AddressKind.recent,
  );

  /// Nanti dari `GET /orders` kategori delivery.
  static const pastDeliveries = [
    PastDelivery(destination: _reog, daysAgo: 4),
    PastDelivery(destination: _reog, daysAgo: 19),
    PastDelivery(destination: _reog, daysAgo: 90),
  ];
}
