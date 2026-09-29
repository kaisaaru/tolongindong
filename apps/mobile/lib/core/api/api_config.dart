import 'package:flutter/foundation.dart';

/// Alamat backend. Bisa ditimpa saat run:
/// `flutter run --dart-define=API_URL=http://192.168.1.10:8000`
class ApiConfig {
  const ApiConfig._();

  static const _override = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;

    // Emulator Android punya jaringan sendiri. Di dalamnya, "localhost"
    // berarti emulator itu sendiri, bukan laptop. 10.0.2.2 adalah alamat
    // khusus yang menunjuk balik ke laptop.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    // Simulator iOS dan desktop berbagi jaringan dengan laptop.
    return 'http://127.0.0.1:8000';
  }
}
