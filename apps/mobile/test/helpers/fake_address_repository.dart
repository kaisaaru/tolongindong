import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/address/address_repository.dart';
import 'package:mobile/features/household/household_models.dart';

import 'test_data.dart';

/// Pengganti [AddressRepository] untuk widget test: alamat di memori.
class FakeAddressRepository implements AddressRepository {
  FakeAddressRepository({List<SavedAddress> addresses = testAddresses})
    : addresses = [...addresses];

  final List<SavedAddress> addresses;

  /// Kalau diisi, [create] berikutnya gagal dengan error ini (sekali).
  ApiException? failNextCreate;

  int _nextId = 50;

  @override
  Future<List<SavedAddress>> list() async => [...addresses];

  @override
  Future<SavedAddress> create({
    required String label,
    required String fullAddress,
    required double latitude,
    required double longitude,
    String? landmarkNote,
    bool isPrimary = false,
  }) async {
    final fail = failNextCreate;
    if (fail != null) {
      failNextCreate = null;
      throw fail;
    }
    final address = SavedAddress(
      id: _nextId++,
      label: label,
      fullAddress: fullAddress,
      kind: AddressKind.home,
      latitude: latitude,
      longitude: longitude,
      landmarkNote: landmarkNote,
      isPrimary: isPrimary,
    );
    addresses.add(address);
    return address;
  }

  @override
  Future<void> delete(int id) async {
    addresses.removeWhere((a) => a.id == id);
  }

  @override
  Future<void> setPrimary(int id) async {
    for (var i = 0; i < addresses.length; i++) {
      final a = addresses[i];
      addresses[i] = SavedAddress(
        id: a.id,
        label: a.label,
        fullAddress: a.fullAddress,
        kind: a.kind,
        latitude: a.latitude,
        longitude: a.longitude,
        landmarkNote: a.landmarkNote,
        isPrimary: a.id == id,
      );
    }
  }
}
