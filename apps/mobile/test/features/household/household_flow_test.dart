import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/activity/activity_view.dart';
import 'package:mobile/features/household/hourly_helper_list_page.dart';
import 'package:mobile/features/household/house_order_form_page.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/household/order_review_page.dart';
import 'package:mobile/features/order/order_detail_page.dart';
import 'package:mobile/features/order/order_repository.dart';
import 'package:mobile/features/order/order_success_page.dart';

import '../../helpers/fake_helper_repository.dart';
import '../../helpers/fake_order_repository.dart';
import '../../helpers/fake_wallet_repository.dart';
import '../../helpers/pump_page.dart';
import '../../helpers/test_data.dart';

const _household = testHousehold;
final _helper = testHelpers.first; // Rp40.000/jam

HouseholdOrderDraft _draft({TimeSlot? slot, int hours = 1}) =>
    HouseholdOrderDraft(
      service: HouseholdService.rumah,
      address: testHome,
      widthM: 10,
      lengthM: 10,
      tools: ToolOption.provided,
      slot: slot,
      helper: _helper,
      hours: hours,
    );

void main() {
  test('rincian harga: biaya helper per jam ditambah biaya lain', () {
    const price = PriceBreakdown(
      hourlyRate: 40000,
      baseHours: 2,
      fees: [PriceLine('Muatan - Sedang', 10000)],
    );
    expect(price.baseCost, 80000);
    expect(price.feeCost, 10000);
    expect(price.total, 90000);
  });

  test('detail form ditulis ke task_description dan terbaca lagi', () {
    final text = householdOrderDescription(_draft(hours: 2));
    final parsed = OrderDescription.parse(text);

    expect(parsed.title, 'Household - Rumah');
    expect(parsed.valueOf('Ukuran'), 'L: 10 m, P: 10 m');
    expect(parsed.valueOf('Ketersediaan alat'), 'Alat disediakan');
    expect(parsed.valueOf('Waktu pengerjaan'), 'Sekarang');
    expect(parsed.durationHours, 2);
  });

  test('hitung mundur', () {
    expect(countdownLabel(const Duration(minutes: 54, seconds: 23)), '54:23');
    expect(
      countdownLabel(const Duration(hours: 1, minutes: 4, seconds: 5)),
      '1:04:05',
    );
  });

  test('ukuran meter: koma atau titik, ditampilkan dengan koma', () {
    expect(parseMeter('3,5'), 3.5);
    expect(parseMeter('3.5'), 3.5);
    expect(parseMeter(''), isNull);
    expect(meterLabel(10), '10');
    expect(meterLabel(3.5), '3,5');
  });

  testWidgets('kolom ukuran menerima desimal, menolak angka tak wajar', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const HouseOrderFormPage(
        service: HouseholdService.kamar,
        category: _household,
      ),
    );
    await tester.pumpAndSettle();
    final width = find.byType(TextField).first;

    await tester.enterText(width, '3,5');
    expect(find.text('3,5'), findsOneWidget);

    // 4 digit bulat atau 2 desimal ditolak; isian lama dipertahankan.
    await tester.enterText(width, '1250');
    expect(find.text('3,5'), findsOneWidget);
    await tester.enterText(width, '3,55');
    expect(find.text('3,5'), findsOneWidget);
  });

  testWidgets('Lanjut Pesan baru aktif setelah form lengkap', (tester) async {
    await pumpPage(
      tester,
      const HouseOrderFormPage(
        service: HouseholdService.rumah,
        category: _household,
      ),
    );
    await tester.pumpAndSettle();

    ElevatedButton button() => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Lanjut Pesan'),
    );

    // Belum ada helper: total = tarif dasar kategori, tombol mati.
    expect(find.text('Rp 5.000'), findsOneWidget);
    expect(button().onPressed, isNull);
  });

  group('daftar helper', () {
    testWidgets('dari GET /helpers kategori ini; filter Task 1000+', (
      tester,
    ) async {
      final helpers = FakeHelperRepository();
      await pumpPage(
        tester,
        const HourlyHelperListPage(categoryId: 3),
        helperRepo: helpers,
      );
      await tester.pumpAndSettle();

      expect(helpers.requested, [3]);
      expect(find.text('Jarak 1,2 km'), findsOneWidget);
      expect(find.text('Jarak 3,4 km'), findsOneWidget);

      // Chip paling kanan belum dibangun ListView; geser baris chip dulu.
      await tester.dragUntilVisible(
        find.text('Task 1000+'),
        find.byType(ListView).first,
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task 1000+'));
      await tester.pumpAndSettle();

      expect(find.text('Jarak 1,2 km'), findsOneWidget);
      expect(find.text('Jarak 3,4 km'), findsNothing);
    });

    testWidgets('kosong: tidak ada helper di sekitar', (tester) async {
      await pumpPage(
        tester,
        const HourlyHelperListPage(categoryId: 3),
        helperRepo: FakeHelperRepository(hourlyResult: []),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada helper di sekitarmu'), findsOneWidget);
    });

    testWidgets('gagal dimuat: bisa dicoba lagi', (tester) async {
      final helpers = FakeHelperRepository(
        error: const ApiException(
          code: 'NETWORK_ERROR',
          message: 'Tidak ada koneksi internet.',
        ),
      );
      await pumpPage(
        tester,
        const HourlyHelperListPage(categoryId: 3),
        helperRepo: helpers,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada koneksi internet.'), findsOneWidget);

      helpers.error = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Agus Nomercy'), findsOneWidget);
    });
  });

  testWidgets('Aktifitas: pesanan berjalan dan riwayat dari server', (
    tester,
  ) async {
    final orders = FakeOrderRepository(
      orders: [
        FakeOrderRepository.sample(id: 2, status: OrderStatus.onTheWay),
        FakeOrderRepository.sample(
          id: 1,
          status: OrderStatus.cancelledByClient,
        ),
      ],
    );
    await pumpPage(
      tester,
      const Scaffold(body: ActivityView()),
      orderRepo: orders,
    );
    await tester.pumpAndSettle();

    expect(find.text('Household - Rumah'), findsOneWidget);
    expect(find.text('Helper menuju lokasi'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Household - Rumah'), findsOneWidget);
    expect(find.text('Dibatalkan'), findsOneWidget);
  });

  group('Pesan', () {
    testWidgets('konfirmasi, saldo cukup, pesanan dibuat ke helper itu, '
        'lalu Detail Pesanan', (tester) async {
      final orders = FakeOrderRepository(addresses: testAddresses);
      await pumpPage(
        tester,
        OrderReviewPage(draft: _draft(), category: _household),
        orderRepo: orders,
        walletRepo: FakeWalletRepository(balance: 500000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pesan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Apakah kamu sudah yakin\ndengan pesananmu?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Sudah'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderSuccessPage), findsOneWidget);
      expect(find.text('Household - Rumah'), findsOneWidget);
      expect(find.text('TD-Wallet'), findsOneWidget);

      final body = orders.created.single;
      expect(body['category_id'], 3);
      expect(body['helper_id'], 'h-1');
      expect(body['client_estimated_price'], 40000);
      // Rumah: alamat jadi tujuan, tanpa lokasi jemput.
      expect(body['destination_address_id'], 11);
      expect(body['pickup_address_id'], isNull);

      await tester.tap(find.text('Lihat Pesanan'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailPage), findsOneWidget);
      expect(find.text('Menunggu helper menerima'), findsOneWidget);
    });

    testWidgets('saldo kurang: diajak isi saldo, pesanan tidak dibuat', (
      tester,
    ) async {
      final orders = FakeOrderRepository();
      await pumpPage(
        tester,
        OrderReviewPage(draft: _draft(), category: _household),
        orderRepo: orders,
        walletRepo: FakeWalletRepository(balance: 10000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pesan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sudah'));
      await tester.pumpAndSettle();

      expect(find.text('Saldo TD-Wallet kurang'), findsOneWidget);
      await tester.tap(find.text('Nanti'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderReviewPage), findsOneWidget);
      expect(orders.created, isEmpty);
    });

    testWidgets('Kembali di dialog tidak membuat pesanan', (tester) async {
      final orders = FakeOrderRepository();
      await pumpPage(
        tester,
        OrderReviewPage(draft: _draft(), category: _household),
        orderRepo: orders,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pesan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderReviewPage), findsOneWidget);
      expect(orders.created, isEmpty);
    });

    testWidgets('ditolak server: pesannya tampil, tetap di halaman ini', (
      tester,
    ) async {
      final orders = FakeOrderRepository()
        ..failNextCreate = const ApiException(
          code: 'HELPER_UNAVAILABLE',
          message: 'Helper sedang tidak tersedia.',
        );
      await pumpPage(
        tester,
        OrderReviewPage(draft: _draft(), category: _household),
        orderRepo: orders,
        walletRepo: FakeWalletRepository(balance: 500000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pesan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sudah'));
      await tester.pumpAndSettle();

      expect(find.text('Helper sedang tidak tersedia.'), findsOneWidget);
      expect(find.byType(OrderReviewPage), findsOneWidget);
    });
  });
}
