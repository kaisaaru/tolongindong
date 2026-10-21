import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/chat_list_view.dart';
import 'package:mobile/features/chat/chat_models.dart';
import 'package:mobile/features/chat/chat_room_page.dart';
import 'package:mobile/features/chat/chat_store.dart';
import 'package:mobile/features/order/helper_detail_page.dart';
import 'package:mobile/features/order/order_samples.dart';
import 'package:mobile/theme/app_theme.dart';

/// Jam 15.00, jadi pesan contoh pukul 12.00 masih "hari ini".
DateTime _now() => DateTime(2026, 10, 22, 15);

ChatStore _store() => ChatStore(clock: _now);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(412, 917),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
  await tester.pump();
}

void main() {
  group('ChatStore', () {
    test('membuka chat dengan helper yang sama memakai ruang yang ada', () {
      final store = _store();
      final room = store.openWithHelper(helperId: 'sample-1', name: 'Agus');
      expect(room.id, 'room-sample-1');
      expect(store.rooms, hasLength(1));

      store.openWithHelper(helperId: 'sample-3', name: 'Reomeo Asgar');
      expect(store.rooms, hasLength(2));
    });

    test('kirim: dirapikan, pesan kosong diabaikan, ruang naik ke atas', () {
      final store = _store();
      final fresh = store.openWithHelper(helperId: 'x', name: 'Baru');
      // Ruang baru belum punya pesan; "dibuat" pukul 15.00, jadi di atas.
      expect(store.rooms.first, fresh);

      final agus = store.rooms.last;
      store.send(agus, '   ');
      expect(agus.messages, hasLength(4));

      store.send(agus, '  Terima kasih  ');
      expect(agus.lastMessage!.text, 'Terima kasih');
      expect(agus.lastMessage!.fromMe, isTrue);
    });
  });

  testWidgets('daftar obrolan: isi seperti desain, bisa dicari', (
    tester,
  ) async {
    await _pump(tester, Scaffold(body: ChatListView(store: _store())));

    expect(find.text('Obrolan'), findsOneWidget);
    expect(find.text('Agus Nomercy'), findsOneWidget);
    expect(find.text('Baik akan saya kerjakan segera!'), findsOneWidget);
    expect(find.text('12.00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'reomeo');
    await tester.pump();
    expect(find.text('Helper tidak ditemukan.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'agus');
    await tester.pump();
    expect(find.text('Agus Nomercy'), findsOneWidget);
  });

  testWidgets('pesan belum dibaca: lencana, hilang setelah dibuka', (
    tester,
  ) async {
    final store = ChatStore(
      clock: _now,
      rooms: [
        ChatRoom(
          id: 'r',
          helperId: 'h',
          peerName: 'Reomeo Asgar',
          createdAt: DateTime(2026, 10, 22, 9),
          unreadCount: 2,
          messages: [
            ChatMessage(
              fromMe: false,
              sentAt: DateTime(2026, 10, 22, 9),
              text: 'Sudah selesai ya',
            ),
          ],
        ),
      ],
    );
    await _pump(tester, Scaffold(body: ChatListView(store: store)));
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Reomeo Asgar'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatRoomPage), findsOneWidget);
    expect(store.rooms.single.unreadCount, 0);
  });

  testWidgets('ruang chat: gelembung, lampiran, kirim lewat keyboard', (
    tester,
  ) async {
    final store = _store();
    final room = store.rooms.single;
    await _pump(tester, ChatRoomPage(room: room, store: store));

    expect(find.text('Agus Nomercy'), findsOneWidget);
    expect(find.text('Ya tentu! silahkan kirimkan tugasnya'), findsOneWidget);
    expect(find.text('Tugas Kalkulus Aljabar'), findsOneWidget);
    expect(find.text('PDF · 3 MB'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Terimakasih');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(find.text('Terimakasih'), findsOneWidget); // gelembung baru
    expect(room.lastMessage!.text, 'Terimakasih');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);

    await tester.tap(find.byTooltip('Lampiran'));
    await tester.pump();
    expect(find.text('Kirim lampiran belum tersedia.'), findsOneWidget);
  });

  testWidgets('Chat helper di profil membuka ruang dengan helper itu', (
    tester,
  ) async {
    final store = _store();
    final helper = OrderSamples.listingsFor(
      'personal',
    ).firstWhere((h) => h.name == 'Reomeo Asgar');
    await _pump(tester, HelperDetailPage(helper: helper, chatStore: store));

    await tester.tap(find.bySemanticsLabel('Chat helper'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatRoomPage), findsOneWidget);
    expect(store.rooms.any((r) => r.helperId == helper.id), isTrue);
  });

  group('tata letak sempit (360 dp)', () {
    testWidgets('daftar obrolan', (tester) async {
      await _pump(
        tester,
        Scaffold(body: ChatListView(store: _store())),
        size: const Size(360, 740),
      );
      expect(find.text('Agus Nomercy'), findsOneWidget);
    });

    testWidgets('ruang chat', (tester) async {
      final store = _store();
      await _pump(
        tester,
        ChatRoomPage(room: store.rooms.single, store: store),
        size: const Size(360, 740),
      );
      expect(find.text('Ketik pesan'), findsOneWidget);
    });
  });
}
