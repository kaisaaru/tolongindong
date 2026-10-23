import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/core/format/rupiah.dart';
import 'package:mobile/features/chat/chat_room_page.dart';
import 'package:mobile/features/order/category_helpers_page.dart';
import 'package:mobile/features/order/checkout_page.dart';
import 'package:mobile/features/order/helper_detail_page.dart';
import 'package:mobile/features/order/order_detail_page.dart';
import 'package:mobile/features/order/order_repository.dart';
import 'package:mobile/features/order/order_success_page.dart';

import '../../helpers/fake_chat_repository.dart';
import '../../helpers/fake_helper_repository.dart';
import '../../helpers/fake_order_repository.dart';
import '../../helpers/fake_wallet_repository.dart';
import '../../helpers/pump_page.dart';
import '../../helpers/test_data.dart';

final _helper = testListings.first; // Agus Nomercy, Rp40.000/jam

void main() {
  test('rupiah memakai titik ribuan dan tanda minus di depan', () {
    expect(rupiah(30000), 'Rp 30.000');
    expect(rupiah(150000), 'Rp 150.000');
    expect(rupiah(40000, spaced: false), 'Rp40.000');
    expect(rupiah(-2000, spaced: false), '-Rp2.000');
    expect(rupiah(0), 'Rp 0');
  });

  group('daftar helper kategori', () {
    testWidgets('dari GET /helpers kategori ini', (tester) async {
      final helpers = FakeHelperRepository();
      await pumpPage(
        tester,
        const CategoryHelpersPage(category: testPersonal),
        helperRepo: helpers,
      );
      await tester.pumpAndSettle();

      expect(helpers.requested, [testPersonal.id]);
      expect(find.text('Agus Nomercy'), findsWidgets);
      expect(find.text('Citra Lestari'), findsWidgets);
      // Backend belum punya sub-kategori: chip filter disembunyikan.
      expect(find.text('Semua'), findsNothing);
    });

    testWidgets('pencarian cocok ke label keahlian', (tester) async {
      await pumpPage(tester, const CategoryHelpersPage(category: testPersonal));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'household');
      await tester.pumpAndSettle();

      expect(find.text('Agus Nomercy'), findsWidgets);
      expect(find.text('Citra Lestari'), findsNothing);
    });

    testWidgets('kosong', (tester) async {
      await pumpPage(
        tester,
        const CategoryHelpersPage(category: testPersonal),
        helperRepo: FakeHelperRepository(listingResult: []),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada helper di kategori ini.'), findsOneWidget);
    });

    testWidgets('gagal dimuat, lalu Coba lagi', (tester) async {
      final helpers = FakeHelperRepository(
        error: const ApiException(
          code: 'NETWORK_ERROR',
          message: 'Tidak ada koneksi internet.',
        ),
      );
      await pumpPage(
        tester,
        const CategoryHelpersPage(category: testPersonal),
        helperRepo: helpers,
      );
      await tester.pumpAndSettle();
      expect(find.text('Helper gagal dimuat'), findsOneWidget);

      helpers.error = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Agus Nomercy'), findsWidgets);
    });

    testWidgets('kartu helper membuka detail', (tester) async {
      await pumpPage(tester, const CategoryHelpersPage(category: testPersonal));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Citra Lestari').first);
      await tester.pumpAndSettle();

      expect(find.byType(HelperDetailPage), findsOneWidget);
      expect(find.text('Tentang'), findsOneWidget);
      expect(find.textContaining('Helper belum menulis deskripsi'), findsOne);
    });
  });

  testWidgets('profil helper: Chat helper membuka ruang chat', (tester) async {
    final chats = FakeChatRepository();
    await pumpPage(
      tester,
      HelperDetailPage(helper: _helper, category: testPersonal),
      chatRepo: chats,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Chat helper'));
    await tester.pumpAndSettle();

    expect(chats.started, [_helper.id]);
    expect(find.byType(ChatRoomPage), findsOneWidget);
  });

  group('checkout', () {
    testWidgets('detail tugas wajib diisi', (tester) async {
      final orders = FakeOrderRepository();
      await pumpPage(
        tester,
        CheckoutPage(helper: _helper, category: testPersonal),
        orderRepo: orders,
      );
      await tester.pumpAndSettle();

      expect(find.text('Rp 40.000'), findsOneWidget); // total di bilah bawah
      await tester.tap(find.text('Pesan Sekarang'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ceritakan tugasnya, minimal 5 karakter'),
        findsOneWidget,
      );
      expect(orders.created, isEmpty);
    });

    testWidgets('pesanan ke helper ini dan ruang chat dibuka', (tester) async {
      final orders = FakeOrderRepository(addresses: testAddresses);
      final chats = FakeChatRepository();
      await pumpPage(
        tester,
        CheckoutPage(helper: _helper, category: testPersonal),
        orderRepo: orders,
        chatRepo: chats,
        walletRepo: FakeWalletRepository(balance: 100000),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Desain logo usaha kopi, 3 pilihan',
      );
      await tester.tap(find.text('Pesan Sekarang'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderSuccessPage), findsOneWidget);
      final body = orders.created.single;
      expect(body['category_id'], testPersonal.id);
      expect(body['helper_id'], _helper.id);
      expect(body['client_estimated_price'], 40000);
      // Lokasi pengerjaan: alamat utama.
      expect(body['destination_address_id'], testHome.id);
      final parsed = OrderDescription.parse(
        body['task_description']! as String,
      );
      expect(parsed.title, 'Personal - Agus Nomercy');
      expect(parsed.valueOf('Tugas'), 'Desain logo usaha kopi, 3 pilihan');
      expect(chats.started, [_helper.id]);

      // Halaman sukses tidak tertutup sendiri; lanjut lewat tombol.
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(OrderSuccessPage), findsOneWidget);
      await tester.tap(find.text('Lihat Pesanan'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailPage), findsOneWidget);
    });

    testWidgets('saldo kurang: pesanan tidak dibuat', (tester) async {
      final orders = FakeOrderRepository();
      await pumpPage(
        tester,
        CheckoutPage(helper: _helper, category: testPersonal),
        orderRepo: orders,
        walletRepo: FakeWalletRepository(balance: 5000),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ketik ulang makalah');
      await tester.tap(find.text('Pesan Sekarang'));
      await tester.pumpAndSettle();

      expect(find.text('Saldo TD-Wallet kurang'), findsOneWidget);
      expect(orders.created, isEmpty);
    });
  });
}
