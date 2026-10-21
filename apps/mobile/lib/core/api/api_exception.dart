/// Kegagalan yang datang dari backend TolonginDong.
///
/// Backend selalu membungkus error dengan bentuk yang sama:
/// ```json
/// { "success": false,
///   "message": "Nomor telepon / email atau kata sandi salah.",
///   "error": { "code": "INVALID_CREDENTIALS",
///              "detail": { "remaining_attempts": 3 } } }
/// ```
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.detail,
    this.statusCode,
  });

  /// Kode mesin, mis. `INVALID_CREDENTIALS`. Dipakai untuk percabangan logika.
  final String code;

  /// Pesan dari server, sudah berbahasa Indonesia dan layak ditampilkan apa adanya.
  final String message;

  /// Isi `error.detail`. Bentuknya berbeda-beda tergantung [code].
  final Map<String, dynamic>? detail;

  final int? statusCode;

  /// Pesan per field saat [code] == `VALIDATION_ERROR`.
  ///
  /// Server mengirim `{"email": ["Email sudah terdaftar."]}`, diambil yang pertama
  /// karena UI cuma punya ruang satu baris per field.
  Map<String, String> get fieldErrors {
    final raw = detail;
    if (raw == null) return const {};
    return raw.map((field, messages) {
      final first = messages is List && messages.isNotEmpty
          ? messages.first
          : messages;
      return MapEntry(field, first.toString());
    });
  }

  /// Angka di dalam detail, mis. `remaining_attempts` atau `lockout_seconds`.
  int? intOf(String key) {
    final value = detail?[key];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  /// Server tidak terjangkau — beda dari server menolak permintaan.
  bool get isNetworkIssue => code == 'NETWORK_ERROR';

  @override
  String toString() => 'ApiException($code): $message';
}
