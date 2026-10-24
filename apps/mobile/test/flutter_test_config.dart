import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Berlaku untuk semua test: preferensi di memori, kosong di awal tiap
/// test. Tanpa ini, menyimpan mode app (misal saat keluar akun) menunggu
/// plugin yang tidak ada di lingkungan test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  await testMain();
}
