import 'package:flutter/material.dart';

import '../household/household_models.dart';

/// Ukuran paket. Desain hanya menulis dimensi ukuran S ("T = 20 cm
/// L = 40cm"); dimensi M dan L di sini perkiraan dan perlu dikonfirmasi.
enum ItemSize {
  s('S', 20, 40),
  m('M', 30, 50),
  l('L', 40, 60);

  const ItemSize(this.label, this.heightCm, this.widthCm);
  final String label;
  final int heightCm;
  final int widthCm;

  String get dimensions => 'T = $heightCm cm   L = $widthCm cm';
}

enum ItemType {
  pakaian('Pakaian', Icons.checkroom_outlined),
  makanan('Makanan', Icons.lunch_dining_outlined),
  elektronik('Elektronik', Icons.smartphone_outlined),
  obat('Obat-obatan', Icons.medication_outlined),
  dokumen('Dokumen', Icons.description_outlined);

  const ItemType(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Isi lembar "Barang apa ya mau dikirim?".
class DeliveryItem {
  const DeliveryItem({
    required this.size,
    required this.weightKg,
    required this.type,
  });

  final ItemSize size;
  final int weightKg;
  final ItemType type;

  /// "Ukuran M, berat 2 kg".
  String get summary => 'Ukuran ${size.label}, berat $weightKg kg';
}

/// Isi halaman "Penerima".
class Recipient {
  const Recipient({
    required this.name,
    required this.phone,
    this.floor,
    this.note,
  });

  final String name;
  final String phone;

  /// "Lantai atau no. rumah".
  final String? floor;

  /// Catatan untuk pengemudi.
  final String? note;
}

/// Kapan barang diantar: sekarang ([slot] null) atau terjadwal.
class DeliverySchedule {
  const DeliverySchedule.now() : slot = null;
  const DeliverySchedule.at(TimeSlot this.slot);

  final TimeSlot? slot;

  bool get isNow => slot == null;
}

/// "Antar sekarang" diantar sebelum jam bulat berikutnya ditambah satu jam:
/// pesan pukul 09.47 -> sebelum 11.00, seperti desain.
DateTime deliverBy(DateTime orderedAt) {
  final nextHour = DateTime(
    orderedAt.year,
    orderedAt.month,
    orderedAt.day,
    orderedAt.hour + 1,
  );
  return nextHour.add(const Duration(hours: 1));
}

/// Isi form Delivery yang sudah lengkap, siap dikonfirmasi.
class DeliveryDraft {
  const DeliveryDraft({
    required this.senderName,
    required this.senderPhone,
    required this.origin,
    required this.destination,
    required this.recipient,
    required this.schedule,
    required this.item,
    required this.fee,
  });

  /// Pengirim = pengguna yang masuk.
  final String senderName;
  final String? senderPhone;
  final SavedAddress origin;
  final SavedAddress destination;
  final Recipient recipient;
  final DeliverySchedule schedule;
  final DeliveryItem item;

  /// Ongkos kirim dari `POST /orders/estimate`.
  final int fee;

  String get senderContact =>
      senderPhone == null ? senderName : '$senderName - $senderPhone';

  DeliveryDraft copyWith({
    SavedAddress? origin,
    SavedAddress? destination,
    Recipient? recipient,
    DeliverySchedule? schedule,
    DeliveryItem? item,
    int? fee,
  }) => DeliveryDraft(
    senderName: senderName,
    senderPhone: senderPhone,
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    recipient: recipient ?? this.recipient,
    schedule: schedule ?? this.schedule,
    item: item ?? this.item,
    fee: fee ?? this.fee,
  );
}

/// Judul dan keterangan waktu antar, dipakai di form dan Detail Pesanan.
/// [orderedAt] dipakai untuk "sebelum jam ..." pada pengantaran sekarang.
({String title, String subtitle}) scheduleLabels(
  DeliverySchedule schedule,
  DateTime orderedAt,
) {
  final slot = schedule.slot;
  if (slot == null) {
    return (
      title: 'Antar sekarang',
      subtitle: 'Diantar sebelum jam ${clockLabel(deliverBy(orderedAt))}',
    );
  }
  // Desain: "Jadwal: 21 Okt 2026 - 08.00-09.00" (jam tanpa spasi).
  return (
    title: 'Antar nanti',
    subtitle:
        'Jadwal: ${dateLabel(slot.day)} - '
        '${slot.hourLabel.replaceAll(' ', '')}',
  );
}

/// "4 hari lalu", "3 bulan lalu".
String timeAgoLabel(DateTime then, DateTime now) {
  final days = now.difference(then).inDays;
  if (days < 1) return 'Hari ini';
  if (days < 30) return '$days hari lalu';
  if (days < 365) return '${days ~/ 30} bulan lalu';
  return '${days ~/ 365} tahun lalu';
}
