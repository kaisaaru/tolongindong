import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'order_repository.dart';

/// Pesanan pengguna dari server, dipakai bersama beranda (banner), tab
/// Aktifitas, dan halaman detail pesanan.
///
/// Belum ada push notification: selama masih ada pesanan berjalan, daftar
/// diperiksa ulang tiap [pollEvery] supaya perubahan dari helper (menerima,
/// berangkat, selesai) ikut terlihat.
class OrderStore extends ChangeNotifier {
  OrderStore(
    this._repo, {
    DateTime Function()? clock,
    this.pollEvery = const Duration(seconds: 15),
  }) : _clock = clock ?? DateTime.now;

  final OrderRepository _repo;
  final DateTime Function() _clock;
  final Duration pollEvery;

  final List<ServerOrder> _orders = [];

  /// Pesanan yang sudah dinilai di sesi ini. Backend tidak mengirim rating
  /// di JSON pesanan, jadi ajakan memberi rating tidak diulang dari sini.
  final Set<int> _rated = {};
  Timer? _poll;
  bool _loading = false;
  ApiException? _error;

  DateTime get now => _clock();
  bool get loading => _loading;
  ApiException? get error => _error;

  /// Terbaru di atas.
  List<ServerOrder> get active => [
    for (final o in _orders)
      if (!o.status.isTerminal) o,
  ];

  List<ServerOrder> get history => [
    for (final o in _orders)
      if (o.status.isTerminal) o,
  ];

  bool get hasActive => _orders.any((o) => !o.status.isTerminal);

  ServerOrder? byId(int id) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  bool isRated(int id) => _rated.contains(id);

  /// [quiet]: pemeriksaan berkala; tidak menampilkan indikator memuat.
  Future<void> refresh({bool quiet = false}) async {
    if (!quiet) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final fresh = await _repo.list();
      // Detail (riwayat status) yang sudah dimuat dipertahankan.
      final detailed = {
        for (final o in _orders)
          if (o.history.isNotEmpty) o.id: o,
      };
      _orders
        ..clear()
        ..addAll([
          for (final o in fresh)
            if (detailed[o.id] case final d? when d.status == o.status)
              d
            else
              o,
        ]);
      _error = null;
    } on ApiException catch (e) {
      if (!quiet) _error = e;
    } finally {
      _loading = false;
      _syncPolling();
      notifyListeners();
    }
  }

  /// Detail satu pesanan, termasuk riwayat status dan helper.
  Future<ServerOrder> load(int id) async {
    final order = await _repo.detail(id);
    _upsert(order);
    return order;
  }

  /// Buat pesanan ke helper pilihan pelanggan. Gagal: [ApiException]
  /// dilempar (misal saldo kurang, helper sedang tidak tersedia).
  Future<ServerOrder> place({
    required int categoryId,
    required String helperId,
    required String description,
    required int price,
    int? pickupAddressId,
    int? destinationAddressId,
  }) async {
    final id = await _repo.create(
      categoryId: categoryId,
      helperId: helperId,
      description: description,
      price: price,
      pickupAddressId: pickupAddressId,
      destinationAddressId: destinationAddressId,
    );
    return load(id);
  }

  Future<ServerOrder> cancel(int id, {String? reason}) async {
    await _repo.cancel(id, reason: reason);
    return load(id);
  }

  /// Setujui penawaran harga helper; saldo sebesar penawaran ditahan.
  Future<ServerOrder> selectOffer(int id, int offerId) async {
    await _repo.selectOffer(id, offerId);
    return load(id);
  }

  Future<ServerOrder> confirm(int id) async {
    await _repo.confirm(id);
    return load(id);
  }

  /// Sudah pernah dinilai (`ALREADY_RATED`) dianggap berhasil.
  Future<void> rate(int id, int score) async {
    try {
      await _repo.rate(id, score);
    } on ApiException catch (e) {
      if (e.code != 'ALREADY_RATED') rethrow;
    }
    _rated.add(id);
    notifyListeners();
  }

  /// Rating dilewati: jangan ditawarkan lagi di sesi ini.
  void skipRating(int id) {
    _rated.add(id);
    notifyListeners();
  }

  void _upsert(ServerOrder order) {
    final i = _orders.indexWhere((o) => o.id == order.id);
    if (i < 0) {
      _orders.insert(0, order);
    } else {
      _orders[i] = order;
    }
    _syncPolling();
    notifyListeners();
  }

  void _syncPolling() {
    if (hasActive) {
      _poll ??= Timer.periodic(pollEvery, (_) => refresh(quiet: true));
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  /// Kosongkan, misal saat keluar akun.
  void reset() {
    _poll?.cancel();
    _poll = null;
    _orders.clear();
    _rated.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
