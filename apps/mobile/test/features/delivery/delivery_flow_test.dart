import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/delivery/delivery_models.dart';
import 'package:mobile/features/delivery/delivery_page.dart';
import 'package:mobile/features/delivery/delivery_review_page.dart';
import 'package:mobile/features/delivery/recipient_form_page.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/order/order_detail_page.dart';
import 'package:mobile/features/order/order_repository.dart';
import 'package:mobile/features/order/order_success_page.dart';
import 'package:mobile/models/auth_user.dart';

import '../../helpers/fake_helper_repository.dart';
import '../../helpers/fake_order_repository.dart';
import '../../helpers/fake_wallet_repository.dart';
import '../../helpers/pump_page.dart';
import '../../helpers/test_data.dart';

/// Pukul 09.47 seperti status bar di desain.
DateTime _now() => DateTime(2026, 10, 22, 9, 47);

/// Pengirim = pengguna yang masuk.
const _sender = AuthUser(
  id: 'uuid-2',
  fullName: 'Alexsander',
  email: 'alex@example.com',
  phoneNumber: '08123543431',
  photoUrl: null,
  verificationStatus: VerificationStatus.verified,
  isAdmin: false,
  wallet: Wallet.empty,
);

DeliveryPage _page() => DeliveryPage(category: testDelivery, clock: _now);

const _draft = DeliveryDraft(
  senderName: 'Alexsander',
  senderPhone: '08123543431',
  origin: testHome,
  destination: testOffice,
  recipient: Recipient(name: 'Agus', phone: '08123541453'),
  schedule: DeliverySchedule.now(),
  item: DeliveryItem(size: ItemSize.m, weightKg: 2, type: ItemType.makanan),
  fee: 20000,
);

/// Satu pengantaran ke Kantor 4 hari lalu.
FakeOrderRepository _withPastDelivery() => FakeOrderRepository(
  addresses: testAddresses,
  orders: [
    FakeOrderRepository.sample(
      status: OrderStatus.completed,
      categoryCode: 'delivery',
      description: 'Delivery - Dokumen',
      pickup: testHome,
      destination: testOffice,
      createdAt: _now().subtract(const Duration(days: 4)),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(412, 1100),
  FakeOrderRepository? orderRepo,
  FakeHelperRepository? helperRepo,
}) async {
  await pumpPage(
    tester,
    page,
    size: size,
    orderRepo: orderRepo ?? _withPastDelivery(),
    helperRepo: helperRepo,
    walletRepo: FakeWalletRepository(balance: 500000),
    user: _sender,
  );
  await tester.pumpAndSettle();
}

ElevatedButton _button(WidgetTester tester, String label) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, label));

void main() {
  group('model', () {
    test('antar sekarang pukul 09.47 -> sebelum 11.00', () {
      expect(deliverBy(_now()), DateTime(2026, 10, 22, 11));
      final labels = scheduleLabels(const DeliverySchedule.now(), _now());
      expect(labels.subtitle, 'Diantar sebelum jam 11.00');
    });

    test('jadwal antar nanti seperti desain', () {
      final labels = scheduleLabels(
        DeliverySchedule.at(
          TimeSlot(day: DateTime(2026, 10, 21), startHour: 8),
        ),
        _now(),
      );
      expect(labels.subtitle, 'Jadwal: 21 Okt 2026 - 08.00-09.00');
    });

    test('waktu relatif pengantaran sebelumnya', () {
      final now = _now();
      expect(
        timeAgoLabel(now.subtract(const Duration(days: 4)), now),
        '4 hari lalu',
      );
      expect(
        timeAgoLabel(now.subtract(const Duration(days: 90)), now),
        '3 bulan lalu',
      );
    });

    test('penerima dan barang ditulis ke task_description', () {
      final parsed = OrderDescription.parse(
        deliveryOrderDescription(_draft, _now()),
      );
      expect(parsed.title, 'Delivery - Makanan');
      expect(parsed.valueOf('Penerima'), 'Agus');
      expect(parsed.valueOf('Kontak penerima'), '08123541453');
      expect(parsed.valueOf('Ukuran'), 'Ukuran M, berat 2 kg');
      expect(parsed.valueOf('Waktu antar'), 'Diantar sebelum jam 11.00');
      // Kosong tidak ditulis.
      expect(parsed.valueOf('Catatan pengemudi'), isNull);
    });
  });

  testWidgets('landing: asal = alamat utama, tujuan dari pesanan lalu', (
    tester,
  ) async {
    await _pump(tester, _page());

    expect(find.text(testHome.fullAddress), findsOneWidget);
    expect(find.text('Pengantaran sebelumnya'), findsOneWidget);
    expect(find.text(testOffice.fullAddress), findsOneWidget);
    expect(find.text('4 hari lalu'), findsOneWidget);
    expect(find.text('Promo pengiriman'), findsNothing);
  });

  testWidgets('landing tanpa riwayat pengantaran', (tester) async {
    await _pump(tester, _page(), orderRepo: FakeOrderRepository());
    expect(find.text('Pengantaran sebelumnya'), findsNothing);
    expect(
      find.text('Pilih alamat tujuan untuk mulai mengirim barang.'),
      findsOneWidget,
    );
  });

  testWidgets('voucher belum bisa dipakai', (tester) async {
    await _pump(tester, _page());
    // Kartu voucher muncul setelah tujuan dipilih.
    await tester.tap(find.text('4 hari lalu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voucher belum bisa dipakai'));
    await tester.pump();
    expect(
      find.text('Voucher belum bisa dipakai untuk pesanan.'),
      findsOneWidget,
    );
  });

  testWidgets('form lengkap sampai pesanan ke kurir terdekat', (tester) async {
    final orders = _withPastDelivery()..fee = 23500;
    final helpers = FakeHelperRepository();
    await _pump(tester, _page(), orderRepo: orders, helperRepo: helpers);

    // Pilih tujuan dari pengantaran sebelumnya: ongkos dihitung server.
    await tester.tap(find.text('4 hari lalu'));
    await tester.pumpAndSettle();
    expect(find.text('Isi nama dan nomor penerima'), findsOneWidget);
    expect(_button(tester, 'Lihat Pesanan').onPressed, isNull);
    expect(find.text('Rp 23.500'), findsOneWidget);

    // Penerima.
    await tester.tap(find.text('Siapa penerimanya?'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipientFormPage), findsOneWidget);
    expect(_button(tester, 'Konfirmasi').onPressed, isNull);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Agus');
    await tester.enterText(fields.at(2), '08123541453');
    await tester.pump();
    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle();
    expect(find.text('Agus'), findsOneWidget);
    expect(find.text('08123541453'), findsOneWidget);

    // Waktu antar.
    await tester.tap(find.text('Mau dianter kapan?'));
    await tester.pumpAndSettle();
    expect(find.text('Akan diantar sebelum jam 11.00'), findsOneWidget);
    await tester.tap(find.text('Antar Sekarang'));
    await tester.pump();
    await tester.tap(find.text('Pilih Pengantaran ini'));
    await tester.pumpAndSettle();
    expect(find.text('Antar sekarang'), findsOneWidget);

    // Barang.
    await tester.tap(find.text('Barang apa yang ingin dikirim?'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Ukuran M'));
    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('Makanan'));
    await tester.pump();
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Ukuran M, berat 2 kg'), findsOneWidget);

    // Detail Pesanan.
    await tester.tap(find.text('Lihat Pesanan'));
    await tester.pumpAndSettle();
    expect(find.byType(DeliveryReviewPage), findsOneWidget);
    expect(find.text('Alexsander - 08123543431'), findsOneWidget);
    expect(find.text('Agus - 08123541453'), findsOneWidget);
    expect(find.text('Diantar sebelum jam 11.00'), findsOneWidget);
    expect(find.text('TD-Wallet · Saldo Rp 500.000'), findsOneWidget);

    // Pesan: konfirmasi, cek saldo, lalu ke kurir terdekat.
    await tester.tap(find.text('Pesan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderSuccessPage), findsOneWidget);
    expect(helpers.requested, [testDelivery.id]);
    final body = orders.created.single;
    expect(body['category_id'], testDelivery.id);
    expect(body['helper_id'], testHelpers.first.id);
    expect(body['pickup_address_id'], testHome.id);
    expect(body['destination_address_id'], testOffice.id);
    expect(body['client_estimated_price'], 23500);
    expect(
      find.text('Menunggu Agus Nomercy menerima paket untuk Agus.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Lihat Pesanan'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailPage), findsOneWidget);
    expect(find.text('Delivery - Makanan'), findsOneWidget);
    expect(find.text('Agus'), findsOneWidget); // baris Penerima
  });

  testWidgets('belum ada kurir di sekitar: pesanan tidak dibuat', (
    tester,
  ) async {
    final orders = FakeOrderRepository(addresses: testAddresses);
    await _pump(
      tester,
      DeliveryReviewPage(draft: _draft, category: testDelivery, clock: _now),
      orderRepo: orders,
      helperRepo: FakeHelperRepository(hourlyResult: []),
    );

    await tester.tap(find.text('Pesan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah'));
    await tester.pumpAndSettle();

    expect(
      find.text('Belum ada kurir di sekitarmu. Coba lagi nanti.'),
      findsOneWidget,
    );
    expect(find.byType(DeliveryReviewPage), findsOneWidget);
    expect(orders.created, isEmpty);
  });

  testWidgets('Lihat Pesanan belum lengkap: beri tahu dan buka yang kurang', (
    tester,
  ) async {
    await _pump(tester, _page());
    await tester.tap(find.text('4 hari lalu'));
    await tester.pumpAndSettle();

    // Tombol tampil mati, tapi ketukannya tidak diam saja.
    expect(_button(tester, 'Lihat Pesanan').onPressed, isNull);
    await tester.tap(find.text('Lihat Pesanan'));
    await tester.pumpAndSettle();

    expect(find.text('Isi detail penerima dulu.'), findsOneWidget);
    expect(find.byType(RecipientFormPage), findsOneWidget);
  });

  group('pilihan di lembar tidak hilang', () {
    Future<void> openForm(WidgetTester tester) async {
      await _pump(tester, _page());
      await tester.tap(find.text('4 hari lalu'));
      await tester.pumpAndSettle();
    }

    testWidgets('Antar Nanti: Tetapkan Waktu langsung menyimpan', (
      tester,
    ) async {
      await openForm(tester);
      await tester.tap(find.text('Mau dianter kapan?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Antar Nanti'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10.00 - 11.00'));
      await tester.pump();
      await tester.tap(find.text('Tetapkan Waktu'));
      await tester.pumpAndSettle();

      // Lembar waktu ikut tertutup, tanpa "Pilih Pengantaran ini".
      expect(find.text('Pilih Pengantaran ini'), findsNothing);
      expect(find.text('Antar nanti'), findsOneWidget);
      expect(find.text('Jadwal: 22 Okt 2026 - 10.00-11.00'), findsOneWidget);
    });

    testWidgets('Antar Sekarang lalu ketuk di luar lembar', (tester) async {
      await openForm(tester);
      await tester.tap(find.text('Mau dianter kapan?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Antar Sekarang'));
      await tester.pump();
      await tester.tapAt(const Offset(200, 40)); // area gelap di atas lembar
      await tester.pumpAndSettle();

      expect(find.text('Antar sekarang'), findsOneWidget);
    });

    testWidgets('barang lengkap lalu tombol X', (tester) async {
      await openForm(tester);
      await tester.tap(find.text('Barang apa yang ingin dikirim?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('Pakaian'));
      await tester.pump();
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      expect(find.text('Ukuran S, berat 12 kg'), findsOneWidget);
    });
  });

  group('tata letak sempit (360 dp)', () {
    const narrow = Size(360, 740);

    testWidgets('landing', (tester) async {
      await _pump(tester, _page(), size: narrow);
      expect(find.text('Delivery'), findsOneWidget);
    });

    testWidgets('form', (tester) async {
      await _pump(tester, _page(), size: narrow);
      await tester.tap(find.text('4 hari lalu'));
      await tester.pumpAndSettle();
      expect(find.text('Barang apa yang ingin dikirim?'), findsOneWidget);
    });

    testWidgets('penerima', (tester) async {
      await _pump(
        tester,
        const RecipientFormPage(address: testOffice),
        size: narrow,
      );
      expect(find.text('Penerima'), findsOneWidget);
    });

    testWidgets('detail pesanan dengan rincian terbuka', (tester) async {
      await _pump(
        tester,
        DeliveryReviewPage(draft: _draft, category: testDelivery, clock: _now),
        size: narrow,
      );
      await tester.tap(find.text('Total'));
      await tester.pump();
      expect(find.text('Biaya Pengiriman'), findsOneWidget);
    });
  });
}
