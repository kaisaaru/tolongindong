/// 30000 -> "Rp 30.000". [spaced] false -> "Rp30.000", dipakai di rincian
/// pembayaran sesuai desain. Nilai negatif -> "-Rp2.000".
String rupiah(int value, {bool spaced = true}) {
  final grouped = value.abs().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );
  final sign = value < 0 ? '-' : '';
  return '${sign}Rp${spaced ? ' ' : ''}$grouped';
}
