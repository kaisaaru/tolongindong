import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_scope.dart';
import 'package:mobile/features/auth/auth_repository.dart';
import 'package:mobile/features/chat/chat_store.dart';
import 'package:mobile/features/home/catalog_repository.dart';
import 'package:mobile/features/notification/notification_repository.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/features/wallet/wallet_repository.dart';
import 'package:mobile/models/auth_user.dart';
import 'package:mobile/theme/app_theme.dart';

import 'fake_auth_repository.dart';
import 'fake_catalog_repository.dart';
import 'fake_notification_repository.dart';
import 'fake_wallet_repository.dart';

/// Pengguna yang sudah masuk di setiap test, kecuali diganti lewat `user`.
const testUser = AuthUser(
  id: 'uuid-1',
  fullName: 'Nanda Persada',
  email: 'nanda@example.com',
  phoneNumber: '08123456789',
  photoUrl: null,
  verificationStatus: VerificationStatus.verified,
  isAdmin: false,
  wallet: Wallet.empty,
);

/// [page] di dalam [AppScope] dan `MaterialApp` bertema, seperti app.
///
/// Repository diganti versi palsu tanpa jaringan. Store yang diberikan
/// dipakai apa adanya, jadi test masih bisa memeriksa isinya setelah halaman
/// ditutup. `user: null` berarti belum masuk (splash, login).
Widget testApp(
  Widget page, {
  AuthRepository? authRepo,
  CatalogRepository? catalogRepo,
  WalletRepository? walletRepo,
  NotificationRepository? notificationRepo,
  OrderStore? orderStore,
  ChatStore? chatStore,
  AuthUser? user = testUser,
}) => AppScope(
  authRepo: authRepo ?? FakeAuthRepository(sessionUser: user),
  catalogRepo: catalogRepo ?? FakeCatalogRepository(),
  walletRepo: walletRepo ?? FakeWalletRepository(),
  notificationRepo: notificationRepo ?? FakeNotificationRepository([]),
  orderStore: orderStore,
  chatStore: chatStore,
  user: user,
  child: MaterialApp(theme: AppTheme.light, home: page),
);

/// Render [page] lewat [testApp] di layar seukuran frame desain
/// (Android Compact, 412x917), atau [size].
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(412, 917),
  AuthRepository? authRepo,
  CatalogRepository? catalogRepo,
  WalletRepository? walletRepo,
  NotificationRepository? notificationRepo,
  OrderStore? orderStore,
  ChatStore? chatStore,
  AuthUser? user = testUser,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testApp(
      page,
      authRepo: authRepo,
      catalogRepo: catalogRepo,
      walletRepo: walletRepo,
      notificationRepo: notificationRepo,
      orderStore: orderStore,
      chatStore: chatStore,
      user: user,
    ),
  );
}
