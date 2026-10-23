import '../../core/api/api_client.dart';
import '../household/household_models.dart';

/// Status pesanan backend (`OrderStatus` di Laravel), dari sisi pelanggan.
enum OrderStatus {
  draft('draft', 'Menunggu helper menerima'),
  searching('searching', 'Mencari helper'),
  awaitingQuote('awaiting_quote', 'Menunggu helper menerima'),
  pendingConfirmation('pending_confirmation', 'Menunggu helper menerima'),
  accepted('accepted', 'Helper bersiap berangkat'),
  onTheWay('on_the_way', 'Helper menuju lokasi'),
  arrived('arrived', 'Helper sudah sampai'),
  inProgress('in_progress', 'Sedang dikerjakan'),
  priceAdjustment('price_adjustment', 'Sedang dikerjakan'),
  awaitingConfirmation('awaiting_confirmation', 'Menunggu konfirmasimu'),
  completed('completed', 'Selesai'),
  cancelledByClient('cancelled_by_client', 'Dibatalkan'),
  cancelledByHelper('cancelled_by_helper', 'Dibatalkan helper'),
  cancelledByAdmin('cancelled_by_admin', 'Dibatalkan admin'),
  expired('expired', 'Kedaluwarsa'),
  disputed('disputed', 'Dalam sengketa'),
  refunded('refunded', 'Dana dikembalikan'),
  partiallyRefunded('partially_refunded', 'Dana dikembalikan sebagian'),
  unknown('', 'Diproses');

  const OrderStatus(this.code, this.label);
  final String code;

  /// Satu kalimat untuk pelanggan.
  final String label;

  static OrderStatus fromCode(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => unknown);

  bool get isTerminal => switch (this) {
    completed ||
    cancelledByClient ||
    cancelledByHelper ||
    cancelledByAdmin ||
    expired ||
    refunded ||
    partiallyRefunded => true,
    _ => false,
  };

  bool get isCancelled => switch (this) {
    cancelledByClient ||
    cancelledByHelper ||
    cancelledByAdmin ||
    expired => true,
    _ => false,
  };

  /// Helper belum menerima: batal tanpa biaya.
  bool get isWaiting => switch (this) {
    draft || searching || awaitingQuote || pendingConfirmation => true,
    _ => false,
  };

  /// Pelanggan boleh menyatakan selesai (`POST /orders/{id}/confirm`).
  bool get canConfirm => this == inProgress || this == awaitingConfirmation;
}

/// Helper yang mengerjakan pesanan.
class OrderHelper {
  const OrderHelper({
    required this.id,
    required this.name,
    required this.rating,
    this.photoUrl,
  });

  /// `helper` dari JSON pesanan: profil helper beserta `user`.
  factory OrderHelper.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OrderHelper(
      id: json['id'] as String,
      name: user['full_name'] as String? ?? 'Helper',
      photoUrl: user['photo_url'] as String?,
      rating: double.tryParse('${json['rating_average']}') ?? 0,
    );
  }

  /// `helper_profiles.id`, untuk membuka chat.
  final String id;
  final String name;
  final String? photoUrl;
  final double rating;
}

/// Pelanggan pemesan, dilihat dari sisi helper (`client` di detail).
class OrderClient {
  const OrderClient({required this.id, required this.name, this.photoUrl});

  factory OrderClient.fromJson(Map<String, dynamic> json) => OrderClient(
    id: json['id'] as String? ?? '',
    name: json['full_name'] as String? ?? 'Client',
    photoUrl: json['photo_url'] as String?,
  );

  final String id;
  final String name;
  final String? photoUrl;
}

enum OfferStatus {
  submitted('submitted'),
  selected('selected'),
  confirmed('confirmed'),
  notSelected('not_selected'),
  withdrawn('withdrawn'),
  expired('expired'),
  declined('declined');

  const OfferStatus(this.code);
  final String code;

  static OfferStatus fromCode(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => expired);
}

/// Penawaran harga helper untuk pesanan direct (`offers` di detail).
/// Pelanggan punya waktu sampai [validUntil] untuk menyetujuinya.
class OrderOffer {
  const OrderOffer({
    required this.id,
    required this.helperId,
    required this.price,
    required this.status,
    this.message,
    this.validUntil,
  });

  factory OrderOffer.fromJson(Map<String, dynamic> json) => OrderOffer(
    id: (json['id'] as num).toInt(),
    helperId: json['helper_id'] as String? ?? '',
    price: (json['proposed_price'] as num?)?.toInt() ?? 0,
    status: OfferStatus.fromCode(json['offer_status'] as String?),
    message: json['message'] as String?,
    validUntil: DateTime.tryParse('${json['valid_until']}')?.toLocal(),
  );

  final int id;

  /// `helper_profiles.id` yang menawar.
  final String helperId;
  final int price;
  final OfferStatus status;
  final String? message;
  final DateTime? validUntil;
}

/// Komisi platform 10% dari harga, dibulatkan ke bawah seperti
/// `SettlementCalculator` di backend.
int platformCommissionOf(int price) => price * 10 ~/ 100;

/// Pesanan dari server (`GET /orders`, `GET /orders/{id}`).
///
/// Backend belum punya kolom untuk detail form (ukuran, alat, jadwal,
/// durasi, penerima, barang). App menulisnya ke `task_description` sebagai
/// baris "Label: isi" di bawah judul "Kategori - Layanan" (lihat
/// [OrderDescription]), lalu membacanya kembali di sini.
class ServerOrder {
  const ServerOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.categoryCode,
    required this.categoryName,
    required this.description,
    required this.price,
    required this.createdAt,
    this.cancellationFee = 0,
    this.helper,
    this.pickup,
    this.destination,
    this.history = const [],
    this.client,
    this.offers = const [],
    this.estimatedPrice = 0,
    this.helperPayout = 0,
    this.platformCommission = 0,
    this.respondBy,
    this.helperFinishedAt,
    this.allowedNext = const [],
  });

  /// [allowedNext]: `allowed_next_statuses` dari detail pesanan.
  factory ServerOrder.fromJson(
    Map<String, dynamic> json, {
    List<dynamic>? allowedNext,
  }) {
    Map<String, dynamic>? map(Object? o) =>
        (o as Map?)?.cast<String, dynamic>();
    final category = map(json['service_category']) ?? const {};
    final total = (json['total_amount'] as num?)?.toInt() ?? 0;
    final pickup = map(json['pickup_address']);
    final destination = map(json['destination_address']);
    final helper = map(json['helper']);
    final client = map(json['client']);
    return ServerOrder(
      id: (json['id'] as num).toInt(),
      number: json['order_number'] as String? ?? '',
      status: OrderStatus.fromCode(json['status'] as String?),
      categoryCode: category['code'] as String? ?? '',
      categoryName: category['name'] as String? ?? 'Pesanan',
      description: json['task_description'] as String? ?? '',
      // Sebelum helper menerima, harga final belum ada.
      price: total > 0
          ? total
          : (json['client_estimated_price'] as num?)?.toInt() ?? 0,
      cancellationFee: (json['cancellation_fee'] as num?)?.toInt() ?? 0,
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      helper: helper == null ? null : OrderHelper.fromJson(helper),
      pickup: pickup == null ? null : SavedAddress.fromJson(pickup),
      destination: destination == null
          ? null
          : SavedAddress.fromJson(destination),
      history: [
        for (final e in json['status_histories'] as List? ?? const [])
          (
            status: OrderStatus.fromCode((e as Map)['to_status'] as String?),
            at: _date(e['created_at']) ?? DateTime.now(),
          ),
      ],
      client: client == null ? null : OrderClient.fromJson(client),
      offers: [
        for (final e in json['offers'] as List? ?? const [])
          OrderOffer.fromJson((e as Map).cast<String, dynamic>()),
      ],
      estimatedPrice: (json['client_estimated_price'] as num?)?.toInt() ?? 0,
      helperPayout: (json['helper_payout'] as num?)?.toInt() ?? 0,
      platformCommission: (json['platform_commission'] as num?)?.toInt() ?? 0,
      respondBy: _date(json['offer_window_expires_at']),
      helperFinishedAt: _date(json['helper_finished_at']),
      allowedNext: [
        for (final code in allowedNext ?? const [])
          OrderStatus.fromCode('$code'),
      ],
    );
  }

  static DateTime? _date(Object? value) =>
      DateTime.tryParse('$value')?.toLocal();

  final int id;

  /// Misal "ORD-20261022-NOS7".
  final String number;
  final OrderStatus status;

  /// `delivery`, `personal`, atau `household`.
  final String categoryCode;
  final String categoryName;
  final String description;

  /// Total yang dibayar dari TD-Wallet.
  final int price;
  final int cancellationFee;
  final DateTime createdAt;
  final OrderHelper? helper;
  final SavedAddress? pickup;
  final SavedAddress? destination;

  /// Riwayat status, lama ke baru. Hanya ada di detail pesanan.
  final List<({OrderStatus status, DateTime at})> history;

  /// Pemesan; hanya ada di detail pesanan.
  final OrderClient? client;

  /// Penawaran harga helper; hanya ada di detail pesanan.
  final List<OrderOffer> offers;

  /// Perkiraan harga dari pelanggan, bukan harga yang disepakati.
  final int estimatedPrice;

  /// Pendapatan bersih helper dan komisi platform dari server. Pesanan
  /// lewat penawaran baru terisi saat selesai; pakai [commission] dan
  /// [netPayout] untuk tampilan.
  final int helperPayout;
  final int platformCommission;

  /// Komisi 10%: dari server kalau sudah ada, kalau belum dihitung.
  int get commission =>
      platformCommission > 0 ? platformCommission : platformCommissionOf(price);

  /// Pendapatan bersih helper.
  int get netPayout => helperPayout > 0 ? helperPayout : price - commission;

  /// Batas helper merespons permintaan direct (5 menit sejak dibuat).
  /// Ditampilkan saja: backend belum menutup permintaan yang lewat batas.
  final DateTime? respondBy;

  /// Kapan helper menandai pekerjaan selesai.
  final DateTime? helperFinishedAt;

  /// Status berikutnya yang boleh dituju; hanya ada di detail pesanan.
  final List<OrderStatus> allowedNext;

  /// Penawaran yang masih menunggu keputusan pelanggan.
  OrderOffer? get pendingOffer {
    for (final o in offers) {
      if (o.status == OfferStatus.submitted) return o;
    }
    return null;
  }

  OrderDescription get parsed => OrderDescription.parse(description);

  /// "Household - Rumah", atau nama kategori untuk pesanan dari tempat lain.
  String get title => parsed.title ?? categoryName;

  /// Kapan pesanan terakhir masuk [status], kalau ada di riwayat.
  DateTime? enteredAt(OrderStatus status) {
    for (final h in history.reversed) {
      if (h.status == status) return h.at;
    }
    return null;
  }
}

/// Isi `task_description` yang ditulis app: judul, lalu baris
/// "Label: isi". Teks bebas (pesanan dari klien lain) jadi [freeText].
class OrderDescription {
  const OrderDescription({this.title, this.rows = const [], this.freeText});

  factory OrderDescription.parse(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const OrderDescription();
    final title = lines.first;
    if (!_titlePattern.hasMatch(title)) {
      return OrderDescription(freeText: text.trim());
    }
    return OrderDescription(
      title: title,
      rows: [
        for (final line in lines.skip(1))
          if (line.indexOf(': ') case final i when i > 0)
            (label: line.substring(0, i), value: line.substring(i + 2)),
      ],
    );
  }

  /// Judul tulisan app, misal "Household - Rumah" atau "Personal".
  static final _titlePattern = RegExp(
    r'^(Household|Personal|Delivery)( - .+)?$',
  );

  /// Susun deskripsi untuk `POST /orders`. Baris dengan isi kosong dilewati.
  static String compose(String title, List<(String, String?)> rows) => [
    title,
    for (final (label, value) in rows)
      if (value != null && value.trim().isNotEmpty)
        '$label: ${value.trim().replaceAll('\n', ' ')}',
  ].join('\n');

  final String? title;
  final List<({String label, String value})> rows;
  final String? freeText;

  String? valueOf(String label) {
    for (final r in rows) {
      if (r.label == label) return r.value;
    }
    return null;
  }

  /// Dari baris "Durasi: 2 Jam"; untuk hitung mundur Household.
  int? get durationHours {
    final match = RegExp(r'(\d+)').firstMatch(valueOf('Durasi') ?? '');
    return match == null ? null : int.parse(match.group(1)!);
  }
}

/// Pesanan pelanggan (`/orders`, API-ORD-01 s/d 09).
class OrderRepository {
  OrderRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Direct booking: pelanggan sudah memilih helper (DEC-21). Pesanan
  /// menunggu helper menerima; saldo TD-Wallet baru ditahan saat itu.
  Future<int> create({
    required int categoryId,
    required String helperId,
    required String description,
    required int price,
    int? pickupAddressId,
    int? destinationAddressId,
  }) async {
    final data = await _api.post(
      '/orders',
      body: {
        'category_id': categoryId,
        'booking_type': 'direct',
        'helper_id': helperId,
        'task_description': description,
        'client_estimated_price': price,
        'pickup_address_id': ?pickupAddressId,
        'destination_address_id': ?destinationAddressId,
      },
    );
    return ((data as Map)['id'] as num).toInt();
  }

  /// Terbaru di atas.
  Future<List<ServerOrder>> list({int perPage = 30}) async {
    final data = await _api.get('/orders', query: {'per_page': perPage});
    return [
      for (final e in (data as Map)['data'] as List? ?? const [])
        ServerOrder.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  Future<ServerOrder> detail(int id) async {
    final data = await _api.get('/orders/$id');
    return ServerOrder.fromJson(
      ((data as Map)['order'] as Map).cast<String, dynamic>(),
      allowedNext: data['allowed_next_statuses'] as List?,
    );
  }

  /// Setujui penawaran harga helper (`POST /orders/{id}/offers/{offer}/
  /// select`). Saldo TD-Wallet sebesar penawaran langsung ditahan.
  Future<void> selectOffer(int orderId, int offerId) async {
    await _api.post('/orders/$orderId/offers/$offerId/select');
  }

  /// Biaya pembatalan dihitung server (gratis sebelum helper menerima).
  Future<void> cancel(int id, {String? reason}) async {
    await _api.post('/orders/$id/cancel', body: {'reason': ?reason});
  }

  /// Pelanggan menyatakan pekerjaan selesai: dana diteruskan ke helper.
  Future<void> confirm(int id) async {
    await _api.post('/orders/$id/confirm');
  }

  Future<void> rate(int id, int score, {String? review}) async {
    await _api.post(
      '/orders/$id/rating',
      body: {'score': score, 'review': ?review},
    );
  }

  /// Ongkos acuan terendah (`POST /orders/estimate`): tarif dasar kategori
  /// ditambah Rp2.500 per km jarak asal-tujuan.
  Future<int> estimate({
    required int categoryId,
    int? pickupAddressId,
    int? destinationAddressId,
  }) async {
    final data = await _api.post(
      '/orders/estimate',
      body: {
        'category_id': categoryId,
        'pickup_address_id': ?pickupAddressId,
        'destination_address_id': ?destinationAddressId,
      },
    );
    final range = (data as Map)['estimated_price_range'] as Map;
    return (range['min'] as num).toInt();
  }
}
