import '../../core/api/api_client.dart';
import '../../core/api/paged.dart';

/// Satu notifikasi dari `GET /notifications` (FR-NOT-001 s/d 005).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.orderId,
    this.readAt,
  });

  final int id;

  /// `order_offer`, `order_status_change`, `chat_message`, `dispute_update`,
  /// `wallet_mutation`, atau `promo`.
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final int? orderId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    orderId: orderId,
    readAt: readAt ?? at,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse('${json['created_at']}')?.toLocal() ??
            DateTime.now(),
        orderId: (json['reference_order_id'] as num?)?.toInt(),
        readAt: DateTime.tryParse('${json['read_at']}')?.toLocal(),
      );
}

/// Satu halaman notifikasi beserta jumlah yang belum dibaca.
class NotificationFeed {
  const NotificationFeed({required this.unreadCount, required this.page});

  final int unreadCount;
  final Paged<AppNotification> page;
}

class NotificationRepository {
  NotificationRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Terbaru di atas, 20 per halaman.
  Future<NotificationFeed> list({int page = 1}) async {
    final data = await _api.get(
      '/notifications',
      query: {'page': page, 'per_page': 20},
    );
    final map = (data as Map).cast<String, dynamic>();
    return NotificationFeed(
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
      page: Paged.fromJson(
        (map['notifications'] as Map).cast<String, dynamic>(),
        AppNotification.fromJson,
      ),
    );
  }

  Future<void> markRead(int id) async {
    await _api.post('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.post('/notifications/read-all');
  }
}
