import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/splash/splash_page.dart';
import 'package:mobile/models/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_catalog_repository.dart';
import '../../helpers/pump_page.dart';

void main() {
  // Splash menentukan tujuan dari dua sumber: ada tidaknya sesi, dan
  // apakah onboarding pernah dilihat. Keduanya dipalsukan di sini.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('belum login dan belum lihat onboarding, splash ke onboarding', (
    tester,
  ) async {
    await pumpPage(tester, SplashPage(), authRepo: FakeAuthRepository());

    await tester.pump(SplashPage.duration - const Duration(milliseconds: 1));
    expect(find.byType(OnboardingPage), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('sudah login, splash langsung ke beranda', (tester) async {
    const user = AuthUser(
      id: 'uuid-1',
      fullName: 'Nanda',
      email: 'nanda@example.com',
      phoneNumber: '08123456789',
      photoUrl: null,
      verificationStatus: VerificationStatus.verified,
      isAdmin: false,
      wallet: Wallet.empty,
    );
    await pumpPage(
      tester,
      SplashPage(),
      authRepo: FakeAuthRepository(sessionUser: user),
      catalogRepo: FakeCatalogRepository(),
    );

    await tester.pump(SplashPage.duration);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('sudah lihat onboarding tapi belum login, splash ke login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await pumpPage(tester, SplashPage(), authRepo: FakeAuthRepository());

    await tester.pump(SplashPage.duration);
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(SplashPage), findsNothing);
  });
}
