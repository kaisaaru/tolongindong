import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/splash/splash_page.dart';

import '../../helpers/pump_page.dart';

void main() {
  testWidgets('splash pindah ke onboarding setelah durasinya habis', (
    tester,
  ) async {
    await pumpPage(tester, const SplashPage());

    await tester.pump(SplashPage.duration - const Duration(milliseconds: 1));
    expect(find.byType(OnboardingPage), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });
}
