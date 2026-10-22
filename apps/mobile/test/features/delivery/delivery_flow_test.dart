import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/activity_view.dart';
import 'package:mobile/features/delivery/delivery_models.dart';
import 'package:mobile/features/delivery/delivery_page.dart';
import 'package:mobile/features/delivery/delivery_review_page.dart';
import 'package:mobile/features/delivery/delivery_samples.dart';
import 'package:mobile/features/delivery/recipient_form_page.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/household/household_samples.dart';
import 'package:mobile/features/order/order_samples.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/features/order/order_success_page.dart';
import 'package:mobile/features/order/payment_method_page.dart';
import 'package:mobile/models/auth_user.dart';

import '../../helpers/pump_page.dart';

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

DeliveryPage _page() => DeliveryPage(clock: _now);

final _draft = DeliveryDraft(
  senderName: 'Alexsander',
  senderPhone: '08123543431',
  origin: HouseholdSamples.currentLocation,
  destination: HouseholdSamples.savedAddresses[1], // KOST BUMISAKA
  recipient: const Recipient(name: 'Agus', phone: '08123541453'),
  schedule: const DeliverySchedule.now(),
  item: const DeliveryItem(
    size: ItemSize.m,
    weightKg: 2,
    type: ItemType.makanan,
  ),
  fee: DeliverySamples.fee,
);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(412, 1100),
  OrderStore? orderStore,
}) async {
  await pumpPage(
    tester,
    page,
    size: size,
    orderStore: orderStore,
    user: _sender,
  );
  await tester.pump();
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

    test('voucher 20% dari Rp20.000 = Rp4.000, total Rp16.000', () {
      final order = DeliveryOrder(
        draft: _draft,
        payment: HouseholdSamples.paymentMethods.first,
        placedAt: _now(),
        voucher: OrderSamples.vouchers.first,
      );
      expect(order.discount, 4000);
      expect(order.total, 16000);
      expect(_draft.item.summary, 'Ukuran M, berat 2 kg');
    });
  });

  testWidgets('landing: pengantaran sebelumnya dan promo', (tester) async {
    await _pump(tester, _page(), orderStore: OrderStore());

    expect(find.text('Pengantaran sebelumnya'), findsOneWidget);
    expect(find.text('4 hari lalu'), findsOneWidget);
    expect(find.text('3 bulan lalu'), findsOneWidget);
    expect(find.text('Promo pengiriman'), findsOneWidget);
    expect(find.text('Lihat Pesanan'), findsNothing);
  });

  testWidgets('promo dipakai, lalu ikut ke form', (tester) async {
    await _pump(tester, _page(), orderStore: OrderStore());

    await tester.tap(find.text('Diskon 20%').first);
    await tester.pump();
    expect(find.text('Dipakai'), findsOneWidget);

    await tester.tap(find.text('4 hari lalu'));
    await tester.pumpAndSettle();
    expect(find.text('Diskon 20%'), findsOneWidget); // kartu voucher
    expect(find.text('Rp 16.000'), findsOneWidget);
  });

  testWidgets('form lengkap sampai pesanan berhasil (bayar di tempat)', (
    tester,
  ) async {
    final store = OrderStore();
    await _pump(tester, _page(), orderStore: store);

    // Pilih tujuan dari pengantaran sebelumnya.
    await tester.tap(find.text('4 hari lalu'));
    await tester.pumpAndSettle();
    expect(find.text('Isi nama dan nomor penerima'), findsOneWidget);
    expect(_button(tester, 'Lihat Pesanan').onPressed, isNull);
    expect(find.text('Rp 20.000'), findsOneWidget);

    // Penerima: baris sendiri, sejajar waktu dan barang.
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
    expect(_button(tester, 'Pilih Pengantaran ini').onPressed, isNull);
    await tester.tap(find.text('Antar Sekarang'));
    await tester.pump();
    await tester.tap(find.text('Pilih Pengantaran ini'));
    await tester.pumpAndSettle();
    expect(find.text('Antar sekarang'), findsOneWidget);
    expect(find.text('Barang akan segera diambil'), findsOneWidget);

    // Barang.
    await tester.tap(find.text('Barang apa yang ingin dikirim?'));
    await tester.pumpAndSettle();
    expect(_button(tester, 'Selesai').onPressed, isNull);
    await tester.tap(find.bySemanticsLabel('Ukuran M'));
    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('Makanan'));
    await tester.pump();
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Makanan'), findsOneWidget);
    expect(find.text('Ukuran M, berat 2 kg'), findsOneWidget);

    // Detail Pesanan.
    await tester.tap(find.text('Lihat Pesanan'));
    await tester.pumpAndSettle();
    expect(find.byType(DeliveryReviewPage), findsOneWidget);
    expect(find.text('Alexsander - 08123543431'), findsOneWidget);
    expect(find.text('Agus - 08123541453'), findsOneWidget);
    expect(find.text('Diantar sebelum jam 11.00'), findsOneWidget);

    // Pesan: konfirmasi, lalu metode pembayaran (ada Bayar di Tempat).
    await tester.tap(find.text('Pesan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentMethodPage), findsOneWidget);
    // Judul grup dan nama metode sama-sama "Bayar di Tempat".
    await tester.tap(find.text('Bayar di Tempat').last);
    await tester.pumpAndSettle();

    expect(find.byType(OrderSuccessPage), findsOneWidget);
    final order = store.deliveries.single;
    expect(order.payment.id, 'cod');
    expect(order.total, 20000);
    expect(order.draft.recipient.name, 'Agus');
    expect(find.text('Paket untuk Agus. Diantar sebelum jam 11.00.'), findsOne);

    await tester.tap(find.text('Lihat Pesanan'));
    await tester.pumpAndSettle();
    expect(find.text('Dalam pengantaran'), findsOneWidget);
    expect(find.text('Pesanan Diterima'), findsOneWidget);
  });

  testWidgets('Lihat Pesanan belum lengkap: beri tahu dan buka yang kurang', (
    tester,
  ) async {
    await _pump(tester, _page(), orderStore: OrderStore());
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
      await _pump(tester, _page(), orderStore: OrderStore());
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

  test('jadwal antar nanti seperti desain', () {
    final labels = scheduleLabels(
      DeliverySchedule.at(TimeSlot(day: DateTime(2026, 10, 21), startHour: 8)),
      _now(),
    );
    expect(labels.subtitle, 'Jadwal: 21 Okt 2026 - 08.00-09.00');
  });

  testWidgets('Bayar di Tempat hanya untuk Delivery', (tester) async {
    await _pump(tester, const PaymentMethodPage());
    expect(find.text('Bayar di Tempat'), findsNothing);

    await _pump(tester, const PaymentMethodPage(allowCashOnDelivery: true));
    expect(find.text('Bayar di Tempat'), findsNWidgets(2)); // grup + metode
  });

  testWidgets('Aktifitas: pengantaran, dibuka sebagai detail baca-saja', (
    tester,
  ) async {
    final store = OrderStore(clock: _now)
      ..placeDelivery(
        draft: _draft,
        payment: HouseholdSamples.paymentMethods.first,
      );
    await _pump(tester, Scaffold(body: ActivityView()), orderStore: store);

    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Diantar sebelum jam 11.00'), findsOneWidget);

    await tester.tap(find.text('Delivery'));
    await tester.pumpAndSettle();
    expect(find.byType(DeliveryReviewPage), findsOneWidget);
    expect(find.text('Pesan'), findsNothing);
    expect(find.text('OVO'), findsOneWidget);
  });

  testWidgets('Pesanan Diterima memindahkan pengantaran ke riwayat', (
    tester,
  ) async {
    final store = OrderStore(clock: _now)
      ..placeDelivery(
        draft: _draft,
        payment: HouseholdSamples.paymentMethods.first,
      );
    await _pump(
      tester,
      DeliveryReviewPage.placed(order: store.deliveries.single),
      orderStore: store,
    );

    await tester.tap(find.text('Pesanan Diterima'));
    await tester.pumpAndSettle();
    // Dibatalkan dulu: pesanan tetap berjalan.
    await tester.tap(find.text('Belum'));
    await tester.pumpAndSettle();
    expect(store.deliveries, hasLength(1));

    await tester.tap(find.text('Pesanan Diterima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah diterima'));
    await tester.pumpAndSettle();

    expect(store.deliveries, isEmpty);
    expect(store.hasActive, isFalse);
    final record = store.history.single;
    expect(record.title, 'Delivery - Makanan');
    expect(record.categoryCode, 'delivery');
    expect(record.total, DeliverySamples.fee);
  });

  group('tata letak sempit (360 dp)', () {
    const narrow = Size(360, 740);

    testWidgets('landing', (tester) async {
      await _pump(tester, _page(), orderStore: OrderStore(), size: narrow);
      expect(find.text('Delivery'), findsOneWidget);
    });

    testWidgets('form', (tester) async {
      await _pump(tester, _page(), orderStore: OrderStore(), size: narrow);
      await tester.tap(find.text('4 hari lalu'));
      await tester.pumpAndSettle();
      expect(find.text('Barang apa yang ingin dikirim?'), findsOneWidget);
    });

    testWidgets('penerima', (tester) async {
      await _pump(
        tester,
        RecipientFormPage(address: HouseholdSamples.savedAddresses[1]),
        size: narrow,
      );
      expect(find.text('Penerima'), findsOneWidget);
    });

    testWidgets('detail pesanan dengan rincian terbuka', (tester) async {
      await _pump(
        tester,
        DeliveryReviewPage(
          draft: _draft,
          voucher: OrderSamples.vouchers.first,

          clock: _now,
        ),
        size: narrow,
        orderStore: OrderStore(),
      );
      await tester.tap(find.text('Total'));
      await tester.pump();
      expect(find.text('Biaya Pengiriman'), findsOneWidget);
      expect(find.text('-Rp 4.000'), findsOneWidget);
    });
  });
}
