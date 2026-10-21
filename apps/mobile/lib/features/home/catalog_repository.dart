import '../../core/api/api_client.dart';
import '../../models/service_category.dart';

/// Data yang tampil di beranda: kategori layanan, alamat utama di header,
/// dan jumlah notifikasi belum dibaca.
class CatalogRepository {
  CatalogRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// `GET /service-categories` — endpoint publik, tidak butuh login.
  /// Balasannya berupa List, bukan Map, jadi tidak lewat `_persist` apa pun.
  Future<List<ServiceCategory>> categories() async {
    final data = await _api.get('/service-categories');
    return (data as List)
        .map(
          (e) => ServiceCategory.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  /// `GET /addresses` (FR-PRF-002). Backend selalu menaruh alamat utama di
  /// urutan teratas, jadi cukup ambil yang pertama. Null kalau user belum
  /// menyimpan alamat sama sekali.
  Future<String?> primaryAddress() async {
    final data = await _api.get('/addresses');
    final list = data as List;
    if (list.isEmpty) return null;
    final address = (list.first as Map)['full_address'] as String?;
    return address == null || address.trim().isEmpty ? null : address.trim();
  }

  /// `GET /notifications` (FR-NOT-001). Hanya angka belum dibacanya yang
  /// dipakai beranda; daftar lengkapnya untuk halaman notifikasi nanti.
  Future<int> unreadNotificationCount() async {
    final data = await _api.get('/notifications', query: {'per_page': 1});
    return ((data as Map)['unread_count'] as num?)?.toInt() ?? 0;
  }
}
