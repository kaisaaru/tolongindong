import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/household/address_picker_page.dart';
import 'package:mobile/features/household/hourly_helper_list_page.dart';
import 'package:mobile/features/household/house_order_form_page.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/household/household_page.dart';
import 'package:mobile/features/household/order_review_page.dart';
import 'package:mobile/features/household/widgets/household_widgets.dart';
import 'package:mobile/features/order/order_detail_page.dart';
import 'package:mobile/features/order/order_repository.dart';
import 'package:mobile/theme/app_theme.dart';

import '../../helpers/fake_order_repository.dart';
import '../../helpers/pump_page.dart';
import '../../helpers/test_data.dart';

const _household = testHousehold;

final _draft = HouseholdOrderDraft(
  service: HouseholdService.rumah,
  address: testHome,
  widthM: 10,
  lengthM: 10,
  tools: ToolOption.notProvided,
  helper: testHelpers.first,
  hours: 1,
);

/// Render [page] di layar HP sempit (360x740). Overflow apa pun membuat
/// test gagal, jadi ini menjaga tata letak tidak meluap di layar kecil.
Future<void> _pumpNarrow(
  WidgetTester tester,
  Widget page, {
  FakeOrderRepository? orderRepo,
}) async {
  await pumpPage(
    tester,
    page,
    size: const Size(360, 740),
    orderRepo: orderRepo,
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('kategori Household', (tester) async {
    await _pumpNarrow(tester, const HouseholdPage(category: _household));
    expect(find.text('Kategori Kebutuhan'), findsOneWidget);
  });

  testWidgets('ubin layanan tetap persegi di layar 320 dp', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const HouseholdPage(category: _household),
      ),
    );

    final icon = find.byIcon(HouseholdService.pindahan.icon);
    final tile = find.ancestor(of: icon, matching: find.byType(Container));
    final size = tester.getSize(tile.first);
    expect(size.width, size.height);
    expect(size.width, lessThan(73));
  });

  testWidgets('header mengikuti ukuran desain di bawah status bar', (
    tester,
  ) async {
    // Status bar setinggi iPhone dengan Dynamic Island.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const HouseOrderFormPage(
          service: HouseholdService.rumah,
          category: _household,
        ),
      ),
    );
    await tester.pump();

    final back = find.bySemanticsLabel('Kembali');
    expect(tester.getCenter(back).dy, 47 + 33);
    expect(tester.getBottomLeft(find.byType(ColoredHeader)).dy, 47 + 95);
    // Label ukuran tampil utuh, tidak terpotong.
    expect(find.text('Panjang:'), findsOneWidget);
  });

  testWidgets('form Rumah', (tester) async {
    await _pumpNarrow(
      tester,
      const HouseOrderFormPage(
        service: HouseholdService.rumah,
        category: _household,
      ),
    );
    expect(find.text('Alamat Rumah'), findsOneWidget);
  });

  testWidgets('pilih alamat: alamat tersimpan dan Tambah alamat baru', (
    tester,
  ) async {
    await _pumpNarrow(tester, const AddressPickerPage());
    expect(find.text('Tersimpan'), findsOneWidget);
    expect(find.text(testOffice.fullAddress), findsOneWidget);
    expect(find.text('Tambah alamat baru'), findsOneWidget);
  });

  testWidgets('daftar helper', (tester) async {
    await _pumpNarrow(tester, const HourlyHelperListPage(categoryId: 3));
    expect(find.text('Daftar Helper'), findsOneWidget);
  });

  testWidgets('detail pesanan dengan rincian terbuka', (tester) async {
    await _pumpNarrow(
      tester,
      OrderReviewPage(draft: _draft, category: _household),
    );
    await tester.tap(find.text('Total'));
    await tester.pump();
    expect(find.text('Biaya Helper'), findsOneWidget);
  });

  group('pesanan berjalan', () {
    final start = DateTime(2026, 10, 22, 9);

    FakeOrderRepository repo(OrderStatus status) => FakeOrderRepository(
      orders: [
        FakeOrderRepository.sample(
          status: status,
          description: householdOrderDescription(_draft),
          destination: testHome,
          history: [
            (status: OrderStatus.accepted, at: start),
            if (status == OrderStatus.inProgress)
              (status: OrderStatus.inProgress, at: start),
          ],
        ),
      ],
    );

    testWidgets('menunggu helper: bisa batal', (tester) async {
      await _pumpNarrow(
        tester,
        const OrderDetailPage(orderId: 1),
        orderRepo: repo(OrderStatus.awaitingQuote),
      );
      expect(find.text('Menunggu helper menerima'), findsOneWidget);
      expect(find.text('Batalkan Pesanan'), findsOneWidget);
    });

    testWidgets('dikerjakan: hitung mundur durasi', (tester) async {
      await _pumpNarrow(
        tester,
        OrderDetailPage(
          orderId: 1,
          clock: () => start.add(const Duration(minutes: 5, seconds: 37)),
        ),
        orderRepo: repo(OrderStatus.inProgress),
      );
      expect(find.text('Durasi tersisa'), findsOneWidget);
      expect(find.text('54:23'), findsOneWidget);
      expect(find.text('Pesanan Selesai'), findsOneWidget);
      // Sedang dikerjakan: tidak bisa dibatalkan dari app.
      expect(find.text('Batalkan Pesanan'), findsNothing);
    });

    testWidgets('durasi habis', (tester) async {
      await _pumpNarrow(
        tester,
        OrderDetailPage(
          orderId: 1,
          clock: () => start.add(const Duration(hours: 2)),
        ),
        orderRepo: repo(OrderStatus.inProgress),
      );
      expect(find.text('Waktu helper sudah habis'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });
  });
}
