/// 30000 -> "Rp 30.000". [spaced] false -> "Rp30.000", dipakai di rincian
/// pembayaran sesuai desain. Nilai negatif -> "-Rp2.000".
String rupiah(int value, {bool spaced = true}) {
  final sign = value < 0 ? '-' : '';
  return '${sign}Rp${spaced ? ' ' : ''}${thousands(value.abs())}';
}

/// 40000 -> "40.000"; -8000 -> "-8.000". Angka tanpa "Rp".
String thousands(int value) {
  final grouped = value.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return value < 0 ? '-$grouped' : grouped;
}
