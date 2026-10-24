import '../../core/api/api_client.dart';
import '../order/order_repository.dart';

/// Kategori layanan helper.
class HelperCategory {
  const HelperCategory({
    required this.id,
    required this.code,
    required this.name,
  });

  factory HelperCategory.fromJson(Map<String, dynamic> json) => HelperCategory(
    id: (json['id'] as num).toInt(),
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  final int id;

  /// `delivery`, `personal`, atau `household`.
  final String code;
  final String name;
}

/// Status akun helper dari `GET /helper/status`.
class HelperStatus {
  const HelperStatus({
    required this.isVerifiedHelper,
    this.profileId,
    this.available = false,
    this.hourlyRate = 0,
    this.rating = 0,
    this.ratingCount = 0,
    this.completedCount = 0,
    this.categories = const [],
  });

  /// Belum pernah mendaftar jadi helper.
  static const none = HelperStatus(isVerifiedHelper: false);

  factory HelperStatus.fromJson(Map<String, dynamic> json) {
    final profile = (json['helper_profile'] as Map?)?.cast<String, dynamic>();
    if (profile == null) {
      return HelperStatus(
        isVerifiedHelper: json['is_verified_helper'] as bool? ?? false,
      );
    }
    return HelperStatus(
      isVerifiedHelper: json['is_verified_helper'] as bool? ?? false,
      profileId: profile['id'] as String?,
      available: profile['is_available'] == 'available',
      hourlyRate: (profile['hourly_rate'] as num?)?.toInt() ?? 0,
      rating: double.tryParse('${profile['rating_average']}') ?? 0,
      ratingCount: (profile['rating_count'] as num?)?.toInt() ?? 0,
      completedCount: (profile['completed_order_count'] as num?)?.toInt() ?? 0,
      categories: [
        for (final c in profile['categories'] as List? ?? const [])
          HelperCategory.fromJson((c as Map).cast<String, dynamic>()),
      ],
    );
  }

  /// Sudah disetujui admin: boleh masuk mode Helper.
  final bool isVerifiedHelper;

  /// `helper_profiles.id`, untuk mengenali penawaran milik sendiri.
  final String? profileId;

  /// Muncul di pencarian dan menerima permintaan baru.
  final bool available;
  final int hourlyRate;
  final double rating;
  final int ratingCount;
  final int completedCount;
  final List<HelperCategory> categories;
}

/// Pekerjaan helper (`/orders` dengan `role=helper`, `/helper/*`).
class HelperWorkRepository {
  HelperWorkRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<HelperStatus> status() async {
    final data = await _api.get('/helper/status');
    return HelperStatus.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Ubah status kerja dan/atau kategori layanan (maksimal 3).
  Future<void> updateProfile({bool? available, List<int>? categoryIds}) async {
    await _api.put(
      '/helper/profile',
      body: {
        if (available != null)
          'is_available': available ? 'available' : 'unavailable',
        'category_ids': ?categoryIds,
      },
    );
  }

  /// Pesanan yang ditujukan ke helper ini, terbaru di atas.
  Future<List<ServerOrder>> jobs({int perPage = 100}) async {
    final data = await _api.get(
      '/orders',
      query: {'role': 'helper', 'per_page': perPage},
    );
    return [
      for (final e in (data as Map)['data'] as List? ?? const [])
        ServerOrder.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  Future<ServerOrder> job(int id) async {
    final data = await _api.get('/orders/$id');
    return ServerOrder.fromJson(
      ((data as Map)['order'] as Map).cast<String, dynamic>(),
      allowedNext: data['allowed_next_statuses'] as List?,
    );
  }

  /// Penawaran harga; pelanggan punya 5 menit untuk menyetujuinya.
  Future<void> submitOffer(int id, int price, {String? message}) async {
    await _api.post(
      '/orders/$id/offers',
      body: {'proposed_price': price, 'message': ?message},
    );
  }

  Future<void> reject(int id, {String? reason}) async {
    await _api.post('/orders/$id/reject', body: {'reason': ?reason});
  }

  /// Majukan tahap pekerjaan, misal `on_the_way` atau
  /// `awaiting_confirmation` (tandai selesai).
  Future<void> advance(int id, OrderStatus status) async {
    await _api.post('/orders/$id/status', body: {'status': status.code});
  }
}
