import 'package:shared_preferences/shared_preferences.dart';

/// Satu akun, dua peran: memesan helper (Client) atau mengerjakan
/// pesanan (Helper).
enum AppMode { client, helper }

/// Preferensi ringan yang boleh hilang tanpa merusak apa pun.
///
/// Sengaja dipisah dari [TokenStorage]: token perlu terenkripsi, sedangkan
/// penanda seperti "onboarding sudah dilihat" tidak rahasia.
class AppPreferences {
  static const _onboardingSeenKey = 'onboarding_seen';
  static const _modeKey = 'app_mode';

  /// Mode terakhir dipakai, supaya helper langsung masuk mode Helper saat
  /// membuka app lagi. Gagal dibaca: mode Client.
  Future<AppMode> mode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_modeKey) == AppMode.helper.name
          ? AppMode.helper
          : AppMode.client;
    } on Exception {
      return AppMode.client;
    }
  }

  /// Gagal disimpan tidak menghalangi pindah mode atau keluar akun.
  Future<void> setMode(AppMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.name);
    } on Exception {
      // Lihat dokumentasi di atas.
    }
  }

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  /// Dipakai saat logout kalau nanti onboarding perlu muncul lagi,
  /// dan berguna untuk menguji ulang alur pertama kali.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingSeenKey);
  }
}
