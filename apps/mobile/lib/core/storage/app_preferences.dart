import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi ringan yang boleh hilang tanpa merusak apa pun.
///
/// Sengaja dipisah dari [TokenStorage]: token perlu terenkripsi, sedangkan
/// penanda seperti "onboarding sudah dilihat" tidak rahasia.
class AppPreferences {
  static const _onboardingSeenKey = 'onboarding_seen';

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
