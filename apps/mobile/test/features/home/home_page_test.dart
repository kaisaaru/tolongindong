import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/models/auth_user.dart';
import 'package:mobile/models/service_category.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_catalog_repository.dart';
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

  testWidgets('nav berisi empat tab desain baru', (tester) async {
    await _pumpHome(tester, FakeCatalogRepository());

    for (final tab in ['Beranda', 'Aktifitas', 'Obrolan', 'Akun']) {
      expect(find.text(tab), findsOneWidget);
    }
  });
}
