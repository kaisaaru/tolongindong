import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/auth/auth_repository.dart';
import 'package:mobile/models/auth_user.dart';

/// Pengganti [AuthRepository] untuk widget test: tidak menyentuh jaringan
/// maupun keystore. Isi [registerResult] atau [failWith] sesuai skenario.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.registerResult,
    this.loginResult,
    this.failWith,
    this.sessionUser,
  });

  final OtpChallenge? registerResult;
  final AuthUser? loginResult;

  /// Kalau diisi, dianggap ada sesi tersimpan dan `me()` mengembalikan ini.
  final AuthUser? sessionUser;

  /// Kalau diisi, setiap pemanggilan melemparkan error ini.
  final ApiException? failWith;

  /// Argumen panggilan terakhir, untuk diperiksa di test.
  Map<String, Object?>? lastCall;

  Never _fail() => throw failWith!;

  @override
  Future<OtpChallenge> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    lastCall = {
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
    };
    if (failWith != null) _fail();
    return registerResult ??
        OtpChallenge(phoneNumber: phoneNumber, expiresInSeconds: 300);
  }

  @override
  Future<AuthUser> login({
    required String identifier,
    required String password,
  }) async {
    lastCall = {'identifier': identifier};
    if (failWith != null) _fail();
    return loginResult!;
  }

  @override
  Future<AuthUser> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    String? tempToken,
  }) async {
    lastCall = {'phone_number': phoneNumber, 'otp_code': otpCode};
    if (failWith != null) _fail();
    return loginResult!;
  }

  @override
  Future<OtpChallenge> resendOtp(String phoneNumber, {String type = 'register'}) async {
    if (failWith != null) _fail();
    return OtpChallenge(
      phoneNumber: phoneNumber,
      expiresInSeconds: 300,
      debugOtp: '123456',
    );
  }

  @override
  Future<AuthUser> signInWithGoogle(String idToken) async => loginResult!;

  @override
  Future<AuthUser> me() async {
    if (failWith != null) _fail();
    return sessionUser ?? loginResult!;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<bool> hasSession() async => sessionUser != null;
}
