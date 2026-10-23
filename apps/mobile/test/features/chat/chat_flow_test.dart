import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/chat/chat_list_view.dart';
import 'package:mobile/features/chat/chat_models.dart';
import 'package:mobile/features/chat/chat_room_page.dart';
import 'package:mobile/features/chat/chat_store.dart';

import '../../helpers/fake_chat_repository.dart';
import '../../helpers/pump_page.dart';

/// Jam 15.00, jadi pesan pukul 12.00 masih "hari ini".
DateTime _now() => DateTime(2026, 10, 22, 15);

ChatMessage _message(String text, {bool fromMe = false, int hour = 12}) =>
    ChatMessage(
      fromMe: fromMe,
      sentAt: DateTime(2026, 10, 22, hour),
      text: text,
    );

/// Satu ruang dengan Agus, pesan terakhir dari helper pukul 12.00.
FakeChatRepository _repo({int unread = 0, bool readOnly = false}) =>
    FakeChatRepository(
      clock: _now,
      rooms: [
        FakeRoom(
          id: 1,
          peerName: 'Agus Nomercy',
          helperId: 'h-1',
          unread: unread,
          isReadOnly: readOnly,
          messages: [
            _message(
              'Halo, bisa bantu tugas kalkulus?',
              fromMe: true,
              hour: 11,
            ),
            _message('Baik akan saya kerjakan segera!'),
          ],
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(412, 917),
  FakeChatRepository? chatRepo,
  ChatStore? chatStore,
}) async {
  await pumpPage(
    tester,
    page,
    size: size,
    chatRepo: chatRepo,
    chatStore: chatStore,
  );
  await tester.pumpAndSettle();
}

/// Ruang [id] dari [repo], seperti yang dibuka dari daftar obrolan.
Future<(ChatStore, ChatRoom)> _openRoom(FakeChatRepository repo) async {
  final store = ChatStore(repo, userId: () => testUser.id, clock: _now);
  await store.refresh();
  return (store, store.rooms.single);
}

void main() {
  group('ChatStore', () {
    test(
      'membuka chat dengan helper yang sama memakai ruang yang ada',
      () async {
        final repo = _repo();
        final store = ChatStore(repo, clock: _now);
        await store.refresh();

        final room = await store.openWithHelper(helperId: 'h-1', name: 'Agus');
        expect(room.id, 1);
        expect(store.rooms, hasLength(1));

        await store.openWithHelper(helperId: 'h-2', name: 'Budi');
        expect(store.rooms, hasLength(2));
        expect(repo.started, ['h-1', 'h-2']);
      },
    );

    test('kirim: dirapikan, pesan kosong diabaikan', () async {
      final (store, room) = await _openRoom(_repo());
      await store.loadMessages(room);

      await store.send(room, '   ');
      expect(room.messages, hasLength(2));

      await store.send(room, '  Terima kasih  ');
      expect(room.lastMessage!.text, 'Terima kasih');
      expect(room.lastMessage!.fromMe, isTrue);
    });
  });

  testWidgets('daftar obrolan dari server, bisa dicari', (tester) async {
    await _pump(
      tester,
      const Scaffold(body: ChatListView()),
      chatStore: ChatStore(_repo(), clock: _now),
    );

    expect(find.text('Obrolan'), findsOneWidget);
    expect(find.text('Agus Nomercy'), findsOneWidget);
    expect(find.text('Baik akan saya kerjakan segera!'), findsOneWidget);
    expect(find.text('12.00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'budi');
    await tester.pump();
    expect(find.text('Helper tidak ditemukan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'agus');
    await tester.pump();
    expect(find.text('Agus Nomercy'), findsOneWidget);
  });

  testWidgets('belum ada obrolan', (tester) async {
    await _pump(
      tester,
      const Scaffold(body: ChatListView()),
      chatRepo: FakeChatRepository(),
    );
    expect(find.text('Belum ada obrolan'), findsOneWidget);
  });

  testWidgets('pesan belum dibaca: lencana, hilang setelah dibuka', (
    tester,
  ) async {
    final store = ChatStore(_repo(unread: 2), clock: _now);
    addTearDown(store.dispose);
    await _pump(tester, const Scaffold(body: ChatListView()), chatStore: store);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Agus Nomercy'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatRoomPage), findsOneWidget);
    expect(store.unreadCount, 0);
  });

  testWidgets('ruang chat: isi dari server, kirim lewat keyboard', (
    tester,
  ) async {
    final repo = _repo();
    final (store, room) = await _openRoom(repo);
    addTearDown(store.dispose);
    await _pump(tester, ChatRoomPage(room: room), chatStore: store);

    expect(find.text('Agus Nomercy'), findsOneWidget);
    expect(find.text('Baik akan saya kerjakan segera!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Terimakasih');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Terimakasih'), findsOneWidget); // gelembung baru
    expect(repo.stored.single.messages.last.text, 'Terimakasih');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);

    await tester.tap(find.byTooltip('Lampiran'));
    await tester.pump();
    expect(find.text('Kirim lampiran belum tersedia.'), findsOneWidget);
  });

  testWidgets('balasan helper muncul tanpa membuka ulang', (tester) async {
    final repo = _repo();
    final (store, room) = await _openRoom(repo);
    addTearDown(store.dispose);
    await _pump(tester, ChatRoomPage(room: room), chatStore: store);

    repo.reply(1, 'Sudah saya kirim filenya');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Sudah saya kirim filenya'), findsOneWidget);
  });

  testWidgets('gagal kirim: pesan tetap di kolom ketik', (tester) async {
    final repo = _repo()
      ..failNextSend = const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Tidak ada koneksi internet.',
      );
    final (store, room) = await _openRoom(repo);
    addTearDown(store.dispose);
    await _pump(tester, ChatRoomPage(room: room), chatStore: store);

    await tester.enterText(find.byType(TextField), 'Halo lagi');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada koneksi internet.'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Halo lagi');
  });

  testWidgets('pesanan selesai: obrolan hanya bisa dibaca', (tester) async {
    final (store, room) = await _openRoom(_repo(readOnly: true));
    addTearDown(store.dispose);
    await _pump(tester, ChatRoomPage(room: room), chatStore: store);

    expect(
      find.text('Pesanan sudah selesai. Obrolan ini hanya bisa dibaca.'),
      findsOneWidget,
    );
    expect(find.text('Ketik pesan'), findsNothing);
  });

  group('tata letak sempit (360 dp)', () {
    testWidgets('daftar obrolan', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: ChatListView()),
        size: const Size(360, 740),
        chatRepo: _repo(),
      );
      expect(find.text('Agus Nomercy'), findsOneWidget);
    });

    testWidgets('ruang chat', (tester) async {
      final (store, room) = await _openRoom(_repo());
      addTearDown(store.dispose);
      await _pump(
        tester,
        ChatRoomPage(room: room),
        size: const Size(360, 740),
        chatStore: store,
      );
      expect(find.text('Ketik pesan'), findsOneWidget);
    });
  });
}
