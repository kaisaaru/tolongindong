import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/household/house_order_form_page.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/household/move_order_form_page.dart';
import 'package:mobile/features/household/order_review_page.dart';
import 'package:mobile/features/household/route_picker_page.dart';
import 'package:mobile/features/household/widgets/household_widgets.dart';
import 'package:mobile/features/order/order_detail_page.dart';
import 'package:mobile/features/order/order_repository.dart';

import '../../helpers/fake_order_repository.dart';
import '../../helpers/fake_wallet_repository.dart';
import '../../helpers/pump_page.dart';
import '../../helpers/test_data.dart';

const _household = testHousehold;

/// Pesanan seperti frame 177: muatan Sedang, termasuk kendaraan, helper
/// Rp40.000/jam.
final _moveDraft = HouseholdOrderDraft(
  service: HouseholdService.pindahan,
  address: testHome,
  destination: testOffice,
  load: LoadOption.moving[1], // Sedang
  fleet: FleetOption.withVehicle,
  helper: testHelpers.first,
  hours: 1,
);

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  Size size, {
  FakeOrderRepository? orderRepo,
}) async {
  await pumpPage(
    tester,
    page,
    size: size,
    orderRepo: orderRepo,
    walletRepo: FakeWalletRepository(balance: 500000),
  );
  await tester.pumpAndSettle();
}

/// Layar HP sempit: overflow apa pun membuat test gagal.
Future<void> _pumpNarrow(
  WidgetTester tester,
  Widget page, {
  FakeOrderRepository? orderRepo,
}) => _pump(tester, page, const Size(360, 740), orderRepo: orderRepo);

void main() {
  group('biaya Pindahan', () {
    test('muatan + kendaraan + helper = Rp110.000 seperti desain', () {
      final price = PriceBreakdown(
        hourlyRate: 40000,
        baseHours: 1,
        fees: _moveDraft.fees,
      );
      expect(
        [for (final f in price.fees) '${f.label}=${f.amount}'],
        ['Muatan - Sedang=20000', 'Kendaraan=50000'],
      );
      expect(price.total, 110000);
    });

    test('biaya Rp 0 tidak jadi baris', () {
      expect(
        extraFees(LoadOption.moving.first, FleetOption.laborOnly),
        isEmpty,
      );
    });
  });

  testWidgets('form: pilih tujuan lalu asal dari alamat tersimpan', (
    tester,
  ) async {
    // Layar tinggi supaya seluruh form terlihat tanpa menggulir.
    await _pump(
      tester,
      const MoveOrderFormPage(category: _household),
      const Size(412, 1400),
    );

    ElevatedButton button() => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Lanjut Pesan'),
    );
    expect(find.text('Rp 5.000'), findsOneWidget);
    expect(button().onPressed, isNull);

    await tester.tap(find.text('Mau dianter kemana'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutePickerPage), findsOneWidget);

    // Kolom tujuan aktif dulu; setelah terisi, giliran lokasi awal.
    await tester.tap(find.text('Kantor'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutePickerPage), findsOneWidget);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();

    expect(find.byType(RoutePickerPage), findsNothing);
    expect(find.text(testHome.fullAddress), findsOneWidget);
    expect(find.text(testOffice.fullAddress), findsOneWidget);

    await tester.tap(find.textContaining('Sedang (4–8 Kardus)'));
    await tester.tap(find.text('Termasuk kendaraan'));
    await tester.tap(find.text('Sekarang'));
    await tester.pump();

    // Helper belum dipilih: total masih tarif dasar, tombol masih mati.
    expect(find.text('Rp 5.000'), findsOneWidget);
    expect(button().onPressed, isNull);
  });

  testWidgets('rute: lokasi awal dan tujuan tidak boleh sama', (tester) async {
    await _pumpNarrow(tester, const RoutePickerPage(origin: testHome));

    // Kolom tujuan aktif; lokasi awal sudah Rumah.
    await tester.tap(find.text('Rumah'));
    await tester.pump();

    expect(
      find.text('Lokasi awal dan tujuan tidak boleh sama.'),
      findsOneWidget,
    );
    expect(find.byType(RoutePickerPage), findsOneWidget);
  });

  testWidgets('Pesan Pindahan: asal jadi lokasi jemput', (tester) async {
    final orders = FakeOrderRepository(addresses: testAddresses);
    await _pump(
      tester,
      OrderReviewPage(draft: _moveDraft, category: _household),
      const Size(412, 917),
      orderRepo: orders,
    );

    await tester.tap(find.text('Pesan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah'));
    await tester.pumpAndSettle();

    final body = orders.created.single;
    expect(body['pickup_address_id'], testHome.id);
    expect(body['destination_address_id'], testOffice.id);
    expect(body['client_estimated_price'], 110000);
    final parsed = OrderDescription.parse(body['task_description']! as String);
    expect(parsed.title, 'Household - Pindahan');
    expect(parsed.valueOf('Kebutuhan armada'), 'Termasuk kendaraan');
  });

  for (final (name, page) in [
    ('Pindahan', const MoveOrderFormPage(category: _household)),
    (
      'Rumah',
      const HouseOrderFormPage(
        service: HouseholdService.rumah,
        category: _household,
      ),
    ),
  ]) {
    testWidgets('kartu waktu selebar form ($name)', (tester) async {
      await _pump(tester, page, const Size(412, 1400));

      final formWidth = tester.getSize(find.byType(HelperPickerField)).width;
      for (final title in ['Sekarang', 'Terjadwal']) {
        expect(
          tester.getSize(find.widgetWithText(SelectCard, title)).width,
          formWidth,
        );
      }
    });
  }

  group('tata letak sempit', () {
    testWidgets('form Pindahan', (tester) async {
      await _pumpNarrow(tester, const MoveOrderFormPage(category: _household));
      expect(find.text('Alamat Asal & Tujuan'), findsOneWidget);
    });

    testWidgets('pilih rute', (tester) async {
      await _pumpNarrow(tester, const RoutePickerPage());
      expect(find.text('Tersimpan'), findsOneWidget);
      expect(find.text('Rumah'), findsOneWidget);
    });

    testWidgets('detail pesanan dengan rincian terbuka', (tester) async {
      await _pumpNarrow(
        tester,
        OrderReviewPage(draft: _moveDraft, category: _household),
      );
      expect(find.text('Lokasi awal'), findsOneWidget);
      expect(find.text('Lokasi tujuan'), findsOneWidget);
      expect(find.text('Termasuk kendaraan'), findsOneWidget);

      await tester.tap(find.text('Total'));
      await tester.pump();
      expect(find.text('Muatan - Sedang'), findsOneWidget);
      expect(find.text('Kendaraan'), findsOneWidget);
      expect(find.text('Rp110.000'), findsOneWidget);
    });

    testWidgets('pesanan berjalan', (tester) async {
      final orders = FakeOrderRepository(
        orders: [
          FakeOrderRepository.sample(
            status: OrderStatus.onTheWay,
            description: householdOrderDescription(_moveDraft),
            price: 110000,
            pickup: testHome,
            destination: testOffice,
          ),
        ],
      );
      await _pumpNarrow(
        tester,
        const OrderDetailPage(orderId: 1),
        orderRepo: orders,
      );
      expect(find.text('Lokasi jemput'), findsOneWidget);
      expect(find.text('Lokasi tujuan'), findsOneWidget);
      expect(find.text('Termasuk kendaraan'), findsOneWidget);
    });
  });
}
