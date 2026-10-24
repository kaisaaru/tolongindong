import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/app_preferences.dart';
import 'package:mobile/features/helper/helper_shell.dart';
import 'package:mobile/features/helper/helper_work_repository.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/splash/splash_page.dart';
import 'package:mobile/models/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_catalog_repository.dart';
import '../../helpers/fake_helper_work_repository.dart';
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

  testWidgets('sudah login, splash langsung ke beranda', (tester) async {
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

  for (final (verified, expected) in [(true, HelperShell), (false, HomePage)]) {
    testWidgets(
      'terakhir di mode Helper: ${verified ? 'mode Helper' : 'helper '
                'tidak lagi terverifikasi, kembali ke Client'}',
      (tester) async {
        await AppPreferences().setMode(AppMode.helper);
        await pumpPage(
          tester,
          SplashPage(),
          authRepo: FakeAuthRepository(sessionUser: user),
          catalogRepo: FakeCatalogRepository(),
          helperWorkRepo: FakeHelperWorkRepository(
            helperStatus: verified ? testHelperStatus : HelperStatus.none,
          ),
        );

        await tester.pump(SplashPage.duration);
        await tester.pumpAndSettle();

        expect(find.byType(expected), findsOneWidget);
        expect(
          await AppPreferences().mode(),
          verified ? AppMode.helper : AppMode.client,
        );
      },
    );
  }

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

  testWidgets(
    'server lambat bangun: splash memberi tahu sedang menghubungkan',
    (tester) async {
      await pumpPage(
        tester,
        const SplashPage(),
        authRepo: _SlowAuthRepository(),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 350));
      expect(_notice(tester), 0);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 350));
      expect(_notice(tester), 1);

      // Begitu server menjawab, splash tetap pindah seperti biasa.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);
    },
  );
}

/// Server deploy yang baru bangun setelah 10 detik.
class _SlowAuthRepository extends FakeAuthRepository {
  @override
  Future<bool> hasSession() async {
    await Future<void>.delayed(const Duration(seconds: 10));
    return false;
  }
}

/// Opacity keterangan "Menghubungkan ke server...".
double _notice(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Menghubungkan ke server...'),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;
