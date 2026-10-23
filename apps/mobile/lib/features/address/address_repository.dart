import '../../core/api/api_client.dart';
import '../household/household_models.dart';

/// Alamat tersimpan pengguna (`/addresses`, FR-PRF-002 dan FR-PRF-003).
/// Pesanan dibuat memakai id alamat dari sini.
class AddressRepository {
  AddressRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Alamat utama selalu di urutan pertama.
  Future<List<SavedAddress>> list() async {
    final data = await _api.get('/addresses');
    return [
      for (final e in data as List)
        SavedAddress.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  /// Koordinat wajib: dipakai menghitung jarak helper dan ongkos kirim.
  Future<SavedAddress> create({
    required String label,
    required String fullAddress,
    required double latitude,
    required double longitude,
    String? landmarkNote,
    bool isPrimary = false,
  }) async {
    final data = await _api.post(
      '/addresses',
      body: {
        'label': label,
        'full_address': fullAddress,
        'latitude': latitude,
        'longitude': longitude,
        'landmark_note': ?landmarkNote,
        'is_primary': isPrimary,
      },
    );
    return SavedAddress.fromJson((data as Map).cast<String, dynamic>());
  }
}
