// Tes yang menembak backend sungguhan di http://127.0.0.1:8000.
// Jalankan backend lebih dulu: php artisan serve
//
//   flutter test test/auth_live_test.dart
//
// Tujuannya membuktikan rantai ApiClient -> amplop -> model benar,
// sebelum kode ini dipakai di halaman.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/features/auth/auth_repository.dart';
import 'package:mobile/models/auth_user.dart';

/// Pengganti keystore perangkat, yang tidak tersedia di lingkungan tes.
class MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> save(String token) async => _token = token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> clear() async => _token = null;

  @override
  Future<bool> hasToken() async => (_token ?? '').isNotEmpty;
}

void main() {
  const baseUrl = 'http://127.0.0.1:8000';

  late MemoryTokenStorage storage;
  late AuthRepository auth;

  setUp(() {
    storage = MemoryTokenStorage();
    auth = AuthRepository(
      api: ApiClient(storage: storage, baseUrl: baseUrl),
      storage: storage,
    );
  });

  test('data berbentuk List ikut terbaca (service-categories)', () async {
    final data = await ApiClient(storage: storage, baseUrl: baseUrl)
        .get('/service-categories');

    expect(data, isA<List>());
    expect((data as List).length, 6);
    expect(data.first['code'], 'food_run');
  });

  test('login benar menghasilkan AuthUser dan menyimpan token', () async {
    final user = await auth.login(
      identifier: 'admin@admin.com',
      password: 'password',
    );

    expect(user.fullName, 'Administrator');
    expect(user.isAdmin, isTrue);
    expect(user.verificationStatus, VerificationStatus.verified);
    expect(user.wallet.currency, 'IDR');
    expect(await storage.hasToken(), isTrue, reason: 'token wajib tersimpan');
  });

  test('token tersimpan otomatis terpakai di permintaan berikutnya', () async {
    await auth.login(identifier: 'admin@admin.com', password: 'password');

    final me = await auth.me();
    expect(me.email, 'admin@admin.com');
  });

  test('tanpa token, /me ditolak sebagai UNAUTHENTICATED', () async {
    final error = await auth.me().then<Object?>((_) => null).onError(
          (Object e, _) => e,
        );

    expect(error, isA<ApiException>());
    expect((error as ApiException).code, 'UNAUTHENTICATED');
    expect(error.statusCode, 401);
  });

  test('password salah memberi kode dan sisa percobaan', () async {
    final error = await auth
        .login(identifier: 'admin@admin.com', password: 'jelas-salah')
        .then<Object?>((_) => null)
        .onError((Object e, _) => e);

    expect(error, isA<ApiException>());
    final api = error as ApiException;
    expect(api.code, anyOf('INVALID_CREDENTIALS', 'ACCOUNT_LOCKED'));
    expect(api.message, isNotEmpty);
    if (api.code == 'INVALID_CREDENTIALS') {
      expect(api.intOf('remaining_attempts'), isNotNull);
    }
  });

  test('server mati terbaca sebagai NETWORK_ERROR, bukan crash', () async {
    final offline = AuthRepository(
      api: ApiClient(storage: storage, baseUrl: 'http://127.0.0.1:9'),
      storage: storage,
    );

    final error = await offline
        .login(identifier: 'a@b.c', password: 'x')
        .then<Object?>((_) => null)
        .onError((Object e, _) => e);

    expect((error as ApiException).isNetworkIssue, isTrue);
  });
}
