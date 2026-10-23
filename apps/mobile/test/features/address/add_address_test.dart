import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/address/add_address_page.dart';
import 'package:mobile/features/address/location_service.dart';
import 'package:mobile/features/household/address_picker_page.dart';
import 'package:mobile/features/household/household_models.dart';

import '../../helpers/fake_address_repository.dart';
import '../../helpers/fake_location_service.dart';
import '../../helpers/pump_page.dart';

ElevatedButton _save(WidgetTester tester) => tester.widget<ElevatedButton>(
  find.widgetWithText(ElevatedButton, 'Simpan Alamat'),
);

void main() {
  testWidgets('Simpan aktif setelah alamat dan titik lokasi terisi', (
    tester,
  ) async {
    final addresses = FakeAddressRepository(addresses: []);
    await pumpPage(tester, const AddAddressPage(), addressRepo: addresses);
    await tester.pumpAndSettle();
    expect(_save(tester).onPressed, isNull);

    await tester.enterText(
      find.byType(TextField).at(1),
      'Jl. Braga No.10, Sumur Bandung',
    );
    await tester.pump();
    expect(_save(tester).onPressed, isNull); // belum ada koordinat

    await tester.tap(find.text('Gunakan lokasi saat ini'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lokasi didapat'), findsOneWidget);
    expect(find.text('Ambil ulang lokasi'), findsOneWidget);

    await tester.tap(find.text('Kantor'));
    await tester.tap(find.text('Jadikan alamat utama'));
    await tester.pump();
    await tester.tap(find.text('Simpan Alamat'));
    await tester.pumpAndSettle();

    final saved = addresses.addresses.single;
    expect(saved.label, 'Kantor');
    expect(saved.fullAddress, 'Jl. Braga No.10, Sumur Bandung');
    expect(saved.latitude, -6.9175);
    expect(saved.isPrimary, isTrue);
    expect(find.byType(AddAddressPage), findsNothing);
  });

  testWidgets('izin lokasi ditolak: pesannya tampil', (tester) async {
    await pumpPage(
      tester,
      const AddAddressPage(),
      locationService: FakeLocationService(
        error: const LocationException('Izin lokasi ditolak.'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gunakan lokasi saat ini'));
    await tester.pumpAndSettle();

    expect(find.text('Izin lokasi ditolak.'), findsOneWidget);
    expect(_save(tester).onPressed, isNull);
  });

  testWidgets('ditolak validasi server: pesan di kolomnya', (tester) async {
    final addresses = FakeAddressRepository()
      ..failNextCreate = const ApiException(
        code: 'VALIDATION_ERROR',
        message: 'Data tidak valid.',
        detail: {
          'full_address': ['Alamat terlalu pendek.'],
        },
      );
    await pumpPage(tester, const AddAddressPage(), addressRepo: addresses);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'Jl. A 1');
    await tester.tap(find.text('Gunakan lokasi saat ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Alamat'));
    await tester.pumpAndSettle();

    expect(find.text('Alamat terlalu pendek.'), findsOneWidget);
    expect(find.byType(AddAddressPage), findsOneWidget);
  });

  testWidgets('pilih alamat: alamat baru langsung terpilih', (tester) async {
    SavedAddress? picked;
    await pumpPage(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            picked = await Navigator.of(context).push<SavedAddress>(
              MaterialPageRoute(builder: (_) => const AddressPickerPage()),
            );
          },
          child: const Text('Buka'),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah alamat baru'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(1),
      'Jl. Dago No.5, Coblong, Bandung',
    );
    await tester.tap(find.text('Gunakan lokasi saat ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Alamat'));
    await tester.pumpAndSettle();

    expect(picked?.fullAddress, 'Jl. Dago No.5, Coblong, Bandung');
    expect(picked?.id, isNotNull);
    expect(find.byType(AddressPickerPage), findsNothing);
  });

  testWidgets('layar sempit (360 dp)', (tester) async {
    await pumpPage(tester, const AddAddressPage(), size: const Size(360, 740));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Alamat'), findsOneWidget);
  });
}
