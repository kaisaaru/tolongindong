/// Status verifikasi identitas (FR-VER-003).
enum VerificationStatus {
  /// Belum pernah mengajukan berkas.
  unverified,

  /// Berkas sudah dikirim, menunggu admin.
  pending,

  /// Disetujui admin, sudah boleh menerima pesanan.
  verified,

  /// Ditolak admin, boleh mengajukan ulang.
  rejected;

  static VerificationStatus fromCode(String? code) => switch (code) {
    'pending' => VerificationStatus.pending,
    'verified' => VerificationStatus.verified,
    'rejected' => VerificationStatus.rejected,
    _ => VerificationStatus.unverified,
  };

  bool get isVerified => this == VerificationStatus.verified;
}

/// Saldo TD-Wallet. Nominal rupiah disimpan sebagai bilangan bulat,
/// tidak pernah desimal.
class Wallet {
  const Wallet({
    required this.availableBalance,
    required this.heldBalance,
    required this.currency,
  });

  /// Saldo yang bisa dipakai.
  final int availableBalance;

  /// Saldo yang sedang ditahan untuk pesanan berjalan (escrow, DEC-02).
  final int heldBalance;

  final String currency;

  static const empty = Wallet(
    availableBalance: 0,
    heldBalance: 0,
    currency: 'IDR',
  );

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    availableBalance: json['available_balance'] as int? ?? 0,
    heldBalance: json['held_balance'] as int? ?? 0,
    currency: json['currency'] as String? ?? 'IDR',
  );
}

/// Pengguna yang sedang login.
///
/// Bentuk ini dikirim backend di tiga tempat dengan isi yang sama:
/// `POST /login`, `POST /verify-otp`, dan `GET /me`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.photoUrl,
    required this.verificationStatus,
    required this.isAdmin,
    required this.wallet,
  });

  /// UUID, bukan angka. Jangan pakai int.
  final String id;

  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final VerificationStatus verificationStatus;
  final bool isAdmin;
  final Wallet wallet;

  /// Saldo terbaru, misal setelah isi saldo, tanpa memuat ulang `/me`.
  AuthUser withWallet(Wallet wallet) => AuthUser(
    id: id,
    fullName: fullName,
    email: email,
    phoneNumber: phoneNumber,
    photoUrl: photoUrl,
    verificationStatus: verificationStatus,
    isAdmin: isAdmin,
    wallet: wallet,
  );

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phoneNumber: json['phone_number'] as String?,
    photoUrl: json['photo_url'] as String?,
    verificationStatus: VerificationStatus.fromCode(
      json['verification_status'] as String?,
    ),
    // Tidak selalu dikirim (mis. respons verify-otp), jadi anggap bukan admin.
    isAdmin: json['is_admin'] as bool? ?? false,
    wallet: json['wallet'] is Map
        ? Wallet.fromJson((json['wallet'] as Map).cast<String, dynamic>())
        : Wallet.empty,
  );
}

/// Hasil `POST /register` — sengaja bukan [AuthUser], karena registrasi
/// belum menerbitkan token. Token baru keluar setelah OTP diverifikasi.
class OtpChallenge {
  const OtpChallenge({
    required this.phoneNumber,
    required this.expiresInSeconds,
    this.debugOtp,
  });

  final String phoneNumber;

  /// Umur kode OTP, 300 detik (FR-AUTH-002).
  final int expiresInSeconds;

  /// Hanya terisi saat backend berjalan dengan `APP_ENV=local`.
  /// Belum ada gateway SMS, jadi ini satu-satunya cara melihat kodenya.
  final String? debugOtp;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
    phoneNumber: json['phone_number'] as String? ?? '',
    expiresInSeconds: json['otp_expires_in_seconds'] as int? ?? 300,
    debugOtp: json['debug_otp']?.toString(),
  );
}
