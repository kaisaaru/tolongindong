// Alur pesanan dan chat ujung-ke-ujung terhadap backend sungguhan.
//
// Tes ini MEMBUAT pesanan, memotong saldo, dan mengirim chat, jadi hanya
// boleh ditembakkan ke backend uji dengan database sendiri (misal SQLite
// lokal), BUKAN ke database bersama. Tanpa SANDBOX_URL, semua dilewati.
//
//   flutter test test/order_live_test.dart \
//     --dart-define=SANDBOX_URL=http://127.0.0.1:8001
//
// Akun yang dibutuhkan (password sama: SANDBOX_PASSWORD, default
// password123): pelanggan client@uji.test bersaldo dan punya 2 alamat,
// helper agus@uji.test (Personal + Household) dan budi@uji.test
// (Delivery + Household) yang sudah disetujui admin.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/features/address/address_repository.dart';
import 'package:mobile/features/auth/auth_repository.dart';
import 'package:mobile/features/chat/chat_repository.dart';
import 'package:mobile/features/chat/chat_store.dart';
import 'package:mobile/features/helper/helper_store.dart';
import 'package:mobile/features/helper/helper_work_repository.dart';
import 'package:mobile/features/home/catalog_repository.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/household/order_review_page.dart';
import 'package:mobile/features/order/helper_repository.dart';
import 'package:mobile/features/order/order_repository.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/features/wallet/wallet_repository.dart';
import 'package:mobile/models/auth_user.dart';

const _baseUrl = String.fromEnvironment('SANDBOX_URL');
const _password = String.fromEnvironment(
  'SANDBOX_PASSWORD',
  defaultValue: 'password123',
);

/// Pengganti keystore perangkat, yang tidak tersedia di lingkungan tes.
class _MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> save(String token) async => _token = token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> clear() async => _token = null;

  @override
  Future<bool> hasToken() async => (_token ?? '').isNotEmpty;
}

/// Satu akun yang sudah masuk, dengan [ApiClient] bertoken miliknya.
class _Session {
  _Session(this.user, this.api);

  final AuthUser user;
  final ApiClient api;

  static Future<_Session> login(String email) async {
    final storage = _MemoryTokenStorage();
    final api = ApiClient(storage: storage, baseUrl: _baseUrl);
    final user = await AuthRepository(
      api: api,
      storage: storage,
    ).login(identifier: email, password: _password);
    return _Session(user, api);
  }
}

void main() {
  group('sandbox', skip: _baseUrl.isEmpty ? 'SANDBOX_URL kosong' : null, () {
    late _Session client;
    late _Session agus;
    late Map<String, int> categoryIds;
    late List<SavedAddress> addresses;
    late OrderStore store;

    setUpAll(() async {
      client = await _Session.login('client@uji.test');
      agus = await _Session.login('agus@uji.test');
      final categories = await CatalogRepository(api: client.api).categories();
      categoryIds = {for (final c in categories) c.code: c.id};
      addresses = await AddressRepository(api: client.api).list();
    });

    setUp(() {
      store = OrderStore(
        OrderRepository(api: client.api),
        pollEvery: const Duration(hours: 1),
      );
    });

    tearDown(() => store.dispose());

    /// Helper [name] di kategori [code], dari `GET /helpers`.
    Future<HourlyHelper> helperNamed(String code, String name) async {
      final helpers = await HelperRepository(
        api: client.api,
      ).hourly(categoryIds[code]!);
      return helpers.firstWhere((h) => h.name == name);
    }

    /// Sisi helper: terima lalu jalankan status sampai dikerjakan.
    Future<void> helperWorks(_Session helper, int orderId) async {
      await helper.api.post('/orders/$orderId/accept');
      for (final status in ['on_the_way', 'arrived', 'in_progress']) {
        await helper.api.post(
          '/orders/$orderId/status',
          body: {'status': status},
        );
      }
    }

    test('Household: pesan, helper bekerja, selesai, rating', () async {
      expect(addresses, isNotEmpty, reason: 'pelanggan butuh alamat');
      final helper = await helperNamed('household', 'Agus Nomercy');
      final draft = HouseholdOrderDraft(
        service: HouseholdService.rumah,
        address: addresses.first,
        widthM: 4,
        lengthM: 5,
        tools: ToolOption.provided,
        helper: helper,
        hours: 1,
      );
      final walletBefore = await WalletRepository(api: client.api).wallet();

      final placed = await store.place(
        categoryId: categoryIds['household']!,
        helperId: helper.id,
        description: householdOrderDescription(draft),
        price: helper.hourlyRate,
        destinationAddressId: addresses.first.id,
      );
      expect(placed.status, OrderStatus.awaitingQuote);
      expect(placed.helper?.name, 'Agus Nomercy');
      expect(placed.title, 'Household - Rumah');
      expect(placed.parsed.durationHours, 1);
      expect(placed.destination?.id, addresses.first.id);
      expect(store.active.map((o) => o.id), contains(placed.id));

      await helperWorks(agus, placed.id);
      final working = await store.load(placed.id);
      expect(working.status, OrderStatus.inProgress);
      expect(working.status.canConfirm, isTrue);
      // Hitung mundur Household mulai dari riwayat status.
      expect(working.enteredAt(OrderStatus.inProgress), isNotNull);

      // Saldo ditahan sejak helper menerima.
      final held = await WalletRepository(api: client.api).wallet();
      expect(held.availableBalance, lessThan(walletBefore.availableBalance));

      final done = await store.confirm(placed.id);
      expect(done.status, OrderStatus.completed);
      await store.rate(placed.id, 5);
      expect(store.isRated(placed.id), isTrue);
      // Dinilai dua kali (misal dari perangkat lain) tidak dianggap gagal.
      await store.rate(placed.id, 4);

      await store.refresh();
      expect(store.history.map((o) => o.id), contains(placed.id));
    });

    test('batal sebelum helper menerima: tanpa biaya', () async {
      final helper = await helperNamed('household', 'Agus Nomercy');
      final placed = await store.place(
        categoryId: categoryIds['household']!,
        helperId: helper.id,
        description: 'Household - Kamar\nDurasi: 1 Jam',
        price: helper.hourlyRate,
        destinationAddressId: addresses.first.id,
      );

      final cancelled = await store.cancel(placed.id, reason: 'Tes batal');
      expect(cancelled.status, OrderStatus.cancelledByClient);
      expect(cancelled.status.isCancelled, isTrue);
      expect(cancelled.cancellationFee, 0);
    });

    test('Delivery: ongkos dari estimate, pesan ke kurir terdekat', () async {
      expect(addresses.length, greaterThanOrEqualTo(2));
      final repo = OrderRepository(api: client.api);
      final fee = await repo.estimate(
        categoryId: categoryIds['delivery']!,
        pickupAddressId: addresses[0].id,
        destinationAddressId: addresses[1].id,
      );
      expect(fee, greaterThan(0));

      final couriers = await HelperRepository(
        api: client.api,
      ).hourly(categoryIds['delivery']!);
      expect(couriers.map((h) => h.name), contains('Budi Santoso'));

      try {
        final placed = await store.place(
          categoryId: categoryIds['delivery']!,
          helperId: couriers.first.id,
          description: 'Delivery - Dokumen\nPenerima: Uji',
          price: fee,
          pickupAddressId: addresses[0].id,
          destinationAddressId: addresses[1].id,
        );
        expect(placed.pickup?.id, addresses[0].id);
        expect(placed.destination?.id, addresses[1].id);
        await store.cancel(placed.id);
      } on ApiException catch (e) {
        // Kategori bertalangan butuh limit talangan dari helper; kalau
        // datanya belum siap, backend menolak dengan kode ini.
        expect(e.code, 'ADVANCE_LIMIT_REQUIRED');
      }
    });

    test('Mode Helper: penawaran, disetujui Client, kerja, cair', () async {
      final helper = await helperNamed('household', 'Agus Nomercy');
      final work = HelperStore(
        HelperWorkRepository(api: agus.api),
        pollEvery: const Duration(hours: 1),
      );
      addTearDown(work.dispose);

      // Status kerja bisa dimatikan lalu dinyalakan lagi.
      await work.loadStatus();
      expect(work.status.isVerifiedHelper, isTrue);
      expect(work.status.profileId, helper.id);
      await work.setAvailable(false);
      expect(work.status.available, isFalse);
      await work.setAvailable(true);
      expect(work.status.available, isTrue);

      final placed = await store.place(
        categoryId: categoryIds['household']!,
        helperId: helper.id,
        description: 'Household - Kamar\nDurasi: 1 Jam',
        price: 35000,
        destinationAddressId: addresses.first.id,
      );

      // Permintaan masuk ke helper, lengkap dengan pemesan.
      await work.refresh();
      final request = work.toReview.firstWhere((o) => o.id == placed.id);
      expect(request.client?.name, client.user.fullName);
      expect(request.estimatedPrice, 35000);
      expect(request.respondBy, isNotNull);

      final offered = await work.submitOffer(placed.id, 60000);
      expect(work.myOffer(offered)?.status, OfferStatus.submitted);
      expect(work.waitingDecision.map((o) => o.id), contains(placed.id));

      // Client melihat dan menyetujui penawaran.
      final seen = await store.load(placed.id);
      final offer = seen.pendingOffer!;
      expect(offer.price, 60000);
      final accepted = await store.selectOffer(placed.id, offer.id);
      expect(accepted.status, OrderStatus.accepted);
      expect(accepted.price, 60000);

      var job = await work.load(placed.id);
      expect(job.status, OrderStatus.accepted);
      // Lewat penawaran, backend baru mengisi komisi saat selesai; app
      // menghitung 10% sendiri sementara itu.
      expect(job.commission, 6000);
      expect(job.netPayout, 54000);

      await work.advance(placed.id, OrderStatus.onTheWay);
      job = await work.startWork(placed.id);
      expect(job.status, OrderStatus.inProgress);
      job = await work.advance(placed.id, OrderStatus.awaitingConfirmation);
      expect(job.status, OrderStatus.awaitingConfirmation);
      expect(job.helperFinishedAt, isNotNull);

      await store.confirm(placed.id);
      await work.refresh();
      final paid = work.paidOut.firstWhere((o) => o.id == placed.id);
      expect(paid.helperPayout, 54000);
    });

    test('Mode Helper: tolak permintaan', () async {
      final helper = await helperNamed('household', 'Agus Nomercy');
      final work = HelperStore(
        HelperWorkRepository(api: agus.api),
        pollEvery: const Duration(hours: 1),
      );
      addTearDown(work.dispose);
      final placed = await store.place(
        categoryId: categoryIds['household']!,
        helperId: helper.id,
        description: 'Household - Pakaian',
        price: 35000,
        destinationAddressId: addresses.first.id,
      );

      final rejected = await work.reject(placed.id);
      expect(rejected.status, OrderStatus.cancelledByHelper);
      expect((await store.load(placed.id)).status.isCancelled, isTrue);
    });

    test('Chat: pelanggan menyapa, helper membalas', () async {
      final helper = await helperNamed('household', 'Agus Nomercy');
      final chats = ChatStore(
        ChatRepository(api: client.api),
        userId: () => client.user.id,
      );
      addTearDown(chats.dispose);

      final room = await chats.openWithHelper(
        helperId: helper.id,
        name: helper.name,
      );
      final hello = 'Halo dari tes ${DateTime.now().millisecondsSinceEpoch}';
      await chats.send(room, hello);
      expect(room.lastMessage?.text, hello);
      expect(room.lastMessage?.fromMe, isTrue);

      // Sisi helper.
      final helperChats = ChatRepository(api: agus.api);
      final helperRooms = await helperChats.rooms(agus.user.id);
      final same = helperRooms.firstWhere((r) => r.id == room.id);
      final seen = await helperChats.messages(same.id, agus.user.id);
      expect(seen.last.text, hello);
      expect(seen.last.fromMe, isFalse);
      await helperChats.send(same.id, 'Siap, saya bantu.', agus.user.id);

      await chats.loadMessages(room);
      expect(room.messages.last.text, 'Siap, saya bantu.');
      expect(room.messages.last.fromMe, isFalse);
      expect(room.unreadCount, 0);

      await chats.refresh();
      expect(chats.rooms.map((r) => r.id), contains(room.id));
    });
  });
}
