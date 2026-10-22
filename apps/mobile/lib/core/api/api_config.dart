import 'package:flutter/foundation.dart';

/// Alamat backend.
///
/// - Build rilis (APK/IPA yang dibagikan): server deploy [production].
/// - Debug: backend lokal di laptop, supaya kode OTP debug ikut tampil
///   (server deploy berjalan dengan `APP_ENV=production`).
/// - Keduanya bisa ditimpa saat run, misal untuk mencoba server deploy dari
///   debug: `flutter run --dart-define=API_URL=https://tolongindong.onrender.com`
class ApiConfig {
  const ApiConfig._();

  static const _override = String.fromEnvironment('API_URL');

  /// Server deploy di Render.
  static const production = 'https://tolongindong.onrender.com';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kReleaseMode) return production;

    // Emulator Android punya jaringan sendiri. Di dalamnya, "localhost"
    // berarti emulator itu sendiri, bukan laptop. 10.0.2.2 adalah alamat
    // khusus yang menunjuk balik ke laptop.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    // Simulator iOS dan desktop berbagi jaringan dengan laptop.
    return 'http://127.0.0.1:8000';
  }

  /// Server deploy memakai paket gratis Render: setelah lama tidak dipakai,
  /// permintaan pertama menunggu server bangun hingga ±1 menit. Server lokal
  /// yang tidak menjawab 15 detik hampir pasti memang mati.
  static Duration timeoutFor(String url) =>
      isLocal(url) ? const Duration(seconds: 15) : const Duration(seconds: 60);

  /// Backend di laptop sendiri (HTTP biasa), bukan server deploy.
  static bool isLocal(String url) => !url.startsWith('https://');
}
