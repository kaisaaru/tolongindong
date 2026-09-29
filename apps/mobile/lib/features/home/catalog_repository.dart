import '../../core/api/api_client.dart';
import '../../models/service_category.dart';

/// Data katalog yang tampil di beranda. Untuk sekarang baru kategori
/// layanan; promo dan makanan favorit menyusul kalau backend sudah punya.
class CatalogRepository {
  CatalogRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// `GET /service-categories` — endpoint publik, tidak butuh login.
  /// Balasannya berupa List, bukan Map, jadi tidak lewat `_persist` apa pun.
  Future<List<ServiceCategory>> categories() async {
    final data = await _api.get('/service-categories');
    return (data as List)
        .map((e) => ServiceCategory.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
