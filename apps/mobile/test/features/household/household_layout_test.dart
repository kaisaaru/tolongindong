import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/household/active_order_page.dart';
import 'package:mobile/features/household/address_picker_page.dart';
import 'package:mobile/features/household/extend_duration_page.dart';
import 'package:mobile/features/household/hourly_helper_list_page.dart';
import 'package:mobile/features/household/house_order_form_page.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/household/household_page.dart';
import 'package:mobile/features/household/household_samples.dart';
import 'package:mobile/features/household/order_review_page.dart';
import 'package:mobile/features/household/widgets/household_widgets.dart';
import 'package:mobile/features/order/order_samples.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/features/order/payment_method_page.dart';
import 'package:mobile/models/service_category.dart';
import 'package:mobile/theme/app_theme.dart';

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

final _draft = HouseholdOrderDraft(
  service: HouseholdService.rumah,
  address: HouseholdSamples.savedAddresses.last, // alamat terpanjang
  widthM: 10,
  lengthM: 10,
  tools: ToolOption.notProvided,
  helper: HouseholdSamples.helpers.first,
  hours: 1,
);

/// Render [page] di layar HP sempit (360x740). Overflow apa pun membuat
/// test gagal, jadi ini menjaga tata letak tidak meluap di layar kecil.
Future<void> _pumpNarrow(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
  await tester.pump();
}

void main() {
  testWidgets('kategori Household', (tester) async {
    await _pumpNarrow(tester, const HouseholdPage(category: _household));
    expect(find.text('Kategori Kebutuhan'), findsOneWidget);
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

  testWidgets('pilih alamat, tab Tersimpan', (tester) async {
    await _pumpNarrow(tester, const AddressPickerPage());
    await tester.tap(find.text('Tersimpan'));
    await tester.pump();
    expect(find.text('Tambah alamat baru'), findsOneWidget);
  });

  testWidgets('daftar helper', (tester) async {
    await _pumpNarrow(tester, const HourlyHelperListPage());
    expect(find.text('Daftar Helper'), findsOneWidget);
  });

  testWidgets('detail pesanan dengan rincian terbuka', (tester) async {
    await _pumpNarrow(tester, OrderReviewPage(draft: _draft));
    await tester.tap(find.text('Total'));
    await tester.pump();
    expect(find.text('Biaya Helper'), findsOneWidget);
  });

  testWidgets('metode pembayaran', (tester) async {
    await _pumpNarrow(tester, const PaymentMethodPage());
    expect(find.text('Mandiri'), findsWidgets);
  });

  group('pesanan aktif', () {
    late DateTime real;
    late OrderStore store;

    setUp(() {
      real = DateTime(2026, 10, 21, 9, 45);
      store = OrderStore(clock: () => real);
      store.place(
        draft: _draft,
        payment: HouseholdSamples.paymentMethods.first,
        voucher: OrderSamples.vouchers.first,
      );
    });

    tearDown(() => store.reset());

    testWidgets('menuju lokasi, masih bisa batal', (tester) async {
      await _pumpNarrow(tester, ActiveOrderPage(store: store));
      expect(find.bySemanticsLabel('Batalkan pesanan'), findsOneWidget);
      expect(find.text('Estimasi sampai'), findsOneWidget);
    });

    testWidgets('jendela batal habis: bar hilang dengan animasi', (
      tester,
    ) async {
      await _pumpNarrow(tester, ActiveOrderPage(store: store));
      expect(find.bySemanticsLabel('Batalkan pesanan'), findsOneWidget);

      // 11 detik nyata = 11 menit pesanan, lewat dari jendela 10 menit.
      real = real.add(const Duration(seconds: 11));
      await tester.pump(const Duration(seconds: 1)); // tick store
      await tester.pump(const Duration(milliseconds: 400)); // animasi

      expect(find.bySemanticsLabel('Batalkan pesanan'), findsNothing);
      expect(find.text('Estimasi sampai'), findsOneWidget);
    });

    testWidgets('bekerja: hitung mundur lalu detail', (tester) async {
      real = real.add(const Duration(seconds: 31)); // 31 menit pesanan
      await _pumpNarrow(tester, ActiveOrderPage(store: store));
      expect(find.text('Durasi tersisa'), findsOneWidget);

      await tester.tap(find.text('Lihat detail pesanan'));
      await tester.pump();
      expect(find.text('Selesai di jam'), findsOneWidget);
    });

    testWidgets('tambah durasi', (tester) async {
      real = real.add(const Duration(seconds: 31));
      await _pumpNarrow(tester, ExtendDurationPage(store: store));
      expect(find.text('Biaya tambahan'), findsOneWidget);
    });

    testWidgets('selesai: beri rating', (tester) async {
      real = real.add(const Duration(seconds: 120));
      await _pumpNarrow(tester, ActiveOrderPage(store: store));
      expect(find.text('Beri reting helper'), findsOneWidget);
    });
  });
}
