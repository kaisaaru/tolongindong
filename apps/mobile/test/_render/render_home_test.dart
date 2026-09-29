// Alat sementara: merender beranda ke PNG untuk dibandingkan dengan desain.
// Bukan tes permanen — dihapus setelah dipakai.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/models/auth_user.dart';
import 'package:mobile/models/service_category.dart';
import 'package:mobile/theme/app_theme.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_catalog_repository.dart';

const _fontDir =
    '/Users/nanda/Library/Containers/com.example.mobile/Data/Library/Application Support/com.example.mobile/';

Future<void> _loadFonts() async {
  for (final f in Directory(_fontDir).listSync()) {
    final name = f.uri.pathSegments.last;
    if (!name.startsWith('Poppins_') || !name.endsWith('.ttf')) continue;
    final family = name.split('_').take(2).join('_'); // Poppins_600
    final bytes = File(f.path).readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
      .load();
}

ServiceCategory _cat(int id, String code, String name) => ServiceCategory(
      id: id, code: code, name: name, baseFee: 0, requiresAdvance: false,
      requiresProofPhoto: false, requiresPickupAddress: false,
      requiresDestinationAddress: true);

void main() {
  testWidgets('render beranda', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(_loadFonts);

    const dpr = 1.6675;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = const Size(412 * dpr, 917 * dpr);
    tester.view.padding = const FakeViewPadding(top: 52 * dpr);
    addTearDown(tester.view.reset);

    const user = AuthUser(
      id: 'x', fullName: 'Alexsander', email: 'a@b.c', phoneNumber: null,
      photoUrl: null, verificationStatus: VerificationStatus.verified,
      isAdmin: false, wallet: Wallet.empty);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: HomePage(
          user: user,
          authRepo: FakeAuthRepository(sessionUser: user),
          catalogRepo: FakeCatalogRepository(result: [
            _cat(1, 'food_run', 'Food run'), _cat(2, 'delivery', 'Delivery'),
            _cat(3, 'moving', 'Moving'), _cat(4, 'personal', 'Personal'),
            _cat(5, 'household', 'Household'), _cat(6, 'laundry', 'Laundry'),
          ]),
        ),
      ),
    ));
    // Gambar aset dimuat di luar fake-async; beri waktu lalu pompa ulang.
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
    }
    for (final e in find.byType(Image).evaluate()) {
      final w = e.widget as Image;
      await tester.runAsync(() => precacheImage(w.image, e));
    }
    await tester.pump();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: dpr);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(Platform.environment['OUT_PNG']!).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
