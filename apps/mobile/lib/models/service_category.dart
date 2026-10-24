/// Kategori layanan dari `GET /service-categories` (FR-HLP-001).
///
/// Kategori ditanam backend lewat seeder, jadi jumlah dan kodenya tetap.
/// Yang bisa berubah dari waktu ke waktu cuma tarif dan aturannya.
class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.baseFee,
    required this.requiresAdvance,
    required this.requiresProofPhoto,
    required this.requiresPickupAddress,
    required this.requiresDestinationAddress,
  });

  final int id;

  /// `delivery`, `personal`, `household`.
  /// Dipakai untuk memilih ikon, jadi jangan dicocokkan lewat [name].
  final String code;

  final String name;

  /// Tarif dasar dalam rupiah, bilangan bulat.
  final int baseFee;

  /// Kategori bertalangan (Food run, Laundry) — helper menalangi belanja dulu.
  final bool requiresAdvance;

  /// Wajib unggah foto bukti selesai (FR-ORD-013).
  final bool requiresProofPhoto;

  final bool requiresPickupAddress;
  final bool requiresDestinationAddress;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) =>
      ServiceCategory(
        id: json['id'] as int,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        baseFee: json['base_fee'] as int? ?? 0,
        requiresAdvance: json['requires_advance'] as bool? ?? false,
        requiresProofPhoto: json['requires_proof_photo'] as bool? ?? false,
        requiresPickupAddress:
            json['requires_pickup_address'] as bool? ?? false,
        requiresDestinationAddress:
            json['requires_destination_address'] as bool? ?? true,
      );
}
