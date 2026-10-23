import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/activity_view.dart';
import 'package:mobile/features/chat/chat_room_page.dart';
import 'package:mobile/features/order/order_detail_page.dart';
import 'package:mobile/features/order/order_repository.dart';

import '../../helpers/fake_chat_repository.dart';
import '../../helpers/fake_order_repository.dart';
import '../../helpers/pump_page.dart';
import '../../helpers/test_data.dart';

/// Pesanan Personal #1 ke Agus dengan [status].
FakeOrderRepository _repo(OrderStatus status) => FakeOrderRepository(
  orders: [
    FakeOrderRepository.sample(
      status: status,
      categoryCode: 'personal',
      description:
          'Personal - Agus Nomercy\nTugas: Desain logo usaha kopi\n'
          'Tarif: Rp 40.000/jam',
      price: 40000,
      destination: testHome,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  FakeOrderRepository repo, {
  Size size = const Size(412, 917),
  FakeChatRepository? chatRepo,
}) async {
  await pumpPage(
    tester,
    const OrderDetailPage(orderId: 1),
    size: size,
    orderRepo: repo,
    chatRepo: chatRepo,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('isi pesanan dari server: status, helper, tugas, harga', (
    tester,
  ) async {
    await _pump(tester, _repo(OrderStatus.onTheWay));

    expect(find.text('Helper menuju lokasi'), findsOneWidget);
    expect(find.text('Agus Nomercy sedang menuju lokasimu.'), findsOneWidget);
    expect(find.text('Personal - Agus Nomercy'), findsOneWidget);
    expect(find.text('Desain logo usaha kopi'), findsOneWidget);
    expect(find.text(testHome.fullAddress), findsOneWidget);
    expect(find.text('ORD-20261022-1'), findsOneWidget);
  });

  testWidgets('status ikut berubah saat helper menerima', (tester) async {
    final repo = _repo(OrderStatus.awaitingQuote);
    await _pump(tester, repo);
    expect(find.text('Menunggu helper menerima'), findsOneWidget);

    repo.advance(1, OrderStatus.accepted);
    await tester.pump(OrderDetailPage.pollEvery);
    await tester.pumpAndSettle();

    expect(find.text('Helper bersiap berangkat'), findsOneWidget);
  });

  group('batal', () {
    testWidgets('sebelum helper menerima: gratis', (tester) async {
      final repo = _repo(OrderStatus.awaitingQuote);
      await _pump(tester, repo);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Helper belum menerima pesanan, jadi tidak ada biaya pembatalan.',
        ),
        findsOneWidget,
      );

      // "Tidak": pesanan tetap berjalan.
      await tester.tap(find.text('Tidak'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, isEmpty);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batalkan'));
      await tester.pumpAndSettle();

      expect(repo.cancelled, [1]);
      expect(find.text('Dibatalkan'), findsOneWidget);
      expect(
        find.text('Saldo yang ditahan sudah dikembalikan ke TD-Wallet.'),
        findsOneWidget,
      );
      expect(find.text('Batalkan Pesanan'), findsNothing);
    });

    testWidgets('helper sudah berangkat: ada biaya 25%', (tester) async {
      await _pump(tester, _repo(OrderStatus.onTheWay));
      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('25%'), findsOneWidget);
    });
  });

  group('selesai dan rating', () {
    testWidgets('Pesanan Selesai, konfirmasi, lalu rating 5 bintang', (
      tester,
    ) async {
      final repo = _repo(OrderStatus.inProgress);
      await _pump(tester, repo);

      await tester.tap(find.text('Pesanan Selesai'));
      await tester.pumpAndSettle();
      expect(find.text('Pekerjaan sudah selesai?'), findsOneWidget);
      await tester.tap(find.text('Sudah selesai'));
      await tester.pumpAndSettle();

      expect(repo.confirmed, [1]);
      expect(find.text('Beri reting helper'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Beri 5 bintang'));
      // Bintang terisi tampil sebentar sebelum rating dikirim.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.ratings, {1: 5});
      expect(find.text('Terima kasih atas ratingnya!'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Beri Rating'), findsNothing);
    });

    testWidgets('Lewati: ajakan rating tidak diulang', (tester) async {
      final repo = _repo(OrderStatus.awaitingConfirmation);
      await _pump(tester, repo);

      await tester.tap(find.text('Pesanan Selesai'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sudah selesai'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(repo.ratings, isEmpty);
      expect(find.text('Beri Rating'), findsNothing);
    });

    testWidgets('selesai tanpa rating: tombol Beri Rating', (tester) async {
      final repo = _repo(OrderStatus.completed);
      await _pump(tester, repo);

      await tester.tap(find.text('Beri Rating'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Beri 4 bintang'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.ratings, {1: 4});
    });

    testWidgets('sudah dinilai di perangkat lain dianggap berhasil', (
      tester,
    ) async {
      final repo = _repo(OrderStatus.completed)..ratings[1] = 3;
      await _pump(tester, repo);

      await tester.tap(find.text('Beri Rating'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Beri 5 bintang'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.ratings, {1: 3});
      expect(find.text('Terima kasih atas ratingnya!'), findsOneWidget);
      expect(find.text('Beri Rating'), findsNothing);
    });
  });

  testWidgets('Chat helper membuka ruang dengan helper pesanan', (
    tester,
  ) async {
    final chats = FakeChatRepository();
    await _pump(tester, _repo(OrderStatus.onTheWay), chatRepo: chats);

    await tester.tap(find.bySemanticsLabel('Chat helper'));
    await tester.pumpAndSettle();

    expect(chats.started, ['h-1']);
    expect(find.byType(ChatRoomPage), findsOneWidget);
  });

  testWidgets('gagal dimuat: pesan dan Coba lagi', (tester) async {
    await _pump(tester, FakeOrderRepository());
    expect(find.text('Pesanan gagal dimuat'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('Aktifitas membuka detail pesanan', (tester) async {
    await pumpPage(
      tester,
      const Scaffold(body: ActivityView()),
      orderRepo: _repo(OrderStatus.onTheWay),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Personal - Agus Nomercy'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailPage), findsOneWidget);
  });

  testWidgets('layar sempit (360 dp)', (tester) async {
    await _pump(
      tester,
      _repo(OrderStatus.inProgress),
      size: const Size(360, 740),
    );
    expect(find.text('Pesanan Selesai'), findsOneWidget);
  });
}
