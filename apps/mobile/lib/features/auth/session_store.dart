import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../models/auth_user.dart';
import 'auth_repository.dart';

/// Pengguna yang sedang masuk. Dipakai bersama beranda, Akun, TD-Wallet,
/// dan Delivery (pengirim = pengguna ini), jadi tidak perlu dioper lewat
/// parameter dari halaman ke halaman.
class SessionStore extends ChangeNotifier {
  SessionStore(this._auth, {AuthUser? user}) : _user = user;

  final AuthRepository _auth;
  AuthUser? _user;

  /// Null sebelum masuk dan sesudah keluar.
  AuthUser? get user => _user;

  /// Dipanggil setelah login, verifikasi OTP, atau sesi lama di splash.
  void signIn(AuthUser user) {
    _user = user;
    notifyListeners();
  }

  /// Saldo terbaru dari TD-Wallet; tab Akun ikut menampilkannya.
  void updateWallet(Wallet wallet) {
    final user = _user;
    if (user == null) return;
    _user = user.withWallet(wallet);
    notifyListeners();
  }

  /// Profil terbaru dari `/me`, misal saat beranda dimuat ulang. Gagal: data
  /// lama tetap dipakai — profil yang telat diperbarui bukan alasan error.
  Future<void> refresh() async {
    try {
      _user = await _auth.me();
      notifyListeners();
    } on ApiException {
      // Lihat dokumentasi di atas.
    }
  }

  /// Token dibuang walau server tidak terjangkau (lihat
  /// [AuthRepository.logout]).
  Future<void> signOut() async {
    try {
      await _auth.logout();
    } finally {
      _user = null;
      notifyListeners();
    }
  }
}
