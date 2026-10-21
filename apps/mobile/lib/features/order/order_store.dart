import 'dart:async';

import 'package:flutter/foundation.dart';

import '../delivery/delivery_models.dart';
import '../household/household_models.dart';
import 'order_models.dart';

enum ActiveStatus {
  /// Helper menuju lokasi. Selama [OrderStore.cancelWindow] pertama,
  /// pesanan masih bisa dibatalkan.
  onTheWay,

  /// Helper sedang bekerja; durasi berjalan mundur.
  working,

  /// Durasi habis; pelanggan memilih tambah waktu atau selesai.
  timeUp,

  /// Pelanggan menyatakan selesai, tinggal memberi rating.
  finished,
}

/// Pesanan yang sedang berjalan.
class ActiveOrder {
  ActiveOrder({
    required this.draft,
    required this.payment,
    required this.placedAt,
    this.voucher,
  });

  final HouseholdOrderDraft draft;
  final PaymentMethod payment;
  final Voucher? voucher;

  /// Waktu "dunia pesanan" saat dibuat. Lihat [OrderStore.now].
  final DateTime placedAt;

  final List<int> extraHours = [];

  /// Lama menunggu antara waktu habis dan durasi ditambah. Tambahan durasi
  /// dihitung mulai saat ditambah, bukan dari jam waktu habis.
  Duration waited = Duration.zero;

  /// True setelah pelanggan memilih "Selesai" saat waktu habis.
  bool ended = false;

  PriceBreakdown get price => PriceBreakdown(
    hourlyRate: draft.helper.hourlyRate,
    baseHours: draft.hours,
    extraHours: List.unmodifiable(extraHours),
    fees: draft.fees,
    voucher: voucher,
  );

  int get totalHours => extraHours.fold(draft.hours, (sum, h) => sum + h);

  /// Pesanan "Sekarang" dianggap tiba 30 menit setelah dibuat; pesanan
  /// terjadwal tiba di awal slotnya.
  DateTime get arriveAt =>
      draft.slot?.start ?? placedAt.add(OrderStore.travelTime);

  DateTime get finishAt =>
      arriveAt.add(Duration(hours: totalHours)).add(waited);

  DateTime get cancelDeadline => placedAt.add(OrderStore.cancelWindow);
}

/// Pesanan Personal yang sedang dikerjakan helper. Tanpa jam: selesai saat
/// pelanggan menekan "Selesai" lalu memberi rating.
class PersonalOrder {
  const PersonalOrder({
    required this.helper,
    required this.payment,
    required this.placedAt,
    this.voucher,
  });

  final HelperListing helper;
  final PaymentMethod payment;
  final Voucher? voucher;
  final DateTime placedAt;

  int get price => helper.price;
  int get discount => voucher?.discountFor(price) ?? 0;
  int get total => price - discount;
}

/// Pengantaran yang sudah dipesan. Desain pelacakan kurir belum ada, jadi
/// pesanan ini hanya tampil di Aktifitas sampai desainnya ada.
class DeliveryOrder {
  const DeliveryOrder({
    required this.draft,
    required this.payment,
    required this.placedAt,
    this.voucher,
  });

  final DeliveryDraft draft;
  final PaymentMethod payment;
  final Voucher? voucher;
  final DateTime placedAt;

  int get discount => draft.discountWith(voucher);
  int get total => draft.fee - discount;
}

enum HistoryOutcome { completed, cancelled }

class OrderRecord {
  const OrderRecord({
    required this.title,
    required this.categoryCode,
    required this.date,
    required this.total,
    required this.outcome,
    this.rating,
  });

  /// Misal "Household - Rumah" atau "Personal - Tugas Kuliah".
  final String title;

  /// Kode kategori backend, untuk ikon di riwayat.
  final String categoryCode;
  final DateTime date;
  final int total;
  final HistoryOutcome outcome;
  final int? rating;
}

/// Satu-satunya sumber pesanan aktif dan riwayat, dipakai bersama beranda,
/// tab Aktifitas, dan halaman pesanan. Satu pesanan Household ([active]) dan
/// satu pesanan Personal ([personal]) boleh berjalan bersamaan.
///
/// SIMULASI: backend belum dipakai. Status Household dihitung dari jam, dan jam
/// "dunia pesanan" berjalan [speed] kali lebih cepat supaya alurnya bisa
/// dicoba tanpa menunggu berjam-jam (1 detik = 1 menit). Saat disambung ke
/// backend, ganti dengan polling `GET /orders/{id}` dan baca `order.status`.
class OrderStore extends ChangeNotifier {
  OrderStore({this.speed = 60, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static final instance = OrderStore();

  static const travelTime = Duration(minutes: 30);
  static const cancelWindow = Duration(minutes: 10);

  final int speed;
  final DateTime Function() _clock;

  /// Pasangan titik acuan jam nyata dan jam dunia pesanan.
  DateTime? _realAnchor;
  DateTime? _worldAnchor;
  Timer? _ticker;

  ActiveOrder? _active;
  PersonalOrder? _personal;
  final List<DeliveryOrder> _deliveries = [];
  final List<OrderRecord> _history = [];

  ActiveOrder? get active => _active;
  PersonalOrder? get personal => _personal;

  /// Terbaru di atas. Boleh lebih dari satu.
  List<DeliveryOrder> get deliveries => List.unmodifiable(_deliveries.reversed);
  List<OrderRecord> get history => List.unmodifiable(_history.reversed);

  bool get hasActive =>
      _active != null || _personal != null || _deliveries.isNotEmpty;

  /// Jam dunia pesanan. Tanpa pesanan aktif, sama dengan jam nyata.
  DateTime get now {
    final real = _clock();
    final realAnchor = _realAnchor;
    final worldAnchor = _worldAnchor;
    if (realAnchor == null || worldAnchor == null) return real;
    return worldAnchor.add(real.difference(realAnchor) * speed);
  }

  ActiveStatus? get status {
    final order = _active;
    if (order == null) return null;
    final t = now;
    if (t.isBefore(order.arriveAt)) return ActiveStatus.onTheWay;
    if (t.isBefore(order.finishAt)) return ActiveStatus.working;
    return order.ended ? ActiveStatus.finished : ActiveStatus.timeUp;
  }

  bool get canCancel {
    final order = _active;
    return order != null && now.isBefore(order.cancelDeadline);
  }

  /// Sisa durasi kerja; nol kalau belum mulai atau sudah selesai.
  Duration get remaining {
    final order = _active;
    if (order == null || status != ActiveStatus.working) return Duration.zero;
    return order.finishAt.difference(now);
  }

  /// Hanya satu pesanan aktif dalam satu waktu.
  void place({
    required HouseholdOrderDraft draft,
    required PaymentMethod payment,
    Voucher? voucher,
  }) {
    assert(_active == null, 'Masih ada pesanan aktif.');
    final real = _clock();
    _realAnchor = real;
    _worldAnchor = real;
    _active = ActiveOrder(
      draft: draft,
      payment: payment,
      voucher: voucher,
      placedAt: real,
    );
    _startTicker();
    notifyListeners();
  }

  void cancel() {
    final order = _active;
    if (order == null) return;
    _archive(order, HistoryOutcome.cancelled);
  }

  void addHours(int hours) {
    final order = _active;
    if (order == null) return;
    final late = now.difference(order.finishAt);
    if (status == ActiveStatus.timeUp && late > Duration.zero) {
      order.waited += late;
    }
    order.extraHours.add(hours);
    notifyListeners();
  }

  /// Pelanggan memilih "Selesai" saat waktu habis: lanjut ke rating.
  void endWork() {
    final order = _active;
    if (order == null || status != ActiveStatus.timeUp) return;
    order.ended = true;
    notifyListeners();
  }

  /// Menutup pesanan yang sudah selesai, dengan atau tanpa rating.
  void complete({int? rating}) {
    final order = _active;
    if (order == null) return;
    _archive(order, HistoryOutcome.completed, rating: rating);
  }

  /// Pesanan Personal dari checkout. Nanti: `POST /orders`.
  void placePersonal({
    required HelperListing helper,
    required PaymentMethod payment,
    Voucher? voucher,
  }) {
    assert(_personal == null, 'Masih ada pesanan Personal aktif.');
    _personal = PersonalOrder(
      helper: helper,
      payment: payment,
      voucher: voucher,
      placedAt: _clock(),
    );
    notifyListeners();
  }

  /// Pesanan Delivery dari Detail Pesanan. Nanti: `POST /orders`.
  DeliveryOrder placeDelivery({
    required DeliveryDraft draft,
    required PaymentMethod payment,
    Voucher? voucher,
  }) {
    final order = DeliveryOrder(
      draft: draft,
      payment: payment,
      voucher: voucher,
      placedAt: _clock(),
    );
    _deliveries.add(order);
    notifyListeners();
    return order;
  }

  /// Pelanggan menekan "Selesai" dan memberi rating.
  void completePersonal({int? rating}) {
    final order = _personal;
    if (order == null) return;
    _history.add(
      OrderRecord(
        title: 'Personal - ${order.helper.subcategory}',
        categoryCode: 'personal',
        date: order.placedAt,
        total: order.total,
        outcome: HistoryOutcome.completed,
        rating: rating,
      ),
    );
    _personal = null;
    notifyListeners();
  }

  void _archive(ActiveOrder order, HistoryOutcome outcome, {int? rating}) {
    _history.add(
      OrderRecord(
        title: 'Household - ${order.draft.service.label}',
        categoryCode: 'household',
        date: order.placedAt,
        total: order.price.total,
        outcome: outcome,
        rating: rating,
      ),
    );
    _active = null;
    _realAnchor = null;
    _worldAnchor = null;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  /// Untuk pengujian.
  @visibleForTesting
  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _active = null;
    _personal = null;
    _deliveries.clear();
    _realAnchor = null;
    _worldAnchor = null;
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
