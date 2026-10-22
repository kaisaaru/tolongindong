import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/activity_view.dart';
import 'package:mobile/features/household/active_order_page.dart';
import 'package:mobile/features/household/hourly_helper_list_page.dart';
import 'package:mobile/features/household/house_order_form_page.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/household/household_samples.dart';
import 'package:mobile/features/household/order_review_page.dart';
import 'package:mobile/features/order/order_samples.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/features/order/order_success_page.dart';
import 'package:mobile/features/order/payment_method_page.dart';
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

final _helper = HouseholdSamples.helpers.first; // Rp40.000/jam

HouseholdOrderDraft _draft({TimeSlot? slot, int hours = 1}) =>
    HouseholdOrderDraft(
      service: HouseholdService.rumah,
      address: HouseholdSamples.savedAddresses.first,
      widthM: 10,
      lengthM: 10,
      tools: ToolOption.provided,
      slot: slot,
      helper: _helper,
      hours: hours,
    );

/// Store dengan jam palsu yang bisa dimajukan.
class _Clock {
  DateTime real = DateTime(2026, 10, 21, 9, 45);
  void advance(Duration d) => real = real.add(d);
}

void main() {
  group('PriceBreakdown', () {
    test('voucher 20% memotong biaya awal, bukan tambahan durasi', () {
      final price = PriceBreakdown(
        hourlyRate: 40000,
        baseHours: 1,
        extraHours: const [1],
        voucher: OrderSamples.vouchers.first,
      );
      expect(price.baseCost, 40000);
      expect(price.discount, 8000);
      expect(price.extraCost, 40000);
      expect(price.total, 72000);
    });
  });

  group('OrderStore', () {
    late _Clock clock;
    late OrderStore store;

    setUp(() {
      clock = _Clock();
      store = OrderStore(clock: () => clock.real);
    });

    tearDown(() => store.dispose());

    test('menuju -> bekerja -> selesai, dengan jam 60x lebih cepat', () {
      store.place(
        draft: _draft(),
        payment: HouseholdSamples.paymentMethods.first,
      );
      expect(store.status, ActiveStatus.onTheWay);
      expect(store.canCancel, isTrue);

      // 11 detik nyata = 11 menit pesanan: jendela batal (10 menit) habis.
      clock.advance(const Duration(seconds: 11));
      expect(store.canCancel, isFalse);
      expect(store.status, ActiveStatus.onTheWay);

      // Tiba 30 menit setelah dibuat.
      clock.advance(const Duration(seconds: 20));
      expect(store.status, ActiveStatus.working);
      expect(store.remaining.inMinutes, 59);

      // Durasi 1 jam habis: tunggu pilihan tambah waktu atau selesai.
      clock.advance(const Duration(seconds: 60));
      expect(store.status, ActiveStatus.timeUp);
      expect(activeStatusLabel(store), 'Waktu helper sudah habis');

      store.endWork();
      expect(store.status, ActiveStatus.finished);
    });

    test('tambah durasi saat waktu habis dihitung mulai saat itu', () {
      store.place(
        draft: _draft(),
        payment: HouseholdSamples.paymentMethods.first,
      );
      // Tiba 30 menit, kerja 1 jam, lalu 15 menit tanpa memilih.
      clock.advance(const Duration(seconds: 105));
      expect(store.status, ActiveStatus.timeUp);

      store.addHours(1);

      expect(store.status, ActiveStatus.working);
      expect(store.remaining.inMinutes, 60);
      // Biaya tetap per jam yang ditambah, bukan per menit menunggu.
      expect(store.active!.price.total, 80000);
    });

    test('tambah durasi memperpanjang jam selesai dan total', () {
      store.place(
        draft: _draft(),
        payment: HouseholdSamples.paymentMethods.first,
        voucher: OrderSamples.vouchers.first,
      );
      final before = store.active!.finishAt;

      store.addHours(1);

      expect(store.active!.finishAt, before.add(const Duration(hours: 1)));
      expect(store.active!.totalHours, 2);
      expect(store.active!.price.total, 40000 - 8000 + 40000);
    });

    test('batal dan rating masuk riwayat', () {
      final payment = HouseholdSamples.paymentMethods.first;
      store.place(draft: _draft(), payment: payment);
      store.cancel();
      expect(store.active, isNull);

      store.place(draft: _draft(), payment: payment);
      store.complete(rating: 5);

      final history = store.history;
      expect(history, hasLength(2));
      // Terbaru di atas.
      expect(history.first.outcome, HistoryOutcome.completed);
      expect(history.first.rating, 5);
      expect(history.last.outcome, HistoryOutcome.cancelled);
    });

    test('pesanan terjadwal tiba di awal slot', () {
      final slot = TimeSlot(day: DateTime(2026, 10, 22), startHour: 8);
      store.place(
        draft: _draft(slot: slot),
        payment: HouseholdSamples.paymentMethods.first,
      );
      expect(store.active!.arriveAt, DateTime(2026, 10, 22, 8));
      expect(store.status, ActiveStatus.onTheWay);
    });
  });

  test('label status dan hitung mundur', () {
    expect(countdownLabel(const Duration(minutes: 54, seconds: 23)), '54:23');
    expect(
      countdownLabel(const Duration(hours: 1, minutes: 4, seconds: 5)),
      '1:04:05',
    );

    final clock = _Clock();
    final store = OrderStore(clock: () => clock.real);
    addTearDown(store.dispose);
    store.place(
      draft: _draft(),
      payment: HouseholdSamples.paymentMethods.first,
    );
    expect(activeStatusLabel(store), 'Tiba dalam 30 menit');
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

  testWidgets('filter Task 1000+ menyisakan helper berpengalaman', (
    tester,
  ) async {
    await pumpPage(tester, const HourlyHelperListPage());
    await tester.pumpAndSettle();

    expect(find.text('Jarak 1 km'), findsOneWidget);
    expect(find.text('Jarak 12 km'), findsOneWidget);

    // Chip paling kanan belum dibangun ListView; geser baris chip dulu.
    await tester.dragUntilVisible(
      find.text('Task 1000+'),
      find.byType(ListView).first,
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Task 1000+'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task 1000+'));
    await tester.pumpAndSettle();

    expect(find.text('Jarak 1 km'), findsOneWidget);
    expect(find.text('Jarak 12 km'), findsNothing);
  });

  testWidgets('Aktifitas menampilkan pesanan aktif dan riwayat', (
    tester,
  ) async {
    final clock = _Clock();
    final store = OrderStore(clock: () => clock.real);
    addTearDown(store.dispose);
    final payment = HouseholdSamples.paymentMethods.first;

    store.place(draft: _draft(), payment: payment);
    store.cancel();
    store.place(draft: _draft(), payment: payment);

    await pumpPage(tester, Scaffold(body: ActivityView()), orderStore: store);
    await tester.pump();

    expect(find.text('Tiba dalam 30 menit'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pump();

    expect(find.text('Household - Rumah'), findsOneWidget);
    expect(find.text('Dibatalkan'), findsOneWidget);

    // Hentikan ticker store sebelum test selesai.
    store.reset();
  });

  testWidgets('Pesan tanpa metode pembayaran: konfirmasi, pilih bayar, '
      'berhasil, lalu pesanan aktif', (tester) async {
    final clock = _Clock();
    final store = OrderStore(clock: () => clock.real);
    addTearDown(store.dispose);

    await pumpPage(tester, OrderReviewPage(draft: _draft()), orderStore: store);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pesan'));
    await tester.pumpAndSettle();
    expect(
      find.text('Apakah kamu sudah yakin\ndengan pesananmu?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Sudah'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentMethodPage), findsOneWidget);

    await tester.tap(find.text('BCA'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderSuccessPage), findsOneWidget);
    expect(store.active?.payment.name, 'BCA');
    // Ringkasan pesanan di halaman sukses.
    expect(find.text('Household - Rumah'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);

    await tester.tap(find.text('Lihat Pesanan'));
    // Bar "Batal" beranimasi tiap frame, jadi tidak pernah "settle".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ActiveOrderPage), findsOneWidget);
    expect(find.byType(OrderSuccessPage), findsNothing);

    // Hentikan ticker store sebelum test selesai.
    store.reset();
  });

  testWidgets('Pesan: Kembali di dialog tidak membuat pesanan', (tester) async {
    final store = OrderStore();
    addTearDown(store.dispose);

    await pumpPage(tester, OrderReviewPage(draft: _draft()), orderStore: store);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pesan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderReviewPage), findsOneWidget);
    expect(store.active, isNull);
  });

  testWidgets('Pesan saat masih ada pesanan berjalan: tanpa dialog', (
    tester,
  ) async {
    final clock = _Clock();
    final store = OrderStore(clock: () => clock.real);
    addTearDown(store.dispose);
    store.place(
      draft: _draft(),
      payment: HouseholdSamples.paymentMethods.first,
    );

    await pumpPage(tester, OrderReviewPage(draft: _draft()), orderStore: store);
    await tester.pump();

    await tester.tap(find.text('Pesan'));
    await tester.pump();
    expect(find.textContaining('Masih ada pesanan yang berjalan'), findsOne);
    expect(find.text('Sudah'), findsNothing);

    store.reset();
  });
}
