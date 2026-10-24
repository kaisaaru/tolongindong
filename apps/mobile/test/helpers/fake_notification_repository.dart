import 'package:mobile/core/api/paged.dart';
import 'package:mobile/features/notification/notification_repository.dart';

/// Pengganti [NotificationRepository] untuk widget test.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository(this.items);

  List<AppNotification> items;
  final readIds = <int>[];
  int markAllCalls = 0;

  @override
  Future<NotificationFeed> list({int page = 1}) async => NotificationFeed(
    unreadCount: items.where((n) => !n.isRead).length,
    page: Paged(items: items, page: 1, lastPage: 1),
  );

  @override
  Future<void> markRead(int id) async => readIds.add(id);

  @override
  Future<void> markAllRead() async => markAllCalls++;
}
