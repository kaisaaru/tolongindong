import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../models/auth_user.dart';

/// Semua urusan autentikasi, dalam bahasa aplikasi — bukan bahasa HTTP.
///
/// Halaman UI memanggil `login(...)` dan menerima [AuthUser] atau
/// [ApiException]. Halaman tidak perlu tahu soal path, header, atau JSON.
class AuthRepository {
  AuthRepository({ApiClient? api, TokenStorage? storage})
      : _api = api ?? ApiClient(storage: storage),
        _storage = storage ?? TokenStorage();

  final ApiClient _api;
  final TokenStorage _storage;

  /// Daftar akun baru. Tidak menerbitkan token — lanjutkan ke [verifyOtp].
  Future<OtpChallenge> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final data = await _api.post('/register', body: {
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'password': password,
    });
    return OtpChallenge.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Verifikasi OTP. Di sinilah token pertama kali terbit dan disimpan.
  Future<AuthUser> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    String? tempToken,
  }) async {
    final data = await _api.post('/verify-otp', body: {
      'phone_number': phoneNumber,
      'otp_code': otpCode,
      'temp_token': ?tempToken,
    });
    return _persist(data);
  }

  /// Kirim ulang OTP. Backend membatasi satu kali per 60 detik
  /// (kode `OTP_THROTTLED`).
  Future<OtpChallenge> resendOtp(String phoneNumber, {String type = 'register'}) async {
    final data = await _api.post('/send-otp', body: {
      'phone_number': phoneNumber,
      'type': type,
    });
    return OtpChallenge.fromJson(
      data is Map ? data.cast<String, dynamic>() : {'phone_number': phoneNumber},
    );
  }

  /// [identifier] boleh email atau nomor HP — backend menerima keduanya.
  Future<AuthUser> login({
    required String identifier,
    required String password,
  }) async {
    final data = await _api.post('/login', body: {
      'identifier': identifier,
      'password': password,
    });
    return _persist(data);
  }

  Future<AuthUser> signInWithGoogle(String idToken) async {
    final data = await _api.post('/google', body: {'id_token': idToken});
    return _persist(data);
  }

  /// Profil pengguna yang tokennya tersimpan. Dipakai saat app dibuka
  /// untuk memastikan sesi lama masih berlaku.
  Future<AuthUser> me() async {
    final data = await _api.get('/me');
    return AuthUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } finally {
      // Token lokal tetap dibuang walau server tidak terjangkau, supaya
      // pengguna tidak tersangkut di kondisi "seolah masih login".
      await _storage.clear();
    }
  }

  Future<bool> hasSession() => _storage.hasToken();

  /// Simpan token lalu kembalikan profilnya. Dipakai bersama oleh
  /// login, verify-otp, dan google.
  Future<AuthUser> _persist(dynamic data) async {
    final map = (data as Map).cast<String, dynamic>();
    final token = map['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await _storage.save(token);
    }
    return AuthUser.fromJson((map['user'] as Map).cast<String, dynamic>());
  }
}
