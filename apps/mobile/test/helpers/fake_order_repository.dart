import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/order/order_repository.dart';

/// Pengganti [OrderRepository] untuk widget test: pesanan di memori.
///
/// Sisi helper (menerima, berangkat, selesai) disimulasikan lewat
/// [advance]. Pesanan baru langsung berstatus menunggu helper menerima.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({
    List<ServerOrder> orders = const [],
    this.fee = 20000,
    this.addresses = const [],
    DateTime Function()? clock,
  }) : orders = [...orders],
       _clock = clock ?? (() => DateTime(2026, 10, 22, 9, 47));

  /// Terbaru di atas, seperti `GET /orders`.
  final List<ServerOrder> orders;

  /// Hasil [estimate].
  int fee;

  /// Alamat yang dikenali untuk `pickup_address_id`/`destination_address_id`.
  final List<SavedAddress> addresses;
  final DateTime Function() _clock;

  /// Isi `POST /orders` yang diterima, berurutan.
  final created = <Map<String, Object?>>[];
  final confirmed = <int>[];
  final cancelled = <int>[];
  final ratings = <int, int>{};

  /// Kalau diisi, [create] berikutnya gagal dengan error ini (sekali).
  ApiException? failNextCreate;

  /// Kategori untuk id yang dipakai test (lihat `testCategories`).
  static const _categories = {
    1: ('delivery', 'Delivery'),
    2: ('personal', 'Personal'),
    3: ('household', 'Household'),
  };

  int _nextId = 100;

  /// Pesanan contoh dengan nilai bawaan yang masuk akal.
  static ServerOrder sample({
    int id = 1,
    OrderStatus status = OrderStatus.awaitingQuote,
    String categoryCode = 'household',
    String description = 'Household - Rumah\nDurasi: 2 Jam',
    int price = 80000,
    DateTime? createdAt,
    OrderHelper? helper = const OrderHelper(
      id: 'h-1',
      name: 'Agus Nomercy',
      rating: 5,
    ),
    SavedAddress? pickup,
    SavedAddress? destination,
    List<({OrderStatus status, DateTime at})> history = const [],
    int cancellationFee = 0,
  }) => ServerOrder(
    id: id,
    number: 'ORD-20261022-$id',
    status: status,
    categoryCode: categoryCode,
    categoryName: categoryCode[0].toUpperCase() + categoryCode.substring(1),
    description: description,
    price: price,
    createdAt: createdAt ?? DateTime(2026, 10, 22, 9),
    helper: helper,
    pickup: pickup,
    destination: destination,
    history: history,
    cancellationFee: cancellationFee,
  );

  ServerOrder _byId(int id) => orders.firstWhere(
    (o) => o.id == id,
    orElse: () => throw const ApiException(
      code: 'NOT_FOUND',
      message: 'Pesanan tidak ditemukan.',
    ),
  );

  void _replace(ServerOrder order) {
    final i = orders.indexWhere((o) => o.id == order.id);
    orders[i] = order;
  }

  /// Status berpindah (oleh helper, admin, atau pelanggan) dan tercatat di
  /// riwayat.
  void advance(int id, OrderStatus status, {int? cancellationFee}) {
    final o = _byId(id);
    _replace(
      ServerOrder(
        id: o.id,
        number: o.number,
        status: status,
        categoryCode: o.categoryCode,
        categoryName: o.categoryName,
        description: o.description,
        price: o.price,
        createdAt: o.createdAt,
        helper: o.helper,
        pickup: o.pickup,
        destination: o.destination,
        history: [...o.history, (status: status, at: _clock())],
        cancellationFee: cancellationFee ?? o.cancellationFee,
      ),
    );
  }

  SavedAddress? _address(int? id) {
    for (final a in addresses) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<int> create({
    required int categoryId,
    required String helperId,
    required String description,
    required int price,
    int? pickupAddressId,
    int? destinationAddressId,
  }) async {
    final fail = failNextCreate;
    if (fail != null) {
      failNextCreate = null;
      throw fail;
    }
    created.add({
      'category_id': categoryId,
      'helper_id': helperId,
      'task_description': description,
      'client_estimated_price': price,
      'pickup_address_id': pickupAddressId,
      'destination_address_id': destinationAddressId,
    });
    final (code, name) = _categories[categoryId] ?? ('household', 'Pesanan');
    final id = _nextId++;
    orders.insert(
      0,
      ServerOrder(
        id: id,
        number: 'ORD-20261022-$id',
        status: OrderStatus.awaitingQuote,
        categoryCode: code,
        categoryName: name,
        description: description,
        price: price,
        createdAt: _clock(),
        helper: OrderHelper(id: helperId, name: 'Agus Nomercy', rating: 5),
        pickup: _address(pickupAddressId),
        destination: _address(destinationAddressId),
        history: [(status: OrderStatus.awaitingQuote, at: _clock())],
      ),
    );
    return id;
  }

  @override
  Future<List<ServerOrder>> list({int perPage = 30}) async => [...orders];

  @override
  Future<ServerOrder> detail(int id) async => _byId(id);

  /// Aturan backend: gratis sebelum helper menerima, lalu Rp5.000.
  @override
  Future<void> cancel(int id, {String? reason}) async {
    cancelled.add(id);
    final waiting = _byId(id).status.isWaiting;
    advance(
      id,
      OrderStatus.cancelledByClient,
      cancellationFee: waiting ? 0 : 5000,
    );
  }

  @override
  Future<void> confirm(int id) async {
    confirmed.add(id);
    advance(id, OrderStatus.completed);
  }

  @override
  Future<void> rate(int id, int score, {String? review}) async {
    if (ratings.containsKey(id)) {
      throw const ApiException(
        code: 'ALREADY_RATED',
        message: 'Pesanan ini sudah dinilai.',
      );
    }
    ratings[id] = score;
  }

  @override
  Future<int> estimate({
    required int categoryId,
    int? pickupAddressId,
    int? destinationAddressId,
  }) async => fee;
}
