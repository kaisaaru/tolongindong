import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_scope.dart';
import 'package:mobile/core/media/photo_picker.dart';
import 'package:mobile/features/address/address_repository.dart';
import 'package:mobile/features/address/location_service.dart';
import 'package:mobile/features/auth/auth_repository.dart';
import 'package:mobile/features/chat/chat_repository.dart';
import 'package:mobile/features/chat/chat_store.dart';
import 'package:mobile/features/helper/helper_store.dart';
import 'package:mobile/features/helper/helper_work_repository.dart';
import 'package:mobile/features/home/catalog_repository.dart';
import 'package:mobile/features/notification/notification_repository.dart';
import 'package:mobile/features/order/helper_repository.dart';
import 'package:mobile/features/order/order_repository.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/features/wallet/wallet_repository.dart';
import 'package:mobile/models/auth_user.dart';
import 'package:mobile/theme/app_theme.dart';

import 'fake_address_repository.dart';
import 'fake_auth_repository.dart';
import 'fake_catalog_repository.dart';
import 'fake_chat_repository.dart';
import 'fake_helper_repository.dart';
import 'fake_helper_work_repository.dart';
import 'fake_location_service.dart';
import 'fake_notification_repository.dart';
import 'fake_order_repository.dart';
import 'fake_photo_picker.dart';
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
/// Repository diganti versi palsu tanpa jaringan; berikan sendiri untuk
/// mengatur isi atau memeriksa permintaan. Store yang diberikan dipakai apa
/// adanya dan tidak dibuang otomatis. `user: null` berarti belum masuk
/// (splash, login).
Widget testApp(
  Widget page, {
  AuthRepository? authRepo,
  CatalogRepository? catalogRepo,
  WalletRepository? walletRepo,
  NotificationRepository? notificationRepo,
  HelperRepository? helperRepo,
  AddressRepository? addressRepo,
  OrderRepository? orderRepo,
  ChatRepository? chatRepo,
  LocationService? locationService,
  HelperWorkRepository? helperWorkRepo,
  PhotoPicker? photoPicker,
  OrderStore? orderStore,
  ChatStore? chatStore,
  HelperStore? helperStore,
  AuthUser? user = testUser,
}) => AppScope(
  authRepo: authRepo ?? FakeAuthRepository(sessionUser: user),
  catalogRepo: catalogRepo ?? FakeCatalogRepository(),
  walletRepo: walletRepo ?? FakeWalletRepository(),
  notificationRepo: notificationRepo ?? FakeNotificationRepository([]),
  helperRepo: helperRepo ?? FakeHelperRepository(),
  addressRepo: addressRepo ?? FakeAddressRepository(),
  orderRepo: orderRepo ?? FakeOrderRepository(),
  chatRepo: chatRepo ?? FakeChatRepository(),
  locationService: locationService ?? FakeLocationService(),
  helperWorkRepo: helperWorkRepo ?? FakeHelperWorkRepository(),
  photoPicker: photoPicker ?? FakePhotoPicker(),
  orderStore: orderStore,
  chatStore: chatStore,
  helperStore: helperStore,
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
  HelperRepository? helperRepo,
  AddressRepository? addressRepo,
  OrderRepository? orderRepo,
  ChatRepository? chatRepo,
  LocationService? locationService,
  HelperWorkRepository? helperWorkRepo,
  PhotoPicker? photoPicker,
  OrderStore? orderStore,
  ChatStore? chatStore,
  HelperStore? helperStore,
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
      helperRepo: helperRepo,
      addressRepo: addressRepo,
      orderRepo: orderRepo,
      chatRepo: chatRepo,
      locationService: locationService,
      helperWorkRepo: helperWorkRepo,
      photoPicker: photoPicker,
      orderStore: orderStore,
      chatStore: chatStore,
      helperStore: helperStore,
      user: user,
    ),
  );
}
