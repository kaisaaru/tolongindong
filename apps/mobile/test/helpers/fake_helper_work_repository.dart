import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/helper/helper_work_repository.dart';
import 'package:mobile/features/order/order_repository.dart';

import 'fake_order_repository.dart';

/// Profil helper uji: Agus, tersedia, Delivery + Household.
const testHelperStatus = HelperStatus(
  isVerifiedHelper: true,
  profileId: 'h-1',
  available: true,
  hourlyRate: 40000,
  rating: 5,
  ratingCount: 4,
  completedCount: 12,
  categories: [
    HelperCategory(id: 1, code: 'delivery', name: 'Delivery'),
    HelperCategory(id: 3, code: 'household', name: 'Household'),
  ],
);

/// Pengganti [HelperWorkRepository] untuk widget test. Pekerjaan di memori;
/// sisi Client (menyetujui penawaran) disimulasikan lewat [approveOffer].
class FakeHelperWorkRepository implements HelperWorkRepository {
  FakeHelperWorkRepository({
    this.helperStatus = HelperStatus.none,
    List<ServerOrder> jobs = const [],
    DateTime Function()? clock,
  }) : _jobs = FakeOrderRepository(orders: jobs, clock: clock),
       _clock = clock ?? (() => DateTime(2026, 10, 22, 9, 47));

  HelperStatus helperStatus;
  final FakeOrderRepository _jobs;
  final DateTime Function() _clock;

  /// Permintaan yang masuk, berurutan, misal `('offer', 1, 100000)`.
  final calls = <(String, int, Object?)>[];
  final profileUpdates = <({bool? available, List<int>? categoryIds})>[];

  /// Kalau diisi, aksi berikutnya gagal dengan error ini (sekali).
  ApiException? failNext;

  final _offers = <int, OrderOffer>{};
  int _nextOffer = 1;

  void _maybeFail() {
    final fail = failNext;
    if (fail != null) {
      failNext = null;
      throw fail;
    }
  }

  ServerOrder _withOffers(ServerOrder o) {
    final offer = _offers[o.id];
    return ServerOrder(
      id: o.id,
      number: o.number,
      status: o.status,
      categoryCode: o.categoryCode,
      categoryName: o.categoryName,
      description: o.description,
      price: o.price,
      createdAt: o.createdAt,
      cancellationFee: o.cancellationFee,
      helper: o.helper,
      pickup: o.pickup,
      destination: o.destination,
      history: o.history,
      client: o.client ?? const OrderClient(id: 'c-1', name: 'Nadia Putri'),
      // Seperti server: penawaran ulang menimpa penawaran helper yang sama.
      offers: [
        for (final x in o.offers)
          if (offer == null || x.helperId != offer.helperId) x,
        ?offer,
      ],
      estimatedPrice: o.estimatedPrice,
      helperPayout: o.helperPayout,
      platformCommission: o.platformCommission,
      respondBy: o.respondBy,
      helperFinishedAt: o.helperFinishedAt,
      allowedNext: o.allowedNext,
    );
  }

  /// Client menyetujui penawaran: pesanan diterima dengan harga itu.
  void approveOffer(int id) {
    final offer = _offers.remove(id)!;
    _jobs.advance(id, OrderStatus.accepted, price: offer.price);
  }

  /// Status berpindah dari sisi lain (Client, admin).
  void setStatus(int id, OrderStatus status) => _jobs.advance(id, status);

  /// Client baru saja memesan helper ini.
  void addJob(ServerOrder job) => _jobs.orders.insert(0, job);

  @override
  Future<HelperStatus> status() async => helperStatus;

  @override
  Future<void> updateProfile({bool? available, List<int>? categoryIds}) async {
    _maybeFail();
    profileUpdates.add((available: available, categoryIds: categoryIds));
    final s = helperStatus;
    helperStatus = HelperStatus(
      isVerifiedHelper: s.isVerifiedHelper,
      profileId: s.profileId,
      available: available ?? s.available,
      hourlyRate: s.hourlyRate,
      rating: s.rating,
      ratingCount: s.ratingCount,
      completedCount: s.completedCount,
      categories: categoryIds == null
          ? s.categories
          : [
              for (final id in categoryIds)
                HelperCategory(
                  id: id,
                  code: const {1: 'delivery', 2: 'personal'}[id] ?? 'household',
                  name: const {1: 'Delivery', 2: 'Personal'}[id] ?? 'Household',
                ),
            ],
    );
  }

  @override
  Future<List<ServerOrder>> jobs({int perPage = 100}) async => [
    for (final o in await _jobs.list()) _withOffers(o),
  ];

  @override
  Future<ServerOrder> job(int id) async => _withOffers(await _jobs.detail(id));

  @override
  Future<void> submitOffer(int id, int price, {String? message}) async {
    _maybeFail();
    calls.add(('offer', id, price));
    _offers[id] = OrderOffer(
      id: _nextOffer++,
      helperId: helperStatus.profileId ?? '',
      price: price,
      status: OfferStatus.submitted,
      message: message,
      validUntil: _clock().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<void> reject(int id, {String? reason}) async {
    _maybeFail();
    calls.add(('reject', id, reason));
    _jobs.advance(id, OrderStatus.cancelledByHelper);
  }

  @override
  Future<void> advance(int id, OrderStatus status) async {
    _maybeFail();
    calls.add(('status', id, status));
    _jobs.advance(id, status);
  }
}
