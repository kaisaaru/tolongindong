import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_config.dart';
import 'package:mobile/core/api/api_exception.dart';

import '../auth_live_test.dart' show MemoryTokenStorage;

void main() {
  test('server deploy diberi waktu bangun 60 detik, lokal 15 detik', () {
    expect(
      ApiConfig.timeoutFor(ApiConfig.production),
      const Duration(seconds: 60),
    );
    expect(
      ApiConfig.timeoutFor('http://127.0.0.1:8000'),
      const Duration(seconds: 15),
    );
    expect(
      ApiConfig.timeoutFor('http://10.0.2.2:8000'),
      const Duration(seconds: 15),
    );
  });

  test('build debug memakai backend lokal', () {
    // Test selalu berjalan dalam mode debug.
    expect(ApiConfig.isLocal(ApiConfig.baseUrl), isTrue);
  });

  test('gagal koneksi ke server deploy: pesan untuk pengguna biasa', () async {
    // Port 9 (discard) di localhost lewat https: koneksi pasti gagal cepat.
    final api = ApiClient(
      baseUrl: 'https://127.0.0.1:9',
      storage: MemoryTokenStorage(),
    );
    final error = await api
        .get('/up')
        .then<Object?>((_) => null)
        .catchError((Object e) => e);

    expect(error, isA<ApiException>());
    final e = error! as ApiException;
    expect(e.isNetworkIssue, isTrue);
    expect(e.message, contains('koneksi internetmu'));
    expect(e.message, isNot(contains('backend')));
  });
}
