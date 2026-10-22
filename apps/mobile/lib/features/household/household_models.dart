import 'package:flutter/material.dart';

import '../order/order_models.dart';

/// Layanan di dalam kategori Household.
enum HouseholdService {
  pindahan(
    label: 'Pindahan',
    icon: Icons.local_shipping_rounded,
    iconColor: Color(0xFFFF4B4B),
    tileColor: Color(0xFFFFF1F1),
    headerColor: Color(0xFFFF4B4B),
    sizeLabel: 'Estimasi Muatan',
    addressLabel: 'Alamat Asal & Tujuan',
    addressHint: 'Cari lokasi anda',
  ),
  rumah(
    label: 'Rumah',
    icon: Icons.home_rounded,
    iconColor: Color(0xFF6C63FF),
    tileColor: Color(0xFFF1F1FF),
    headerColor: Color(0xFFCBC7FF),
    sizeLabel: 'Ukuran Rumah',
    addressLabel: 'Alamat Rumah',
    addressHint: 'Cari lokasi rumah anda',
  ),
  kamar(
    label: 'Kamar',
    icon: Icons.bed_rounded,
    iconColor: Color(0xFFFF9F43),
    tileColor: Color(0xFFFFF4EC),
    headerColor: Color(0xFFFFD3AE),
    sizeLabel: 'Ukuran Kamar',
    addressLabel: 'Alamat Kamar',
    addressHint: 'Cari lokasi kamar anda',
  ),
  pakaian(
    label: 'Pakaian',
    icon: Icons.local_laundry_service_rounded,
    iconColor: Color(0xFF1E9E4A),
    tileColor: Color(0xFFEFFBF2),
    // Hijau sangat muda, judul dan ikon status bar gelap di atasnya.
    headerColor: Color(0xFFCCFBDB),
    headerDarkText: true,
    sizeLabel: 'Estimasi Muatan',
    addressLabel: 'Alamat Rumah',
    addressHint: 'Cari lokasi rumah anda',
  );

  const HouseholdService({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.tileColor,
    required this.headerColor,
    required this.sizeLabel,
    required this.addressLabel,
    required this.addressHint,
    this.headerDarkText = false,
  });

  final String label;

  /// Ikon sementara: ilustrasi Figma untuk empat ubin ini belum diekspor.
  final IconData icon;
  final Color iconColor;
  final Color tileColor;
  final Color headerColor;
  final bool headerDarkText;
  final String sizeLabel;
  final String addressLabel;
  final String addressHint;

  /// Pilihan "Estimasi Muatan". Null: form memakai ukuran lebar × panjang.
  List<LoadOption>? get loadOptions => switch (this) {
    pindahan => LoadOption.moving,
    pakaian => LoadOption.laundry,
    rumah || kamar => null,
  };
}

enum ToolOption {
  provided('Alat disediakan'),
  notProvided('Alat tidak disediakan');

  const ToolOption(this.label);
  final String label;
}

/// Satu pilihan "Estimasi Muatan", dengan biaya tambahan tetap.
class LoadOption {
  const LoadOption(this.label, this.detail, this.fee);

  final String label;
  final String detail;
  final int fee;

  /// Pindahan: dihitung per kardus.
  static const moving = [
    LoadOption('Kecil', '1–3 Kardus/Tas', 0),
    LoadOption('Sedang', '4–8 Kardus', 20000),
    LoadOption('Besar', 'Perabotan besar', 40000),
  ];

  /// Pakaian: dihitung per kilogram.
  static const laundry = [
    LoadOption('Kecil', '<3 kg', 0),
    LoadOption('Sedang', '>3–6 kg', 10000),
    LoadOption('Besar', '>6 kg', 30000),
  ];
}

/// Kebutuhan armada Pindahan: tenaga saja, atau ikut membawa kendaraan.
enum FleetOption {
  laborOnly('Hanya tenaga', 0),
  withVehicle('Termasuk kendaraan', 50000);

  const FleetOption(this.label, this.ratePerKm);
  final String label;
  final int ratePerKm;

  /// Jarak asal–tujuan belum bisa dihitung (belum ada geocoding di app
  /// maupun backend). Sementara dianggap 1 km, sama seperti semua total di
  /// desain yang memakai Rp 50.000 untuk kendaraan.
  static const assumedDistanceKm = 1;

  int get estimatedCost => ratePerKm * assumedDistanceKm;
}

/// Satu baris biaya di luar biaya helper, misal "Kendaraan".
class PriceLine {
  const PriceLine(this.label, this.amount);

  final String label;
  final int amount;
}

/// Biaya di luar biaya helper (muatan, kendaraan). Biaya Rp 0 tidak
/// ditampilkan sebagai baris.
List<PriceLine> extraFees(LoadOption? load, FleetOption? fleet) => [
  if (load != null && load.fee > 0)
    PriceLine('Muatan - ${load.label}', load.fee),
  if (fleet != null && fleet.estimatedCost > 0)
    PriceLine('Kendaraan', fleet.estimatedCost),
];

enum AddressKind { current, home, office, recent }

class SavedAddress {
  const SavedAddress({
    required this.label,
    required this.fullAddress,
    required this.kind,
  });

  final String label;
  final String fullAddress;
  final AddressKind kind;
}

/// Helper yang dibayar per jam, mengikuti `GET /helpers` (`hourly_rate`,
/// `distance_km`, `rating_average`, `rating_count`, `completed_order_count`).
class HourlyHelper {
  const HourlyHelper({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.completedCount,
    required this.hourlyRate,
    required this.distanceKm,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final double rating;
  final int reviewCount;
  final int completedCount;
  final int hourlyRate;
  final double distanceKm;
}

/// Satu slot jadwal satu jam, misal 21 Okt 2026 08.00–09.00.
class TimeSlot {
  const TimeSlot({required this.day, required this.startHour});

  final DateTime day;
  final int startHour;

  DateTime get start => DateTime(day.year, day.month, day.day, startHour);

  String get hourLabel => '${_two(startHour)}.00 - ${_two(startHour + 1)}.00';

  @override
  bool operator ==(Object other) => other is TimeSlot && other.start == start;

  @override
  int get hashCode => start.hashCode;
}

enum PaymentGroup {
  /// Hanya ditawarkan untuk Delivery (lihat `PaymentMethodPage`).
  cashOnDelivery('Bayar di Tempat', 'Bayar saat pesanan tiba'),
  eWallet('E-Wallet', 'Pembayaran e-wallet'),
  bank('Bank', 'Transfer bank & virtual account');

  const PaymentGroup(this.label, this.description);
  final String label;
  final String description;
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.group,
    this.logo,
  });

  final String id;
  final String name;
  final PaymentGroup group;

  /// Aset SVG logo merchant. Null untuk Bayar di Tempat (pakai ikon toko).
  final String? logo;

  @override
  bool operator ==(Object other) => other is PaymentMethod && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Isi form pesanan Household yang sudah lengkap, siap dikonfirmasi.
///
/// Rumah/Kamar mengisi ukuran ([widthM], [lengthM]) dan [tools]. Pakaian
/// mengisi [load] dan [tools]. Pindahan mengisi [destination], [load], dan
/// [fleet]; [address] jadi lokasi awal.
class HouseholdOrderDraft {
  const HouseholdOrderDraft({
    required this.service,
    required this.address,
    required this.helper,
    required this.hours,
    this.widthM,
    this.lengthM,
    this.tools,
    this.destination,
    this.load,
    this.fleet,
    this.slot,
    this.note,
  });

  final HouseholdService service;
  final SavedAddress address;
  final double? widthM;
  final double? lengthM;
  final ToolOption? tools;
  final SavedAddress? destination;
  final LoadOption? load;
  final FleetOption? fleet;

  /// Null berarti "Sekarang": helper datang paling lama 1 jam.
  final TimeSlot? slot;
  final HourlyHelper helper;
  final int hours;
  final String? note;

  bool get isMove => service == HouseholdService.pindahan;

  int get helperCost => helper.hourlyRate * hours;

  /// Biaya di luar biaya helper (muatan, kendaraan).
  List<PriceLine> get fees => extraFees(load, fleet);

  /// Alamat masih bisa diganti di halaman Detail Pesanan.
  HouseholdOrderDraft copyWith({
    SavedAddress? address,
    SavedAddress? destination,
  }) => HouseholdOrderDraft(
    service: service,
    address: address ?? this.address,
    widthM: widthM,
    lengthM: lengthM,
    tools: tools,
    destination: destination ?? this.destination,
    load: load,
    fleet: fleet,
    slot: slot,
    helper: helper,
    hours: hours,
    note: note,
  );

  String get timeLabel =>
      slot == null ? 'Sekarang' : '${dateLabel(slot!.day)} ${slot!.hourLabel}';
}

/// Rincian harga pesanan. Potongan voucher hanya berlaku untuk biaya awal
/// (helper + [fees]), tidak untuk durasi tambahan.
class PriceBreakdown {
  const PriceBreakdown({
    required this.hourlyRate,
    required this.baseHours,
    required this.extraHours,
    this.fees = const [],
    this.voucher,
  });

  final int hourlyRate;
  final int baseHours;

  /// Tiap tambahan durasi jadi satu baris tersendiri.
  final List<int> extraHours;
  final List<PriceLine> fees;
  final Voucher? voucher;

  int get baseCost => hourlyRate * baseHours;
  int get feeCost => fees.fold(0, (sum, f) => sum + f.amount);
  int get discount => voucher?.discountFor(baseCost + feeCost) ?? 0;
  int get extraCost => extraHours.fold(0, (sum, h) => sum + h * hourlyRate);
  int get total => baseCost + feeCost - discount + extraCost;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// 21 Oktober 2026 -> "21 Okt 2026".
String dateLabel(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "3,5" atau "3.5" -> 3.5; teks kosong atau bukan angka -> null.
double? parseMeter(String text) => double.tryParse(text.replaceAll(',', '.'));

/// 10.0 -> "10"; 3.5 -> "3,5" (desimal pakai koma, gaya Indonesia).
String meterLabel(double m) => m == m.roundToDouble()
    ? m.toInt().toString()
    : m.toStringAsFixed(1).replaceAll('.', ',');

/// 10:15 -> "10.15".
String clockLabel(DateTime d) => '${_two(d.hour)}.${_two(d.minute)}';
