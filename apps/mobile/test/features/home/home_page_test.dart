import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/change_password_page.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/chat/chat_list_view.dart';
import 'package:mobile/features/chat/chat_store.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/features/household/household_page.dart';
import 'package:mobile/features/notification/notification_page.dart';
import 'package:mobile/features/household/household_samples.dart';
import 'package:mobile/features/order/order_samples.dart';
import 'package:mobile/features/order/order_store.dart';
import 'package:mobile/features/wallet/wallet_page.dart';
import 'package:mobile/models/auth_user.dart';
import 'package:mobile/models/service_category.dart';
import 'package:mobile/theme/app_theme.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_catalog_repository.dart';
import '../../helpers/fake_notification_repository.dart';
import '../../helpers/fake_wallet_repository.dart';
import '../../helpers/pump_page.dart';

const _user = AuthUser(
  id: 'uuid-1',
  fullName: 'Nanda Persada',
  email: 'nanda@example.com',
  phoneNumber: '08123456789',
  photoUrl: null,
  verificationStatus: VerificationStatus.verified,
  isAdmin: false,
  wallet: Wallet.empty,
);

ServiceCategory _category(int id, String code, String name) => ServiceCategory(
  id: id,
  code: code,
  name: name,
  baseFee: 10000,
  requiresAdvance: false,
  requiresProofPhoto: false,
  requiresPickupAddress: false,
  requiresDestinationAddress: true,
);

Future<void> _pumpHome(WidgetTester tester, FakeCatalogRepository repo) async {
  await pumpPage(
    tester,
    HomePage(user: _user, authRepo: FakeAuthRepository(), catalogRepo: repo),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kategori tampil urut desain, diakhiri ubin Helper', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      FakeCatalogRepository(
        // Urutan id dari server sengaja berbeda dari urutan desain.
        result: [
          _category(2, 'delivery', 'Delivery'),
          _category(3, 'household', 'Household'),
          _category(1, 'personal', 'Personal'),
        ],
      ),
    );

    final labels = ['Personal', 'Delivery', 'Household', 'Helper'];
    final xs = [for (final l in labels) tester.getCenter(find.text(l)).dx];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(find.text('Lainnya'), findsNothing);
  });

  testWidgets('alamat utama tampil di header', (tester) async {
    await _pumpHome(
      tester,
      FakeCatalogRepository(address: 'Jl. Kaliurang KM 5'),
    );

    expect(find.text('Hallo, Nanda'), findsOneWidget);
    expect(find.text('Jl. Kaliurang KM 5'), findsOneWidget);
  });

  testWidgets('tanpa alamat tersimpan, header mengajak atur alamat', (
    tester,
  ) async {
    await _pumpHome(tester, FakeCatalogRepository());

    expect(find.text('Atur alamat'), findsOneWidget);
  });

  testWidgets('baris kategori tidak meluap di layar 360 dp', (tester) async {
    // Overflow apa pun membuat test gagal. Baris kategori selebar desain
    // (412 dp) dulu meluap 13 dp di layar 360 dp.
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          user: _user,
          authRepo: FakeAuthRepository(),
          catalogRepo: FakeCatalogRepository(
            result: [
              _category(1, 'personal', 'Personal'),
              _category(2, 'delivery', 'Delivery'),
              _category(3, 'household', 'Household'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final helper = tester.getRect(find.text('Helper'));
    expect(helper.center.dx, lessThan(360 - 35));
  });

  testWidgets('nav berisi empat tab desain baru', (tester) async {
    await _pumpHome(tester, FakeCatalogRepository());

    for (final tab in ['Beranda', 'Aktifitas', 'Obrolan', 'Akun']) {
      expect(find.text(tab), findsOneWidget);
    }
  });

  testWidgets('tab Obrolan berisi daftar obrolan', (tester) async {
    await pumpPage(
      tester,
      HomePage(
        user: _user,
        authRepo: FakeAuthRepository(),
        catalogRepo: FakeCatalogRepository(),
        chatStore: ChatStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Obrolan'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatListView), findsOneWidget);
    expect(find.text('Agus Nomercy'), findsOneWidget);
  });

  testWidgets('banner beranda menampilkan pesanan Personal', (tester) async {
    final store = OrderStore()
      ..placePersonal(
        helper: OrderSamples.listingsFor('personal').first,
        payment: HouseholdSamples.paymentMethods.first,
      );
    await pumpPage(
      tester,
      HomePage(
        user: _user,
        authRepo: FakeAuthRepository(),
        catalogRepo: FakeCatalogRepository(),
        orderStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal'), findsWidgets); // ubin kategori + banner
    expect(find.text('Dikerjakan Agus Nomercy'), findsOneWidget);
  });

  testWidgets('tombol kembali di tab lain membawa ke Beranda', (tester) async {
    await _pumpHome(tester, FakeCatalogRepository());

    await tester.tap(find.text('Aktifitas'));
    await tester.pumpAndSettle();
    expect(find.text('Jasa tersedia'), findsNothing);

    // Tombol kembali Android: tidak menutup aplikasi.
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Jasa tersedia'), findsOneWidget);
  });

  testWidgets('tab Akun: profil, lalu keluar setelah konfirmasi', (
    tester,
  ) async {
    await _pumpHome(tester, FakeCatalogRepository());

    await tester.tap(find.text('Akun'));
    await tester.pumpAndSettle();
    expect(find.text(_user.fullName), findsOneWidget);
    expect(find.text(_user.email), findsOneWidget);
    expect(find.text('Terverifikasi'), findsOneWidget);

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsNothing);

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('cari "pindahan" membuka kategori Household', (tester) async {
    await _pumpHome(
      tester,
      FakeCatalogRepository(
        result: [
          _category(1, 'personal', 'Personal'),
          _category(3, 'household', 'Household'),
        ],
      ),
    );

    await tester.enterText(find.byType(TextField), 'pindahan');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdPage), findsOneWidget);
  });

  testWidgets('kata yang tidak dikenal diberi tahu, tetap di beranda', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      FakeCatalogRepository(result: [_category(1, 'personal', 'Personal')]),
    );

    await tester.enterText(find.byType(TextField), 'servis mobil');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(
      find.text('Belum ada layanan untuk "servis mobil".'),
      findsOneWidget,
    );
  });

  testWidgets('Seputar TolongDong: tips membuka langkah lengkap', (
    tester,
  ) async {
    await _pumpHome(tester, FakeCatalogRepository());

    await tester.scrollUntilVisible(
      find.text('Cara pesan helper'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cara pesan helper'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pilih kategori di beranda'), findsOneWidget);
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pilih kategori di beranda'), findsNothing);
  });

  testWidgets('Aktifitas kosong: Cari Layanan kembali ke Beranda', (
    tester,
  ) async {
    await pumpPage(
      tester,
      HomePage(
        user: _user,
        authRepo: FakeAuthRepository(),
        catalogRepo: FakeCatalogRepository(),
        orderStore: OrderStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aktifitas'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada pesanan berjalan'), findsOneWidget);

    await tester.tap(find.text('Cari Layanan'));
    await tester.pumpAndSettle();
    expect(find.text('Jasa tersedia'), findsOneWidget);
  });

  testWidgets('lonceng membuka halaman notifikasi', (tester) async {
    await pumpPage(
      tester,
      HomePage(
        user: _user,
        authRepo: FakeAuthRepository(sessionUser: _user),
        catalogRepo: FakeCatalogRepository(),
        notificationRepo: FakeNotificationRepository([]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.bell));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationPage), findsOneWidget);
    expect(find.text('Belum ada notifikasi'), findsOneWidget);
  });

  testWidgets('Akun: kartu saldo membuka TD-Wallet, menu ganti password', (
    tester,
  ) async {
    await pumpPage(
      tester,
      HomePage(
        user: _user,
        authRepo: FakeAuthRepository(sessionUser: _user),
        catalogRepo: FakeCatalogRepository(),
        walletRepo: FakeWalletRepository(balance: 75000),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akun'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Isi saldo'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletPage), findsOneWidget);
    expect(find.text('Rp 75.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ganti password'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordPage), findsOneWidget);
  });
}
