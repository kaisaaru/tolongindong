import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/delivery/delivery_page.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/theme/app_theme.dart';

const _fonts = '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';

Future<void> _load(String family, String file) async {
  final bytes = File('$_fonts/$file').readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _load('MaterialIcons', 'MaterialIcons-Regular.otf');
    for (final w in ['400', '500', '600', '700']) {
      final file = switch (w) { '400' => 'Roboto-Regular.ttf', '500' => 'Roboto-Medium.ttf', _ => 'Roboto-Bold.ttf' };
      await _load('Poppins_$w', file);
    }
    await _load('Poppins', 'Roboto-Regular.ttf');
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(824, 1834);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 94);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light,
      home: DeliveryPage(senderName: 'Alexsander', senderPhone: '0812', store: OrderStore(), clock: () => DateTime(2026, 10, 22, 9, 47))));
    await tester.pump();
  }

  testWidgets('landing', (tester) async {
    await pump(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('zz_shots/1_landing.png'));
  });

  testWidgets('form + sheets', (tester) async {
    await pump(tester);
    await tester.tap(find.text('4 hari lalu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('zz_shots/2_form.png'));
    await tester.tap(find.text('Mau dianter kapan?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antar Sekarang'));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('zz_shots/3_time.png'));
    await tester.tap(find.text('Pilih Pengantaran ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barang apa yang ingin dikirim?'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('zz_shots/4_item.png'));
  });
}
