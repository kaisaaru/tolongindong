import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/household/active_order_page.dart';
import 'package:mobile/features/household/house_order_form_page.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/household/household_samples.dart';
import 'package:mobile/features/household/move_order_form_page.dart';
import 'package:mobile/features/household/order_review_page.dart';
import 'package:mobile/features/household/route_picker_page.dart';
import 'package:mobile/features/household/widgets/household_widgets.dart';
import 'package:mobile/features/order/order_samples.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/models/service_category.dart';

import '../../helpers/pump_page.dart';

const _household = ServiceCategory(
  id: 3,
  code: 'household',
  name: 'Household',
  baseFee: 5000,
  requiresAdvance: false,
  requiresProofPhoto: false,
  requiresPickupAddress: false,
  requiresDestinationAddress: false,
);

/// Pesanan seperti frame 177: muatan Sedang, termasuk kendaraan, helper
/// Rp40.000/jam.
final _moveDraft = HouseholdOrderDraft(
  service: HouseholdService.pindahan,
  address: HouseholdSamples.currentLocation,
  destination: HouseholdSamples.savedAddresses.last, // alamat terpanjang
  load: LoadOption.moving[1], // Sedang

  fleet: FleetOption.withVehicle,
  helper: HouseholdSamples.helpers.first,
  hours: 1,
);

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  Size size, {
  OrderStore? orderStore,
}) async {
  await pumpPage(tester, page, size: size, orderStore: orderStore);
  await tester.pump();
}

/// Layar HP sempit: overflow apa pun membuat test gagal.
Future<void> _pumpNarrow(
  WidgetTester tester,
  Widget page, {
  OrderStore? orderStore,
}) => _pump(tester, page, const Size(360, 740), orderStore: orderStore);

void main() {
  group('biaya Pindahan', () {
    test('muatan + kendaraan + helper = Rp110.000 seperti desain', () {
      final price = PriceBreakdown(
        hourlyRate: 40000,
        baseHours: 1,
        extraHours: const [],
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

    test('voucher dihitung dari biaya awal, tambahan durasi tidak', () {
      final price = PriceBreakdown(
        hourlyRate: 40000,
        baseHours: 1,
        extraHours: const [1],
        fees: _moveDraft.fees,
        voucher: OrderSamples.vouchers.first, // 20%, maks Rp10.000
      );
      expect(price.discount, 10000);
      expect(price.total, 110000 - 10000 + 40000);
    });

    test('pesanan aktif membawa biaya tambahan', () {
      final store = OrderStore(clock: () => DateTime(2026, 10, 22, 9));
      addTearDown(store.reset);
      store.place(
        draft: _moveDraft,
        payment: HouseholdSamples.paymentMethods.first,
      );
      expect(store.active!.price.total, 110000);
      store.addHours(1);
      expect(store.active!.price.total, 150000);
    });
  });

  testWidgets('form: pilih tujuan, lokasi awal terisi lokasi saat ini', (
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

    await tester.tap(find.text('KOST BUMISAKA'));
    await tester.pumpAndSettle();

    expect(find.byType(RoutePickerPage), findsNothing);
    expect(
      find.text(HouseholdSamples.currentLocation.fullAddress),
      findsOneWidget,
    );
    expect(
      find.text(HouseholdSamples.recentAddresses[1].fullAddress),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('Sedang (4–8 Kardus)'));
    await tester.tap(find.text('Termasuk kendaraan'));
    await tester.tap(find.text('Sekarang'));
    await tester.pump();

    // Helper belum dipilih: total masih tarif dasar, tombol masih mati.
    expect(find.text('Rp 5.000'), findsOneWidget);
    expect(button().onPressed, isNull);
  });

  testWidgets('rute: lokasi awal dan tujuan tidak boleh sama', (tester) async {
    await _pumpNarrow(tester, const RoutePickerPage());

    // Kolom tujuan aktif; lokasi awal sudah "Lokasi saat ini".
    await tester.tap(find.text('Lokasi saat ini'));
    await tester.pump();

    expect(
      find.text('Lokasi awal dan tujuan tidak boleh sama.'),
      findsOneWidget,
    );
    expect(find.byType(RoutePickerPage), findsOneWidget);
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
      expect(find.text('Lokasi saat ini'), findsOneWidget);
    });

    testWidgets('detail pesanan dengan rincian terbuka', (tester) async {
      await _pumpNarrow(tester, OrderReviewPage(draft: _moveDraft));
      expect(find.text('Lokasi awal'), findsOneWidget);
      expect(find.text('Lokasi tujuan'), findsOneWidget);
      expect(find.text('Termasuk kendaraan'), findsOneWidget);

      await tester.tap(find.text('Total'));
      await tester.pump();
      expect(find.text('Muatan - Sedang'), findsOneWidget);
      expect(find.text('Kendaraan'), findsOneWidget);
      expect(find.text('Rp110.000'), findsOneWidget);
    });

    testWidgets('pesanan aktif', (tester) async {
      final store = OrderStore(clock: () => DateTime(2026, 10, 22, 9));
      store.place(
        draft: _moveDraft,
        payment: HouseholdSamples.paymentMethods.first,
      );

      await _pumpNarrow(tester, ActiveOrderPage(), orderStore: store);
      expect(find.text('Lokasi tujuan'), findsOneWidget);
      expect(find.text('Muatan - Sedang'), findsOneWidget);

      // Hentikan ticker store sebelum test selesai.
      store.reset();
    });
  });
}
