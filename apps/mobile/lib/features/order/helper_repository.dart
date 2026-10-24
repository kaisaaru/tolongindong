import '../../core/api/api_client.dart';
import '../household/household_models.dart';
import 'order_models.dart';

/// Katalog helper terverifikasi yang sedang tersedia, dalam radius 10 km
/// dari alamat utama pengguna (`GET /helpers`, FR-HLP-002 s/d 006).
class HelperRepository {
  HelperRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> _find(
    int categoryId,
    String sortBy,
  ) async {
    final data = await _api.get(
      '/helpers',
      query: {'category_id': categoryId, 'sort_by': sortBy},
    );
    return [
      for (final e in (data as Map)['helpers'] as List? ?? const [])
        (e as Map).cast<String, dynamic>(),
    ];
  }

  /// Helper per jam (Household, Delivery), terdekat lebih dulu.
  Future<List<HourlyHelper>> hourly(int categoryId) async => [
    for (final json in await _find(categoryId, 'distance'))
      HourlyHelper.fromJson(json),
  ];

  /// Daftar helper Personal, rating tertinggi lebih dulu.
  Future<List<HelperListing>> listings(int categoryId) async => [
    for (final json in await _find(categoryId, 'rating'))
      HelperListing.fromJson(json),
  ];
}
