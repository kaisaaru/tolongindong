import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Menyimpan token Sanctum di keystore perangkat.
///
/// Sengaja bukan SharedPreferences: token setara kunci masuk akun, jadi
/// disimpan terenkripsi (Keychain di iOS, EncryptedSharedPreferences di Android).
class TokenStorage {
  static const _key = 'auth_token';

  // Sejak flutter_secure_storage v11, enkripsi AES-GCM sudah jadi perilaku
  // baku di Android, jadi tidak perlu opsi tambahan.
  static const _storage = FlutterSecureStorage();

  Future<void> save(String token) => _storage.write(key: _key, value: token);

  Future<String?> read() => _storage.read(key: _key);

  Future<void> clear() => _storage.delete(key: _key);

  Future<bool> hasToken() async {
    final token = await read();
    return token != null && token.isNotEmpty;
  }
}
