import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/app_preferences.dart';
import 'package:mobile/features/account/account_view.dart';
import 'package:mobile/features/chat/chat_room_page.dart';
import 'package:mobile/features/helper/earnings_page.dart';
import 'package:mobile/features/helper/finish_confirm_page.dart';
import 'package:mobile/features/helper/helper_job_page.dart';
import 'package:mobile/features/helper/helper_settings_page.dart';
import 'package:mobile/features/helper/helper_shell.dart';
import 'package:mobile/features/helper/helper_store.dart';
import 'package:mobile/features/helper/job_progress_page.dart';
import 'package:mobile/features/helper/make_offer_page.dart';
import 'package:mobile/features/helper/proof_page.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/features/order/order_detail_page.dart';
import 'package:mobile/features/order/order_repository.dart';
import 'package:mobile/models/auth_user.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_catalog_repository.dart';
import '../../helpers/fake_chat_repository.dart';
import '../../helpers/fake_helper_work_repository.dart';
import '../../helpers/fake_order_repository.dart';
import '../../helpers/fake_photo_picker.dart';
import '../../helpers/fake_wallet_repository.dart';
import '../../helpers/pump_page.dart';
import '../../helpers/test_data.dart';

DateTime _now() => DateTime(2026, 10, 22, 9, 47);

const _agus = AuthUser(
  id: 'uuid-agus',
  fullName: 'Agus Pratama',
  email: 'agus.pratama@gmail.com',
  phoneNumber: '081234567890',
  photoUrl: null,
  verificationStatus: VerificationStatus.verified,
  isAdmin: false,
  wallet: Wallet.empty,
);

const _nadia = OrderClient(id: 'c-1', name: 'Nadia Putri');

/// Permintaan Delivery baru (#1), pekerjaan Personal berjalan (#2),
/// Household selesai (#3), dan Delivery menunggu konfirmasi (#4).
List<ServerOrder> _jobs() => [
  FakeOrderRepository.sample(
    id: 1,
    status: OrderStatus.awaitingQuote,
    categoryCode: 'delivery',
    description:
        'Delivery - Dokumen\nPenerima: Resepsionis\n'
        'Catatan pengemudi: Serahkan ke resepsionis',
    price: 35000,
    estimatedPrice: 35000,
    client: _nadia,
    pickup: testHome,
    destination: testOffice,
    respondBy: _now().add(const Duration(minutes: 4, seconds: 32)),
    history: [(status: OrderStatus.awaitingQuote, at: _now())],
  ),
  FakeOrderRepository.sample(
    id: 2,
    status: OrderStatus.inProgress,
    categoryCode: 'personal',
    description: 'Personal - Agus\nTugas: Bantu antre berkas di kelurahan',
    price: 50000,
    client: const OrderClient(id: 'c-2', name: 'Budi Santoso'),
    destination: testHome,
    history: [
      (status: OrderStatus.accepted, at: _now()),
      (status: OrderStatus.onTheWay, at: _now()),
      (status: OrderStatus.inProgress, at: _now()),
    ],
  ),
  FakeOrderRepository.sample(
    id: 3,
    status: OrderStatus.completed,
    description: 'Household - Rumah',
    price: 50000,
  ),
  FakeOrderRepository.sample(
    id: 4,
    status: OrderStatus.awaitingConfirmation,
    categoryCode: 'delivery',
    description: 'Delivery - Dokumen',
    price: 100000,
    client: _nadia,
  ),
];

class _Setup {
  _Setup({List<ServerOrder>? jobs})
    : repo = FakeHelperWorkRepository(
        helperStatus: testHelperStatus,
        jobs: jobs ?? _jobs(),
        clock: _now,
      ) {
    store = HelperStore(repo, clock: _now, pollEvery: const Duration(hours: 1));
  }

  final FakeHelperWorkRepository repo;
  late final HelperStore store;
  final photos = FakePhotoPicker();
  final chats = FakeChatRepository();

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(412, 917),
  }) async {
    addTearDown(store.dispose);
    // Di app status helper sudah dimuat mode Helper sebelum halaman apa pun.
    await store.loadStatus();
    await pumpPage(
      tester,
      page,
      size: size,
      user: _agus,
      authRepo: FakeAuthRepository(sessionUser: _agus),
      catalogRepo: FakeCatalogRepository(result: testCategories),
      helperWorkRepo: repo,
      helperStore: store,
      photoPicker: photos,
      chatRepo: chats,
    );
    await tester.pumpAndSettle();
  }
}

/// Household yang sudah disetujui Client, untuk alur Tiba di Lokasi.
ServerOrder _acceptedHousehold() => FakeOrderRepository.sample(
  id: 5,
  status: OrderStatus.accepted,
  description: 'Household - Kamar\nUkuran: 6 x 10 m',
  price: 100000,
  client: const OrderClient(id: 'c-3', name: 'Rina Lestari'),
  destination: testHome,
  history: [(status: OrderStatus.accepted, at: _now())],
);

void main() {
  group('Beranda helper', () {
    testWidgets('sapaan, status kerja, pendapatan, permintaan, berjalan', (
      tester,
    ) async {
      await _Setup().pump(tester, const HelperShell());

      expect(find.text('Halo, Agus!'), findsOneWidget);
      expect(find.text('Sedang tersedia'), findsOneWidget);
      // Pendapatan cair: hanya #3 (Rp50.000 - 10%).
      expect(find.text('Rp45.000'), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // pesanan selesai
      expect(find.text('1 perlu ditinjau'), findsOneWidget);
      expect(find.text('Lihat pesanan masuk (1)'), findsOneWidget);
      expect(find.text('2 aktif'), findsOneWidget); // #2 dan #4
      expect(find.text('Budi Santoso'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Identitas terverifikasi'),
        200,
      );
      expect(find.text('Identitas terverifikasi'), findsOneWidget);
    });

    testWidgets('status kerja dimatikan lewat sakelar', (tester) async {
      final setup = _Setup();
      await setup.pump(tester, const HelperShell());

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(setup.repo.profileUpdates.single.available, isFalse);
      expect(find.text('Sedang tidak tersedia'), findsOneWidget);
    });

    testWidgets('Lihat pendapatan: cair dan menunggu konfirmasi', (
      tester,
    ) async {
      await _Setup().pump(tester, const HelperShell());
      await tester.tap(find.text('Lihat pendapatan'));
      await tester.pumpAndSettle();

      expect(find.byType(EarningsPage), findsOneWidget);
      expect(find.text('Menunggu konfirmasi Client'), findsOneWidget);
      expect(find.text('Rp90.000'), findsOneWidget); // #4 bersih
      expect(find.text('Riwayat pendapatan cair'), findsOneWidget);
      expect(find.text('Total 1 pesanan'), findsOneWidget);
    });
  });

  group('Pesanan', () {
    testWidgets('Perlu ditinjau: permintaan dengan batas respons', (
      tester,
    ) async {
      await _Setup().pump(tester, const HelperShell());
      await tester.tap(find.text('Pesanan'));
      await tester.pumpAndSettle();

      expect(find.text('1 perlu ditinjau'), findsOneWidget);
      expect(find.text('04:32'), findsOneWidget);
      expect(find.text('Rp35.000'), findsOneWidget);

      await tester.tap(find.text('Berjalan'));
      await tester.pumpAndSettle();
      expect(find.text('Budi Santoso'), findsOneWidget);

      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();
      expect(find.text('Household - Rumah'), findsOneWidget);
    });

    testWidgets('buat penawaran: harga, komisi, lalu menunggu keputusan', (
      tester,
    ) async {
      final setup = _Setup();
      await setup.pump(tester, const HelperJobPage(orderId: 1));

      expect(find.text('Detail permintaan'), findsOneWidget);
      expect(find.text('Nadia Putri memilih kamu secara langsung'), findsOne);
      expect(find.text('Serahkan ke resepsionis'), findsOneWidget);

      await tester.tap(find.text('Buat Penawaran'));
      await tester.pumpAndSettle();
      expect(find.byType(MakeOfferPage), findsOneWidget);
      // Awalnya estimasi Client.
      expect(find.text('35.000'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '100000');
      await tester.pump();
      expect(find.text('100.000'), findsOneWidget);
      expect(find.text('-Rp10.000'), findsOneWidget);
      expect(find.text('Rp90.000'), findsOneWidget);

      await tester.tap(find.text('Kirim Penawaran'));
      await tester.pumpAndSettle();

      expect(setup.repo.calls.single, ('offer', 1, 100000));
      expect(find.byType(MakeOfferPage), findsNothing);
      expect(find.text('Penawaran berhasil dikirim'), findsOneWidget);
      expect(
        find.textContaining('sejak pengiriman 09.47, sampai 09.52'),
        findsOneWidget,
      );

      await tester.tap(find.text('Lihat status penawaran'));
      await tester.pumpAndSettle();
      expect(find.byType(OfferSentPage), findsNothing);
      expect(find.text('Menunggu persetujuan Client'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.textContaining('berbeda dari penawaranmu'), findsOneWidget);
    });

    testWidgets('penawaran di bawah minimal tidak bisa dikirim', (
      tester,
    ) async {
      final setup = _Setup();
      await setup.pump(tester, MakeOfferPage(job: _jobs().first));

      await tester.enterText(find.byType(TextField), '500');
      await tester.pump();
      expect(find.text('Minimal Rp 1.000'), findsOneWidget);
      await tester.tap(find.text('Kirim Penawaran'));
      await tester.pump();
      expect(setup.repo.calls, isEmpty);
    });

    testWidgets('tolak permintaan setelah konfirmasi', (tester) async {
      final setup = _Setup();
      await setup.pump(tester, const HelperJobPage(orderId: 1));

      await tester.tap(find.text('Tolak Permintaan'));
      await tester.pumpAndSettle();
      expect(find.text('Tolak permintaan ini?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(setup.repo.calls, isEmpty);

      await tester.tap(find.text('Tolak Permintaan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, tolak'));
      await tester.pumpAndSettle();

      expect(setup.repo.calls.single.$1, 'reject');
      expect(find.text('Permintaan ditolak'), findsOneWidget);
      expect(find.text('Buat Penawaran'), findsNothing);
    });

    testWidgets('disetujui Client, perjalanan, pengerjaan, bukti, selesai', (
      tester,
    ) async {
      final setup = _Setup();
      await setup.pump(tester, const HelperJobPage(orderId: 1));
      await tester.tap(find.text('Buat Penawaran'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '100000');
      await tester.tap(find.text('Kirim Penawaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lihat status penawaran'));
      await tester.pumpAndSettle();

      // Client menyetujui; halaman memeriksa ulang berkala.
      setup.repo.approveOffer(1);
      await tester.pump(HelperJobPage.pollEvery);
      await tester.pumpAndSettle();
      expect(find.text('Pesanan diterima'), findsOneWidget);
      expect(find.text('Penawaran disetujui'), findsOneWidget);
      expect(find.text('Rp90.000'), findsOneWidget);

      await tester.tap(find.text('Mulai Perjalanan'));
      await tester.pumpAndSettle();
      expect(find.text('Menuju lokasi'), findsOneWidget);
      expect(find.text('Dalam perjalanan'), findsOneWidget);

      // Tiba lalu dikerjakan, berurutan seperti aturan backend.
      await tester.tap(find.text('Mulai Pengerjaan'));
      await tester.pumpAndSettle();
      expect(
        [for (final c in setup.repo.calls.skip(1)) c.$3],
        [OrderStatus.onTheWay, OrderStatus.arrived, OrderStatus.inProgress],
      );
      expect(find.text('Pengerjaan aktif'), findsOneWidget);

      await tester.tap(find.text('Lihat Progres'));
      await tester.pumpAndSettle();
      expect(find.byType(JobProgressPage), findsOneWidget);
      expect(find.text('Sedang dikerjakan'), findsOneWidget);
      await tester.tap(find.text('Unggah Bukti Penyelesaian'));
      await tester.pumpAndSettle();

      expect(find.byType(ProofPage), findsOneWidget);
      expect(find.text('Foto bukti · opsional'), findsOneWidget);
      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();
      expect(setup.photos.sources, [true]);
      expect(find.text('Foto bukti terlampir'), findsOneWidget);

      await tester.tap(find.text('Tandai Selesai'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, tandai selesai'));
      await tester.pumpAndSettle();

      expect(setup.repo.calls.last.$3, OrderStatus.awaitingConfirmation);
      expect(find.byType(ProofPage), findsNothing);
      expect(find.text('Tugasmu sudah selesai!'), findsOneWidget);
      expect(find.text('Estimasi bersih · menunggu'), findsOneWidget);

      await tester.tap(find.text('Lihat transaksi'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionDetailPage), findsOneWidget);
      expect(find.textContaining('masih ditahan'), findsOneWidget);
    });

    testWidgets('Household: tiba di lokasi, progres, konfirmasi selesai', (
      tester,
    ) async {
      final setup = _Setup(jobs: [_acceptedHousehold()]);
      await setup.pump(tester, const HelperJobPage(orderId: 5));

      await tester.tap(find.text('Mulai Perjalanan'));
      await tester.pumpAndSettle();
      expect(find.text('Menuju lokasi'), findsOneWidget);
      expect(find.text('Perbarui status secara manual'), findsOneWidget);
      // Household tidak langsung dikerjakan: tiba dulu.
      expect(find.text('Mulai Pengerjaan'), findsNothing);

      await tester.tap(find.text('Tiba di Lokasi'));
      await tester.pumpAndSettle();
      expect(find.text('Tiba di lokasi · 09.47'), findsOneWidget);
      expect(find.text('Pengerjaan belum dimulai'), findsOneWidget);

      await tester.tap(find.text('Mulai Pengerjaan'));
      await tester.pumpAndSettle();
      expect(
        [for (final c in setup.repo.calls) c.$3],
        [OrderStatus.onTheWay, OrderStatus.arrived, OrderStatus.inProgress],
      );
      expect(find.text('Pengerjaan aktif'), findsOneWidget);
      expect(find.text('Kerjakan sesuai kebutuhan Rina'), findsOneWidget);
      expect(find.text('Unggah Bukti'), findsNothing);

      await tester.tap(find.text('Lihat Progres Pekerjaan'));
      await tester.pumpAndSettle();
      expect(find.text('Tiba di lokasi'), findsOneWidget); // tahap timeline
      await tester.tap(find.text('Selesaikan Pekerjaan'));
      await tester.pumpAndSettle();

      expect(find.byType(FinishConfirmPage), findsOneWidget);
      await tester.tap(find.text('Ya, Selesaikan'));
      await tester.pumpAndSettle();

      expect(setup.repo.calls.last.$3, OrderStatus.awaitingConfirmation);
      expect(find.text('Tugasmu sudah selesai!'), findsOneWidget);
      // Ditandai 09.47; konfirmasi otomatis 24 jam kemudian.
      expect(
        find.textContaining('otomatis setelah 24 jam pada 23 Okt 2026, 09.47'),
        findsOneWidget,
      );
      expect(find.text('Lihat pendapatan'), findsOneWidget);
    });

    testWidgets('penawaran lewat 5 menit bisa dikirim ulang', (tester) async {
      final setup = _Setup(
        jobs: [
          FakeOrderRepository.sample(
            id: 6,
            client: _nadia,
            estimatedPrice: 50000,
            offers: [
              OrderOffer(
                id: 9,
                helperId: 'h-1',
                price: 60000,
                status: OfferStatus.submitted,
                validUntil: _now().subtract(const Duration(minutes: 1)),
              ),
            ],
          ),
        ],
      );
      await setup.pump(tester, const HelperJobPage(orderId: 6));

      expect(find.text('Batas persetujuan 5 menit sudah lewat'), findsOne);
      await tester.tap(find.text('Kirim Ulang'));
      await tester.pumpAndSettle();
      // Harga penawaran sebelumnya, bukan estimasi Client.
      expect(find.text('60.000'), findsOneWidget);

      await tester.tap(find.text('Kirim Penawaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lihat status penawaran'));
      await tester.pumpAndSettle();

      expect(setup.repo.calls.single, ('offer', 6, 60000));
      expect(find.text('Menunggu persetujuan Client'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
    });

    testWidgets('chat dengan Client dari pesanan', (tester) async {
      final setup = _Setup();
      await setup.pump(tester, const HelperJobPage(orderId: 2));

      await tester.tap(find.text('Chat dengan Budi'));
      await tester.pumpAndSettle();

      // Ruang pesanan dibuka (dibuat server kalau belum ada).
      expect(setup.chats.openedOrders, [2]);
      expect(find.byType(ChatRoomPage), findsOneWidget);
      expect(find.text('Client · Personal'), findsOneWidget);
      expect(find.text('#ORD-20261022-2 · Sedang dikerjakan'), findsOneWidget);
    });

    testWidgets('kabar permintaan baru dan penawaran disetujui', (
      tester,
    ) async {
      final setup = _Setup();
      await setup.pump(tester, const HelperShell());
      expect(find.byType(SnackBar), findsNothing);

      setup.repo.addJob(
        FakeOrderRepository.sample(
          id: 7,
          description: 'Household - Kamar',
          client: const OrderClient(id: 'c-3', name: 'Rina Lestari'),
        ),
      );
      await setup.store.refresh(quiet: true);
      await tester.pump();
      expect(
        find.text('Permintaan baru dari Rina Lestari: Household - Kamar'),
        findsOneWidget,
      );

      await setup.store.submitOffer(7, 90000);
      setup.repo.approveOffer(7);
      await setup.store.refresh(quiet: true);
      // Snackbar kedua antre sampai yang pertama hilang.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Rina Lestari menyetujui penawaranmu'),
        findsOneWidget,
      );

      await tester.tap(find.text('Lihat'));
      await tester.pumpAndSettle();
      expect(find.text('Pesanan diterima'), findsOneWidget);
    });

    testWidgets('foto bukti tidak wajib', (tester) async {
      final setup = _Setup();
      await setup.pump(tester, ProofPage(job: _jobs()[1]));

      await tester.tap(find.text('Tandai Selesai'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, tandai selesai'));
      await tester.pumpAndSettle();

      expect(setup.repo.calls.single.$3, OrderStatus.awaitingConfirmation);
    });
  });

  group('Profil helper', () {
    testWidgets('identitas, layanan, lalu beralih ke Client', (tester) async {
      await _Setup().pump(tester, const HelperShell());
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Agus Pratama'), findsOneWidget);
      expect(find.text('Mode Helper'), findsOneWidget);
      expect(find.text('Tersedia'), findsOneWidget);
      expect(find.text('Household'), findsOneWidget);
      expect(
        find.text('agus.pratama@gmail.com · 081234567890'),
        findsOneWidget,
      );

      await tester.tap(find.text('Beralih ke Client'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(await AppPreferences().mode(), AppMode.client);
    });

    testWidgets('kategori dan ketersediaan disimpan', (tester) async {
      final setup = _Setup();
      await setup.pump(tester, const HelperSettingsPage());

      expect(find.text('Pengaturan layanan · Agus Pratama'), findsOneWidget);
      // Delivery dan Household tercentang; Personal belum.
      await tester.tap(find.text('Personal'));
      await tester.tap(find.text('Delivery'));
      await tester.tap(find.text('Sedang tidak tersedia'));
      await tester.pump();
      await tester.tap(find.text('Simpan perubahan'));
      await tester.pumpAndSettle();

      final update = setup.repo.profileUpdates.single;
      expect(update.available, isFalse);
      expect(update.categoryIds, [2, 3]);
      expect(find.byType(HelperSettingsPage), findsNothing);
    });

    testWidgets('kategori kosong ditolak sebelum dikirim', (tester) async {
      final setup = _Setup();
      await setup.pump(tester, const HelperSettingsPage());

      await tester.tap(find.text('Delivery'));
      await tester.tap(find.text('Household'));
      await tester.tap(find.text('Simpan perubahan'));
      await tester.pump();

      expect(find.text('Pilih minimal satu kategori layanan.'), findsOneWidget);
      expect(setup.repo.profileUpdates, isEmpty);
    });
  });

  group('dari mode Client', () {
    testWidgets('helper terverifikasi bisa beralih ke mode Helper', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const HomePage(),
        user: _agus,
        authRepo: FakeAuthRepository(sessionUser: _agus),
        helperWorkRepo: FakeHelperWorkRepository(
          helperStatus: testHelperStatus,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountView), findsOneWidget);
      expect(find.text('Daftar Jadi Helper'), findsNothing);
      await tester.tap(find.text('Beralih ke Mode Helper'));
      await tester.pumpAndSettle();

      expect(find.byType(HelperShell), findsOneWidget);
      expect(await AppPreferences().mode(), AppMode.helper);
    });

    testWidgets('Client menyetujui penawaran helper', (tester) async {
      final orders = FakeOrderRepository(
        orders: [
          FakeOrderRepository.sample(
            status: OrderStatus.awaitingQuote,
            categoryCode: 'delivery',
            description: 'Delivery - Dokumen',
            price: 35000,
            estimatedPrice: 35000,
            offers: [
              OrderOffer(
                id: 7,
                helperId: 'h-1',
                price: 100000,
                status: OfferStatus.submitted,
                message: 'Siap antar sekarang',
                validUntil: _now().add(const Duration(minutes: 4)),
              ),
            ],
          ),
        ],
      );
      await pumpPage(
        tester,
        OrderDetailPage(orderId: 1, clock: _now),
        orderRepo: orders,
        walletRepo: FakeWalletRepository(balance: 500000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Penawaran masuk'), findsOneWidget);
      expect(find.text('Penawaran Agus Nomercy'), findsOneWidget);
      expect(find.text('Rp100.000'), findsOneWidget);
      expect(find.text('Estimasimu Rp35.000'), findsOneWidget);
      expect(find.text('"Siap antar sekarang"'), findsOneWidget);

      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();

      expect(orders.selected.single, (1, 7));
      expect(find.text('Helper bersiap berangkat'), findsOneWidget);
      expect(find.text('Penawaran masuk'), findsNothing);
    });
  });

  group('tata letak sempit (320 dp)', () {
    const narrow = Size(320, 640);

    for (final (name, page) in <(String, Widget)>[
      ('beranda', const HelperShell()),
      ('permintaan', const HelperJobPage(orderId: 1)),
      ('berjalan', const HelperJobPage(orderId: 2)),
      ('selesai', const HelperJobPage(orderId: 4)),
      ('pendapatan', const EarningsPage()),
      ('pengaturan', const HelperSettingsPage()),
    ]) {
      testWidgets(name, (tester) async {
        await _Setup().pump(tester, page, size: narrow);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('penawaran dan bukti', (tester) async {
      final setup = _Setup();
      await setup.pump(tester, MakeOfferPage(job: _jobs().first), size: narrow);
      expect(find.text('Harga penawaranmu'), findsOneWidget);
      await pumpPage(
        tester,
        ProofPage(job: _jobs()[1]),
        size: narrow,
        helperStore: setup.store,
      );
      await tester.pumpAndSettle();
      expect(find.text('Bukti penyelesaian'), findsOneWidget);
    });

    testWidgets('profil', (tester) async {
      await _Setup().pump(tester, const HelperShell(), size: narrow);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Beralih ke Client'), 200);
      expect(find.text('Beralih ke Client'), findsOneWidget);
    });

    testWidgets('alur Household sampai konfirmasi penyelesaian', (
      tester,
    ) async {
      final setup = _Setup(jobs: [_acceptedHousehold()]);
      await setup.pump(tester, const HelperJobPage(orderId: 5), size: narrow);
      for (final step in [
        'Mulai Perjalanan',
        'Tiba di Lokasi',
        'Mulai Pengerjaan',
        'Lihat Progres Pekerjaan',
        'Selesaikan Pekerjaan',
      ]) {
        await tester.tap(find.text(step));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: step);
      }
      expect(find.text('Pekerjaan sudah selesai?'), findsOneWidget);
    });
  });
}
