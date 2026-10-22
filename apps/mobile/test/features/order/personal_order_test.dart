import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/activity_view.dart';
import 'package:mobile/features/chat/chat_store.dart';
import 'package:mobile/features/household/household_samples.dart';
import 'package:mobile/features/order/checkout_page.dart';
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

    // Selesaikan timer halaman sukses sebelum test berakhir.
    await tester.pump(OrderSuccessPage.duration);
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
