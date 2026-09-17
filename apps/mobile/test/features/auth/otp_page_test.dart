import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/otp_page.dart';

import '../../helpers/pump_page.dart';

void main() {
  const page = OtpPage(phoneNumber: '081234563914');

  VoidCallback? verifyPressed(WidgetTester tester) => tester
      .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Verifikasi'))
      .onPressed;

  testWidgets('nomor tujuan cuma tampil 4 digit terakhir', (tester) async {
    await pumpPage(tester, page);

    expect(find.textContaining('********3914'), findsOneWidget);
    expect(find.textContaining('0812'), findsNothing);
  });

  testWidgets('tiap digit tampil di kotaknya, selain angka dibuang', (
    tester,
  ) async {
    await pumpPage(tester, page);

    await tester.enterText(find.byType(TextField), '1a2');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });

  testWidgets('Verifikasi aktif setelah 6 digit, lebih dari itu dipotong', (
    tester,
  ) async {
    await pumpPage(tester, page);
    expect(verifyPressed(tester), isNull);

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    expect(verifyPressed(tester), isNull);

    await tester.enterText(find.byType(TextField), '1234567');
    await tester.pump();
    expect(verifyPressed(tester), isNotNull);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '123456',
    );
  });
}
