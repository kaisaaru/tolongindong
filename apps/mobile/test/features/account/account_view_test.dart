import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/account_view.dart';
import 'package:mobile/features/account/help_page.dart';
import 'package:mobile/features/account/saved_addresses_page.dart';
import 'package:mobile/features/address/add_address_page.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/features/notification/notification_page.dart';
import 'package:mobile/models/auth_user.dart';

import '../../helpers/fake_address_repository.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_page.dart';
import '../../helpers/test_data.dart';

const _alex = AuthUser(
  id: 'uuid-7',
  fullName: 'Alexsander',
  email: 'Alexsander83@gmail.com',
  phoneNumber: '08123543431',
  photoUrl: null,
  verificationStatus: VerificationStatus.verified,
  isAdmin: false,
  wallet: Wallet(availableBalance: 250000, heldBalance: 0, currency: 'IDR'),
);

/// Tab Akun di beranda, seperti dibuka dari bilah bawah.
Future<void> _openAccount(
  WidgetTester tester, {
  AuthUser user = _alex,
  Size size = const Size(412, 917),
  FakeAddressRepository? addressRepo,
}) async {
  await pumpPage(
    tester,
    const HomePage(),
    size: size,
    user: user,
    authRepo: FakeAuthRepository(sessionUser: user),
    addressRepo: addressRepo,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Akun'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Profil Saya seperti desain', (tester) async {
    await _openAccount(tester);

    expect(find.byType(AccountView), findsOneWidget);
    expect(find.text('Profil Saya'), findsOneWidget);
    expect(find.text('Alexsander'), findsOneWidget);
    expect(find.text('Alexsander83@gmail.com'), findsOneWidget);
    expect(find.text('ID Verified'), findsOneWidget);
    for (final section in [
      'Akun & Keamanan',
      'Layanan & Fitur',
      'Pengaturan & Bantuan',
    ]) {
      expect(find.text(section), findsOneWidget);
    }
    expect(find.text('Baru'), findsOneWidget); // Daftar Jadi Helper
    expect(find.text('Rp 250.000'), findsOneWidget); // saldo di TD-Wallet
    expect(find.text('Keluar Akun'), findsOneWidget);
  });

  testWidgets('status verifikasi selain terverifikasi', (tester) async {
    const pending = AuthUser(
      id: 'uuid-8',
      fullName: 'Budi',
      email: 'budi@example.com',
      phoneNumber: null,
      photoUrl: null,
      verificationStatus: VerificationStatus.pending,
      isAdmin: false,
      wallet: Wallet.empty,
    );
    await _openAccount(tester, user: pending);
    expect(find.text('Menunggu verifikasi'), findsOneWidget);
    expect(find.text('ID Verified'), findsNothing);
  });

  testWidgets('tombol kembali membawa ke Beranda', (tester) async {
    await _openAccount(tester);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountView), findsNothing);
    expect(find.text('Jasa tersedia'), findsOneWidget);
  });

  testWidgets('menu yang belum didukung backend memberi tahu', (tester) async {
    await _openAccount(tester);
    for (final (menu, message) in [
      ('Edit Profil', 'Edit profil belum tersedia.'),
      ('Daftar Jadi Helper', 'Daftar jadi helper belum tersedia.'),
      ('Voucher Saya', 'Voucher belum tersedia.'),
    ]) {
      await tester.tap(find.text(menu));
      await tester.pump();
      expect(find.text(message), findsOneWidget);
    }
  });

  testWidgets('Notifikasi dan Pusat Bantuan membuka halamannya', (
    tester,
  ) async {
    await _openAccount(tester);

    await tester.tap(find.text('Notifikasi'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationPage), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pusat Bantuan & Kebijakan'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpPage), findsOneWidget);
    await tester.tap(find.text('Tentang TolonginDong'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutDialog), findsOneWidget);
  });

  group('Alamat Tersimpan', () {
    testWidgets('daftar dari server, alamat utama ditandai', (tester) async {
      await _openAccount(tester);
      await tester.tap(find.text('Alamat Tersimpan'));
      await tester.pumpAndSettle();

      expect(find.byType(SavedAddressesPage), findsOneWidget);
      expect(find.text(testHome.fullAddress), findsOneWidget);
      expect(find.text(testOffice.fullAddress), findsOneWidget);
      expect(find.text('Utama'), findsOneWidget);
    });

    testWidgets('jadikan utama', (tester) async {
      final addresses = FakeAddressRepository();
      await pumpPage(
        tester,
        const SavedAddressesPage(),
        addressRepo: addresses,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pilihan alamat').last); // Kantor
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jadikan alamat utama'));
      await tester.pumpAndSettle();

      expect(
        addresses.addresses.firstWhere((a) => a.isPrimary).id,
        testOffice.id,
      );
      expect(find.text('Kantor jadi alamat utama.'), findsOneWidget);
    });

    testWidgets('hapus setelah konfirmasi', (tester) async {
      final addresses = FakeAddressRepository();
      await pumpPage(
        tester,
        const SavedAddressesPage(),
        addressRepo: addresses,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pilihan alamat').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus alamat?'), findsOneWidget);

      // Batal: alamat tetap ada.
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(addresses.addresses, hasLength(2));

      await tester.tap(find.byTooltip('Pilihan alamat').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
      await tester.pumpAndSettle();

      expect(addresses.addresses.map((a) => a.id), [testHome.id]);
      expect(find.text(testOffice.fullAddress), findsNothing);
    });

    testWidgets('kosong, lalu tambah alamat', (tester) async {
      final addresses = FakeAddressRepository(addresses: []);
      await pumpPage(
        tester,
        const SavedAddressesPage(),
        addressRepo: addresses,
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada alamat tersimpan'), findsOneWidget);

      await tester.tap(find.text('Tambah Alamat'));
      await tester.pumpAndSettle();
      expect(find.byType(AddAddressPage), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).at(1),
        'Jl. Dago No.5, Coblong, Bandung',
      );
      await tester.tap(find.text('Gunakan lokasi saat ini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan Alamat'));
      await tester.pumpAndSettle();

      expect(find.byType(SavedAddressesPage), findsOneWidget);
      expect(find.text('Jl. Dago No.5, Coblong, Bandung'), findsOneWidget);
    });
  });

  testWidgets('layar sempit (320 dp)', (tester) async {
    await _openAccount(tester, size: const Size(320, 640));
    expect(find.text('Profil Saya'), findsOneWidget);

    await tester.tap(find.text('Alamat Tersimpan'));
    await tester.pumpAndSettle();
    expect(find.text('Alamat Tersimpan'), findsOneWidget);
  });
}
