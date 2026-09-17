import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme/app_theme.dart';

/// Render [page] pakai `AppTheme` di layar seukuran frame desain
/// (Android Compact, 412x917).
Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(412, 917);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
}
