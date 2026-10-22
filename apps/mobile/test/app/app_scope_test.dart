import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_scope.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/chat/chat_store.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/features/household/household_samples.dart';
import 'package:mobile/features/order/order_samples.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/features/splash/splash_page.dart';
import 'package:mobile/main.dart';
import 'package:mobile/models/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_catalog_repository.dart';
import '../helpers/fake_notification_repository.dart';
import '../helpers/fake_wallet_repository.dart';
import '../helpers/pump_page.dart';

const _budi = AuthUser(
  id: 'uuid-9',
  fullName: 'Budi Santoso',
  email: 'budi@example.com',
  phoneNumber: '081200000009',
  photoUrl: null,
  verificationStatus: VerificationStatus.verified,
  isAdmin: false,
  wallet: Wallet.empty,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('rangkaian main(): sesi tersimpan langsung ke beranda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 917);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Sama seperti main(), hanya repository-nya palsu.
    await tester.pumpWidget(
      AppScope(
        authRepo: FakeAuthRepository(sessionUser: _budi),
        catalogRepo: FakeCatalogRepository(),
        walletRepo: FakeWalletRepository(),
        notificationRepo: FakeNotificationRepository([]),
        child: const MyApp(),
      ),
    );
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(SplashPage.duration);
    await tester.pumpAndSettle();

    // Pengguna dari splash mengalir ke beranda lewat SessionStore.
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Hallo, Budi'), findsOneWidget);
  });

  testWidgets('login mengisi sesi: beranda menyapa pengguna itu', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const LoginPage(),
      user: null,
      authRepo: FakeAuthRepository(loginResult: _budi),
    );

    await tester.enterText(find.byType(TextField).at(0), 'budi@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.pump();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Hallo, Budi'), findsOneWidget);
  });

  testWidgets('isi saldo: saldo di tab Akun ikut berubah tanpa muat ulang', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const HomePage(),
      walletRepo: FakeWalletRepository(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akun'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 0'), findsOneWidget);

    await tester.tap(find.text('Isi saldo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Isi Saldo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rp 50.000'));
    await tester.pump();
    await tester.tap(find.text('Isi Rp 50.000'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 50.000'), findsOneWidget);
  });

  testWidgets('keluar akun mengosongkan pesanan dan obrolan', (tester) async {
    final orders = OrderStore()
      ..placePersonal(
        helper: OrderSamples.listingsFor('personal').first,
        payment: HouseholdSamples.paymentMethods.first,
      );
    final chats = ChatStore(rooms: []);
    chats.openWithHelper(helperId: 'h-1', name: 'Agus');
    expect(chats.rooms, hasLength(1));

    await pumpPage(
      tester,
      const HomePage(),
      orderStore: orders,
      chatStore: chats,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    // Akun berikutnya tidak melihat pesanan dan obrolan akun ini.
    expect(orders.hasActive, isFalse);
    expect(chats.rooms.any((r) => r.helperId == 'h-1'), isFalse);
  });
}
