import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../order/order_repository.dart';
import 'helper_work_repository.dart';

enum HelperNewsKind { request, approved }

/// Kabar dari pemeriksaan berkala: permintaan baru masuk, atau Client
/// menyetujui penawaran.
typedef HelperNews = ({HelperNewsKind kind, ServerOrder job});

/// Mode Helper: status akun helper dan pekerjaan yang ditujukan padanya,
/// dipakai Beranda, Pesanan, dan halaman pekerjaan helper.
///
/// Belum ada notifikasi permintaan baru dari backend, jadi selama mode
/// Helper terbuka daftar diperiksa ulang tiap [pollEvery] ([startPolling]),
/// dan perubahan penting dikumpulkan untuk [takeNews].
class HelperStore extends ChangeNotifier {
  HelperStore(
    this._repo, {
    DateTime Function()? clock,
    this.pollEvery = const Duration(seconds: 15),
  }) : _clock = clock ?? DateTime.now;

  final HelperWorkRepository _repo;
  final DateTime Function() _clock;
  final Duration pollEvery;

  HelperStatus _status = HelperStatus.none;
  bool _statusLoaded = false;
  final List<ServerOrder> _jobs = [];
  bool _loading = false;
  ApiException? _error;
  Timer? _poll;

  /// Permintaan yang sudah pernah terlihat; null sampai daftar pertama
  /// dimuat, supaya isi awal tidak dianggap kabar baru.
  Set<int>? _seenRequests;

  /// Penawaran terkirim yang keputusannya belum terlihat helper.
  final Set<int> _awaitingDecision = {};
  final List<HelperNews> _news = [];

  DateTime get now => _clock();
  HelperStatus get status => _status;

  /// [status] sudah pernah dimuat dari server.
  bool get statusLoaded => _statusLoaded;
  bool get loading => _loading;
  ApiException? get error => _error;

  /// Terbaru di atas.
  List<ServerOrder> get jobs => List.unmodifiable(_jobs);

  ServerOrder? byId(int id) {
    for (final o in _jobs) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Penawaran helper ini di [order], kalau ada.
  OrderOffer? myOffer(ServerOrder order) {
    final me = _status.profileId;
    for (final o in order.offers) {
      if (o.helperId == me) return o;
    }
    return null;
  }

  bool _waitingDecision(ServerOrder o) =>
      o.status == OrderStatus.awaitingQuote &&
      myOffer(o)?.status == OfferStatus.submitted;

  /// Permintaan baru yang belum ditawar atau ditolak.
  List<ServerOrder> get toReview => [
    for (final o in _jobs)
      if (o.status.isWaiting && !_waitingDecision(o)) o,
  ];

  /// Penawaran terkirim, menunggu pelanggan.
  List<ServerOrder> get waitingDecision => [
    for (final o in _jobs)
      if (_waitingDecision(o)) o,
  ];

  /// Sudah disetujui sampai menunggu konfirmasi pelanggan.
  List<ServerOrder> get active => [
    for (final o in _jobs)
      if (!o.status.isTerminal && !o.status.isWaiting) o,
  ];

  List<ServerOrder> get done => [
    for (final o in _jobs)
      if (o.status.isTerminal) o,
  ];

  /// Pendapatan bersih yang sudah cair (pesanan selesai).
  List<ServerOrder> get paidOut => [
    for (final o in _jobs)
      if (o.status == OrderStatus.completed) o,
  ];

  /// Ditandai selesai, menunggu konfirmasi pelanggan.
  List<ServerOrder> get pendingPayout => [
    for (final o in _jobs)
      if (o.status == OrderStatus.awaitingConfirmation) o,
  ];

  int get paidOutTotal => paidOut.fold(0, (sum, o) => sum + o.netPayout);

  /// Kabar sejak pengambilan terakhir, lama ke baru; sekali ambil lalu
  /// dikosongkan.
  List<HelperNews> takeNews() {
    final news = [..._news];
    _news.clear();
    return news;
  }

  void _collectNews() {
    final seen = _seenRequests;
    final requests = toReview;
    if (seen != null) {
      for (final o in requests) {
        if (!seen.contains(o.id)) {
          _news.add((kind: HelperNewsKind.request, job: o));
        }
      }
    }
    _seenRequests = {...?seen, for (final o in requests) o.id};

    for (final o in _jobs) {
      if (!_awaitingDecision.contains(o.id)) continue;
      if (o.status == OrderStatus.accepted) {
        _news.add((kind: HelperNewsKind.approved, job: o));
      }
      if (!_waitingDecision(o)) _awaitingDecision.remove(o.id);
    }
    _awaitingDecision.addAll([for (final o in waitingDecision) o.id]);
  }

  /// Akun yang belum pernah mendaftar jadi helper tetap berhasil, dengan
  /// `isVerifiedHelper` false.
  Future<void> loadStatus() async {
    _status = await _repo.status();
    _statusLoaded = true;
    notifyListeners();
  }

  /// [quiet]: pemeriksaan berkala; tidak menampilkan indikator memuat.
  Future<void> refresh({bool quiet = false}) async {
    if (!quiet) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      if (!_statusLoaded) await loadStatus();
      final fresh = await _repo.jobs();
      // Daftar tidak memuat pemesan maupun penawaran. Pekerjaan yang belum
      // selesai (biasanya sedikit) dibaca detailnya: nama Client tampil, dan
      // ketahuan permintaan mana yang sudah ditawar.
      final detailed = await Future.wait([
        for (final o in fresh)
          if (o.status.isTerminal) Future.value(o) else _repo.job(o.id),
      ]);
      final loaded = {for (final o in _jobs) o.id: o};
      _jobs
        ..clear()
        ..addAll([
          for (final o in detailed)
            // Detail (riwayat, pemesan) yang sudah ada dipertahankan.
            if (loaded[o.id] case final d?
                when d.status == o.status && d.history.isNotEmpty)
              d
            else
              o,
        ]);
      _collectNews();
      _error = null;
    } on ApiException catch (e) {
      if (!quiet) _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Detail satu pekerjaan: pemesan, alamat, riwayat, penawaran. Status
  /// helper ikut dimuat kalau belum, untuk mengenali penawaran sendiri.
  Future<ServerOrder> load(int id) async {
    if (!_statusLoaded) await loadStatus();
    final job = await _repo.job(id);
    final i = _jobs.indexWhere((o) => o.id == id);
    if (i < 0) {
      _jobs.insert(0, job);
    } else {
      _jobs[i] = job;
    }
    // Keputusan yang tampil di halaman pekerjaan bukan kabar lagi.
    if (_waitingDecision(job)) {
      _awaitingDecision.add(id);
    } else {
      _awaitingDecision.remove(id);
    }
    notifyListeners();
    return job;
  }

  Future<ServerOrder> submitOffer(int id, int price) async {
    await _repo.submitOffer(id, price);
    return load(id);
  }

  Future<ServerOrder> reject(int id) async {
    await _repo.reject(id);
    return load(id);
  }

  /// "Mulai Pengerjaan" dari perjalanan: tiba, lalu dikerjakan. Backend
  /// mewajibkan keduanya berurutan.
  Future<ServerOrder> startWork(int id) async {
    if (byId(id)?.status == OrderStatus.onTheWay) {
      await _repo.advance(id, OrderStatus.arrived);
    }
    await _repo.advance(id, OrderStatus.inProgress);
    return load(id);
  }

  Future<ServerOrder> advance(int id, OrderStatus status) async {
    await _repo.advance(id, status);
    return load(id);
  }

  Future<void> setAvailable(bool available) =>
      saveSettings(available: available);

  Future<void> saveSettings({bool? available, List<int>? categoryIds}) async {
    await _repo.updateProfile(available: available, categoryIds: categoryIds);
    await loadStatus();
  }

  void startPolling() {
    _poll ??= Timer.periodic(pollEvery, (_) => refresh(quiet: true));
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// Kosongkan, misal saat keluar akun.
  void reset() {
    stopPolling();
    _status = HelperStatus.none;
    _statusLoaded = false;
    _jobs.clear();
    _seenRequests = null;
    _awaitingDecision.clear();
    _news.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
