import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notification/notification_page.dart';
import 'package:mobile/features/notification/notification_repository.dart';

import '../../helpers/fake_notification_repository.dart';
import '../../helpers/pump_page.dart';

final _now = DateTime(2026, 10, 22, 12);

AppNotification _note(
  int id, {
  bool read = false,
  Duration ago = Duration.zero,
}) => AppNotification(
  id: id,
  type: 'chat_message',
  title: 'Pesan baru dari Agus',
  body: 'Baik akan saya kerjakan segera!',
  createdAt: _now.subtract(ago),
  readAt: read ? _now : null,
);

void main() {
  testWidgets('daftar dengan waktu relatif; ketuk menandai dibaca', (
    tester,
  ) async {
    final repo = FakeNotificationRepository([
      _note(1, ago: const Duration(minutes: 5)),
      _note(2, read: true, ago: const Duration(days: 2)),
    ]);
    await pumpPage(tester, NotificationPage(repo: repo, clock: () => _now));
    await tester.pumpAndSettle();

    expect(find.text('5 menit lalu'), findsOneWidget);
    expect(find.text('2 hari lalu'), findsOneWidget);
    expect(find.text('Tandai dibaca'), findsOneWidget);

    await tester.tap(find.text('5 menit lalu'));
    await tester.pump();

    expect(repo.readIds, [1]);
    // Tidak ada lagi yang belum dibaca.
    expect(find.text('Tandai dibaca'), findsNothing);
  });

  testWidgets('Tandai dibaca menandai semuanya', (tester) async {
    final repo = FakeNotificationRepository([_note(1), _note(2)]);
    await pumpPage(tester, NotificationPage(repo: repo, clock: () => _now));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tandai dibaca'));
    await tester.pump();

    expect(repo.markAllCalls, 1);
    expect(find.text('Tandai dibaca'), findsNothing);
  });

  testWidgets('kosong: penjelasan', (tester) async {
    await pumpPage(
      tester,
      NotificationPage(repo: FakeNotificationRepository([])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada notifikasi'), findsOneWidget);
  });
}
