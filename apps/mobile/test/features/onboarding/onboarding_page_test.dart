import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_page.dart';

void main() {
  // Onboarding menandai dirinya "sudah dilihat" saat selesai, jadi
  // penyimpanan preferensi perlu tersedia di lingkungan tes.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  const firstTitle = 'Bantuan Mudah untuk\nTugas Harian';
  const secondTitle = 'Aman dengan Helper\nTerverifikasi';
  const lastTitle = 'Solusi Tuntas dengan\nHarga Adil';

  Finder skipButton() => find.text('Lewati').hitTestable();

  testWidgets('Selanjutnya menggeser halaman, di akhir jadi Ayo Mulai', (
    tester,
  ) async {
    await pumpPage(tester, const OnboardingPage());
    expect(find.text(firstTitle), findsOneWidget);
    expect(skipButton(), findsOneWidget);

    await tester.tap(find.text('Selanjutnya'));
    await tester.pumpAndSettle();
    expect(find.text(secondTitle), findsOneWidget);
    expect(skipButton(), findsOneWidget);

    await tester.tap(find.text('Selanjutnya'));
    await tester.pumpAndSettle();
    expect(find.text(lastTitle), findsOneWidget);
    expect(find.text('Ayo Mulai'), findsOneWidget);
    expect(find.text('Selanjutnya'), findsNothing);
    expect(skipButton(), findsNothing);
  });

  testWidgets('halaman juga bisa digeser dengan swipe', (tester) async {
    await pumpPage(tester, const OnboardingPage());

    await tester.fling(find.text(firstTitle), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(secondTitle), findsOneWidget);
  });

  testWidgets('Lewati langsung membuka halaman login', (tester) async {
    await pumpPage(tester, const OnboardingPage());

    await tester.tap(skipButton());
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('Ayo Mulai di halaman terakhir membuka halaman login', (
    tester,
  ) async {
    await pumpPage(tester, const OnboardingPage());

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Selanjutnya'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Ayo Mulai'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });
}
