import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/theme/app_theme.dart';

void main() {
  Future<void> pumpLoginPage(WidgetTester tester) async {
    // Ukuran frame Android Compact di desain.
    tester.view.physicalSize = const Size(412, 917);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const LoginPage()),
    );
  }

  Finder field(int index) => find.byType(TextField).at(index);

  testWidgets('tombol Login baru aktif setelah email dan password diisi', (
    tester,
  ) async {
    await pumpLoginPage(tester);
    ElevatedButton loginButton() =>
        tester.widget(find.widgetWithText(ElevatedButton, 'Login'));

    expect(loginButton().onPressed, isNull);

    await tester.enterText(field(0), 'alexsander83@gmail.com');
    await tester.pump();
    expect(loginButton().onPressed, isNull);

    await tester.enterText(field(1), '@lexSa76');
    await tester.pump();
    expect(loginButton().onPressed, isNotNull);
  });

  testWidgets('ikon mata menampilkan dan menyembunyikan password', (
    tester,
  ) async {
    await pumpLoginPage(tester);
    bool obscured() => tester.widget<TextField>(field(1)).obscureText;

    expect(obscured(), isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();
    expect(obscured(), isFalse);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(obscured(), isTrue);
  });
}
