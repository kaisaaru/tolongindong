import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/activity_view.dart';
import 'package:mobile/features/chat/chat_room_page.dart';
import 'package:mobile/features/chat/chat_store.dart';
import 'package:mobile/features/household/household_samples.dart';
import 'package:mobile/features/order/checkout_page.dart';
import 'package:mobile/features/order/helper_detail_page.dart';
import 'package:mobile/features/order/order_samples.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/features/order/order_success_page.dart';
import 'package:mobile/features/order/personal_order_page.dart';
import 'package:mobile/theme/app_theme.dart';

/// Reomeo Asgar, Rp40.000 — seperti frame 202.
final _helper = OrderSamples.listingsFor(
  'personal',
).firstWhere((h) => h.price == 40000);

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
  testWidgets('checkout: pesanan Personal tersimpan dan ruang chat dibuat', (
    tester,
  ) async {
    final store = OrderStore();
    final chats = ChatStore(rooms: []);
    await _pump(
      tester,
      CheckoutPage(helper: _helper, store: store, chatStore: chats),
    );

    await tester.tap(find.text('Pilih metode pembayaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BCA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderSuccessPage), findsOneWidget);
    expect(store.personal?.helper.id, _helper.id);
    expect(store.personal?.payment.name, 'BCA');
    expect(chats.rooms.single.helperId, _helper.id);

    // Halaman sukses tidak tertutup sendiri; lanjut lewat tombol.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(OrderSuccessPage), findsOneWidget);
    await tester.tap(find.text('Lihat Pesanan'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonalOrderPage), findsOneWidget);
  });

  testWidgets('pesanan berjalan: tombol Chat Helper membuka ruang chat', (
    tester,
  ) async {
    final store = OrderStore()
      ..placePersonal(
        helper: _helper,
        payment: HouseholdSamples.paymentMethods.first,
      );
    final chats = ChatStore(rooms: []);
    await _pump(tester, PersonalOrderPage(store: store, chatStore: chats));

    expect(find.text('Sedang dikerjakan ${_helper.name}'), findsOneWidget);
    await tester.tap(find.text('Chat Helper'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatRoomPage), findsOneWidget);
    expect(chats.rooms.single.helperId, _helper.id);
  });

  testWidgets('checkout menolak pesanan Personal kedua', (tester) async {
    final store = OrderStore()
      ..placePersonal(
        helper: _helper,
        payment: HouseholdSamples.paymentMethods.first,
      );
    await _pump(
      tester,
      CheckoutPage(helper: _helper, store: store, chatStore: ChatStore()),
    );

    await tester.tap(find.text('Pilih metode pembayaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OVO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pump();

    expect(
      find.textContaining('Masih ada pesanan Personal yang berjalan'),
      findsOneWidget,
    );
  });

  testWidgets('pesanan berjalan: ringkasan, Selesai, rating, riwayat', (
    tester,
  ) async {
    final store = OrderStore()
      ..placePersonal(
        helper: _helper,
        payment: HouseholdSamples.paymentMethods[3], // BCA
        voucher: OrderSamples.vouchers.first,
      );
    await _pump(tester, PersonalOrderPage(store: store));

    expect(find.text(_helper.name), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('Diskon Rp 8.000'), findsOneWidget);
    expect(find.text('Rp32.000'), findsOneWidget); // total
    // Hanya dibaca: tidak ada panah pilih.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await tester.tap(find.text('Selesai'));
    await tester.pump();
    expect(find.text('Beri reting helper'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Beri 5 bintang'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.personal, isNull);
    final record = store.history.single;
    expect(record.title, 'Personal - ${_helper.subcategory}');
    expect(record.categoryCode, 'personal');
    expect(record.rating, 5);
    expect(record.total, 32000);
  });

  testWidgets('rating boleh dilewati: pesanan tetap masuk riwayat', (
    tester,
  ) async {
    final store = OrderStore()
      ..placePersonal(
        helper: _helper,
        payment: HouseholdSamples.paymentMethods.first,
      );
    await _pump(tester, PersonalOrderPage(store: store));

    await tester.tap(find.text('Selesai'));
    await tester.pump();
    await tester.tap(find.text('Lewati'));
    await tester.pump();

    expect(store.personal, isNull);
    expect(store.history.single.rating, isNull);
  });

  testWidgets('setelah rating atau Lewati, halaman pesanan tertutup', (
    tester,
  ) async {
    for (final rate in [true, false]) {
      final store = OrderStore()
        ..placePersonal(
          helper: _helper,
          payment: HouseholdSamples.paymentMethods.first,
        );
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PersonalOrderPage(store: store),
              ),
            ),
            child: const Text('Buka'),
          ),
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Selesai'));
      await tester.pump();
      if (rate) {
        await tester.tap(find.bySemanticsLabel('Beri 4 bintang'));
        // Bintang terisi tampil sebentar sebelum rating dikirim.
        await tester.pump(const Duration(milliseconds: 400));
      } else {
        await tester.tap(find.text('Lewati'));
      }
      await tester.pumpAndSettle();

      expect(find.byType(PersonalOrderPage), findsNothing);
      expect(store.history.single.rating, rate ? 4 : isNull);
    }
  });

  testWidgets('kembali dari rating membuka lagi rincian pesanan', (
    tester,
  ) async {
    final store = OrderStore()
      ..placePersonal(
        helper: _helper,
        payment: HouseholdSamples.paymentMethods.first,
      );
    await _pump(tester, PersonalOrderPage(store: store));

    await tester.tap(find.text('Selesai'));
    await tester.pump();
    expect(find.text('Beri reting helper'), findsOneWidget);

    // Tombol kembali sistem, misal setelah salah ketuk "Selesai".
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pump();

    expect(find.text('Beri reting helper'), findsNothing);
    expect(find.text('Selesai'), findsOneWidget);
    expect(store.personal, isNotNull);
  });

  testWidgets('profil helper menolak pesanan kedua sebelum checkout', (
    tester,
  ) async {
    final store = OrderStore()
      ..placePersonal(
        helper: _helper,
        payment: HouseholdSamples.paymentMethods.first,
      );
    await _pump(
      tester,
      HelperDetailPage(helper: _helper, store: store, chatStore: ChatStore()),
    );

    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pumpAndSettle(); // snackbar selesai muncul

    expect(
      find.text('Masih ada pesanan Personal yang berjalan.'),
      findsOneWidget,
    );
    expect(find.byType(CheckoutPage), findsNothing);

    await tester.tap(find.text('Lihat'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonalOrderPage), findsOneWidget);
  });

  testWidgets('halaman pesanan yang sudah ditutup tetap bisa kembali', (
    tester,
  ) async {
    await _pump(tester, PersonalOrderPage(store: OrderStore()));

    expect(find.textContaining('Pesanan ini sudah selesai'), findsOneWidget);
    expect(find.byTooltip('Kembali'), findsOneWidget);
  });

  testWidgets('Aktifitas menampilkan pesanan Personal', (tester) async {
    final store = OrderStore()
      ..placePersonal(
        helper: _helper,
        payment: HouseholdSamples.paymentMethods.first,
      );
    await _pump(tester, Scaffold(body: ActivityView(store: store)));

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Dikerjakan ${_helper.name}'), findsOneWidget);

    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonalOrderPage), findsOneWidget);
  });

  testWidgets('pesanan berjalan di layar sempit (360 dp)', (tester) async {
    final store = OrderStore()
      ..placePersonal(
        helper: _helper,
        payment: HouseholdSamples.paymentMethods.first,
      );
    await _pump(
      tester,
      PersonalOrderPage(store: store),
      size: const Size(360, 740),
    );
    expect(find.text('Selesai'), findsOneWidget);
  });
}
