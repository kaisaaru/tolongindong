import 'package:flutter/material.dart';

import '../order/order_models.dart';

/// Layanan di dalam kategori Household. Baru Rumah dan Kamar yang punya
/// desain form; Pindahan dan Pakaian masih "segera hadir".
enum HouseholdService {
  pindahan(
    label: 'Pindahan',
    icon: Icons.local_shipping_rounded,
    iconColor: Color(0xFFFF4B4B),
    tileColor: Color(0xFFFFF1F1),
    headerColor: Color(0xFFFFB5B5),
    sizeLabel: 'Ukuran Barang',
    addressLabel: 'Alamat Jemput',
  ),
  rumah(
    label: 'Rumah',
    icon: Icons.home_rounded,
    iconColor: Color(0xFF6C63FF),
    tileColor: Color(0xFFF1F1FF),
    headerColor: Color(0xFFCBC7FF),
    sizeLabel: 'Ukuran Rumah',
    addressLabel: 'Alamat Rumah',
  ),
  kamar(
    label: 'Kamar',
    icon: Icons.bed_rounded,
    iconColor: Color(0xFFFF9F43),
    tileColor: Color(0xFFFFF4EC),
    headerColor: Color(0xFFFFD3AE),
    sizeLabel: 'Ukuran Kamar',
    addressLabel: 'Alamat Kamar',
  ),
  pakaian(
    label: 'Pakaian',
    icon: Icons.local_laundry_service_rounded,
    iconColor: Color(0xFF1E9E4A),
    tileColor: Color(0xFFEFFBF2),
    headerColor: Color(0xFFB7EBC6),
    sizeLabel: 'Jumlah Pakaian',
    addressLabel: 'Alamat Jemput',
  );

  const HouseholdService({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.tileColor,
    required this.headerColor,
    required this.sizeLabel,
    required this.addressLabel,
  });

  final String label;

  /// Ikon sementara: ilustrasi Figma untuk empat ubin ini belum diekspor.
  final IconData icon;
  final Color iconColor;
  final Color tileColor;
  final Color headerColor;
  final String sizeLabel;
  final String addressLabel;

  /// Layanan yang form-nya sudah ada desainnya.
  bool get isAvailable => this == rumah || this == kamar;
}

enum ToolOption {
  provided('Alat disediakan'),
  notProvided('Alat tidak disediakan');

  const ToolOption(this.label);
  final String label;
}

enum AddressKind { home, office, recent }

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
    required this.brandColor,
  });

  final String id;
  final String name;
  final PaymentGroup group;

  /// Warna penanda logo. Logo asli belum diekspor dari Figma.
  final Color brandColor;

  @override
  bool operator ==(Object other) => other is PaymentMethod && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Isi form pesanan Household yang sudah lengkap, siap dikonfirmasi.
class HouseholdOrderDraft {
  const HouseholdOrderDraft({
    required this.service,
    required this.address,
    required this.widthM,
    required this.lengthM,
    required this.helper,
    required this.hours,
    this.tools,
    this.slot,
    this.note,
  });

  final HouseholdService service;
  final SavedAddress address;
  final double widthM;
  final double lengthM;
  final ToolOption? tools;

  /// Null berarti "Sekarang": helper datang paling lama 1 jam.
  final TimeSlot? slot;
  final HourlyHelper helper;
  final int hours;
  final String? note;

  int get helperCost => helper.hourlyRate * hours;

  /// Alamat masih bisa diganti di halaman Detail Pesanan.
  HouseholdOrderDraft withAddress(SavedAddress address) => HouseholdOrderDraft(
    service: service,
    address: address,
    widthM: widthM,
    lengthM: lengthM,
    tools: tools,
    slot: slot,
    helper: helper,
    hours: hours,
    note: note,
  );

  String get timeLabel =>
      slot == null ? 'Sekarang' : '${dateLabel(slot!.day)} ${slot!.hourLabel}';
}

/// Rincian harga pesanan. Potongan voucher hanya berlaku untuk biaya awal,
/// tidak untuk durasi tambahan.
class PriceBreakdown {
  const PriceBreakdown({
    required this.hourlyRate,
    required this.baseHours,
    required this.extraHours,
    this.voucher,
  });

  final int hourlyRate;
  final int baseHours;

  /// Tiap tambahan durasi jadi satu baris tersendiri.
  final List<int> extraHours;
  final Voucher? voucher;

  int get baseCost => hourlyRate * baseHours;
  int get discount => voucher?.discountFor(baseCost) ?? 0;
  int get extraCost => extraHours.fold(0, (sum, h) => sum + h * hourlyRate);
  int get total => baseCost - discount + extraCost;
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
