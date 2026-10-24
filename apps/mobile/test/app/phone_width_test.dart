import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

Future<double> _pageWidth(WidgetTester tester, Size screen) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late double width;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => PhoneWidth(child: child!),
      home: Builder(
        builder: (context) {
          width = MediaQuery.sizeOf(context).width;
          return const SizedBox();
        },
      ),
    ),
  );
  return width;
}

void main() {
  testWidgets('HP: halaman selebar layar', (tester) async {
    expect(await _pageWidth(tester, const Size(412, 917)), 412);
  });

  testWidgets('tablet: halaman selebar HP besar di tengah', (tester) async {
    expect(
      await _pageWidth(tester, const Size(820, 1180)),
      PhoneWidth.maxWidth,
    );
  });
}
