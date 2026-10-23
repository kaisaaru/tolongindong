import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// Satu pintu untuk semua permintaan ke backend.
///
/// Tiga tugasnya:
/// 1. menempelkan header di setiap permintaan, termasuk token kalau sudah login,
/// 2. membongkar amplop respons backend (`success` / `data` / `error`),
/// 3. mengubah setiap kegagalan menjadi [ApiException] yang seragam.
///
/// Halaman UI tidak pernah menyentuh kelas ini langsung — lewat repository.
class ApiClient {
  /// [baseUrl] hanya diisi saat pengujian; aplikasi memakai [ApiConfig].
  ApiClient({TokenStorage? storage, Dio? dio, String? baseUrl})
    : _storage = storage ?? TokenStorage(),
      _dio = dio ?? Dio(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl {
    _dio.options
      ..baseUrl = _baseUrl
      ..connectTimeout = ApiConfig.timeoutFor(_baseUrl)
      ..receiveTimeout = ApiConfig.timeoutFor(_baseUrl)
      // Tanpa header ini Laravel bisa membalas halaman HTML saat error,
      // bukan JSON, dan parsing di bawah ikut hancur.
      ..headers['Accept'] = 'application/json'
      // Status apa pun dibiarkan lewat. Yang menentukan sukses/gagal adalah
      // isi amplop, bukan kode HTTP. Kalau dibiarkan default, Dio melempar
      // duluan dan kita kehilangan `error.code` yang ada di body.
      ..validateStatus = (_) => true;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _storage;
  final String _baseUrl;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  /// Mengembalikan isi `data` apa adanya — bisa Map (profil user) atau
  /// List (daftar kategori), jadi pemanggil yang menentukan bentuknya.
  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    final Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw ApiException(
        code: 'NETWORK_ERROR',
        // Pengguna app tidak tahu soal "backend"; itu urusan pengembang
        // yang menjalankan server di laptop.
        message: ApiConfig.isLocal(_baseUrl)
            ? 'Tidak bisa menghubungi server. Pastikan backend menyala dan '
                  'perangkat berada di jaringan yang sama.'
            : 'Tidak bisa menghubungi server. Periksa koneksi internetmu, '
                  'lalu coba lagi.',
        detail: {'dio_type': e.type.name},
      );
    }

    final body = response.data;
    if (body is! Map) {
      throw ApiException(
        code: 'BAD_RESPONSE',
        message: 'Respons server tidak dikenali.',
        statusCode: response.statusCode,
      );
    }

    if (body['success'] == true) return body['data'];

    final error = body['error'];

    // Sanctum menolak token tanpa memakai amplop kita:
    // {"message": "Unauthenticated."} — jadi ditangani terpisah.
    if (error is! Map) {
      throw ApiException(
        code: response.statusCode == 401 ? 'UNAUTHENTICATED' : 'UNKNOWN',
        message: body['message']?.toString() ?? 'Terjadi kesalahan.',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      code: error['code']?.toString() ?? 'UNKNOWN',
      message: body['message']?.toString() ?? 'Terjadi kesalahan.',
      detail: (error['detail'] as Map?)?.cast<String, dynamic>(),
      statusCode: response.statusCode,
    );
  }
}
