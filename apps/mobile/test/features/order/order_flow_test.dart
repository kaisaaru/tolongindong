import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/format/rupiah.dart';
import 'package:mobile/features/order/category_helpers_page.dart';
import 'package:mobile/features/order/checkout_page.dart';
import 'package:mobile/features/order/helper_detail_page.dart';
import 'package:mobile/features/order/order_models.dart';
import 'package:mobile/features/order/order_samples.dart';
import 'package:mobile/models/service_category.dart';

import '../../helpers/pump_page.dart';

const _personal = ServiceCategory(
  id: 1,
  code: 'personal',
  name: 'Personal',
  baseFee: 10000,
  requiresAdvance: false,
  requiresProofPhoto: false,
  requiresPickupAddress: false,
  requiresDestinationAddress: false,
);

void main() {
  test('rupiah memakai titik ribuan dan tanda minus di depan', () {
    expect(rupiah(30000), 'Rp 30.000');
    expect(rupiah(150000), 'Rp 150.000');
    expect(rupiah(40000, spaced: false), 'Rp40.000');
    expect(rupiah(-2000, spaced: false), '-Rp2.000');
    expect(rupiah(0), 'Rp 0');
  });

  test('potongan voucher dibatasi maxDiscount dan harga', () {
    const voucher = Voucher(
      id: 'v',
      title: 'Diskon 20%',
      description: '',
      validUntil: '',
      percent: 20,
      maxDiscount: 2000,
    );
    expect(voucher.discountFor(40000), 2000); // 8.000 dipotong ke 2.000
    expect(voucher.discountFor(5000), 1000); // di bawah batas
    expect(voucher.discountFor(0), 0);
  });

  testWidgets('chip sub-kategori menyaring daftar helper', (tester) async {
    await pumpPage(tester, const CategoryHelpersPage(category: _personal));
    await tester.pumpAndSettle();

    expect(find.text('Agus Nomercy'), findsWidgets);
    expect(find.text('Reomeo Asgar'), findsWidgets);

    // Chip ini di luar layar 412 dp (baris chip bisa digeser, seperti desain).
    await tester.ensureVisible(find.text('Tugas Kuliah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tugas Kuliah'));
    await tester.pumpAndSettle();

    expect(find.text('Agus Nomercy'), findsNothing);
    expect(find.text('Reomeo Asgar'), findsWidgets);
  });

  testWidgets('pencarian cocok ke label keahlian', (tester) async {
    await pumpPage(tester, const CategoryHelpersPage(category: _personal));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kalkulus');
    await tester.pumpAndSettle();

    expect(find.text('Agus Nomercy'), findsNothing);
    expect(find.text('Reomeo Asgar'), findsOneWidget);
  });

  testWidgets('kategori tanpa data menampilkan keadaan kosong', (tester) async {
    await pumpPage(
      tester,
      const CategoryHelpersPage(
        category: ServiceCategory(
          id: 2,
          code: 'delivery',
          name: 'Delivery',
          baseFee: 0,
          requiresAdvance: false,
          requiresProofPhoto: false,
          requiresPickupAddress: true,
          requiresDestinationAddress: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada helper di kategori ini.'), findsOneWidget);
  });

  testWidgets('kartu helper membuka detail', (tester) async {
    await pumpPage(tester, const CategoryHelpersPage(category: _personal));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reomeo Asgar').first);
    await tester.pumpAndSettle();

    expect(find.byType(HelperDetailPage), findsOneWidget);
    expect(find.text('Tentang'), findsOneWidget);
  });

  testWidgets('checkout menolak pesan tanpa metode pembayaran', (tester) async {
    final helper = OrderSamples.listingsFor(
      'personal',
    ).firstWhere((h) => h.price == 40000);
    await pumpPage(tester, CheckoutPage(helper: helper));
    await tester.pumpAndSettle();

    expect(find.text('Rp 40.000'), findsOneWidget); // total di bilah bawah

    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pump();

    expect(find.text('Pilih metode pembayaran dulu.'), findsOneWidget);
  });
}
