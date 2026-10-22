import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/household/house_order_form_page.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/household/household_page.dart';
import 'package:mobile/features/household/household_samples.dart';
import 'package:mobile/features/household/order_review_page.dart';
import 'package:mobile/models/service_category.dart';
import 'package:mobile/theme/app_colors.dart';

import '../../helpers/pump_page.dart';

const _household = ServiceCategory(
  id: 3,
  code: 'household',
  name: 'Household',
  baseFee: 5000,
  requiresAdvance: false,
  requiresProofPhoto: false,
  requiresPickupAddress: false,
  requiresDestinationAddress: false,
);

/// Pesanan Pakaian: muatan Sedang (>3–6 kg), helper Rp40.000/jam, 1 jam.
final _laundryDraft = HouseholdOrderDraft(
  service: HouseholdService.pakaian,
  address: HouseholdSamples.savedAddresses.first,
  load: LoadOption.laundry[1],
  tools: ToolOption.provided,
  helper: HouseholdSamples.helpers.first,
  hours: 1,
);

/// Layar HP sempit: overflow apa pun membuat test gagal.
Future<void> _pumpNarrow(WidgetTester tester, Widget page) async {
  await pumpPage(tester, page, size: const Size(360, 740));
  await tester.pump();
}

void main() {
  test('muatan Pakaian dihitung per kg', () {
    expect(HouseholdService.pakaian.loadOptions, LoadOption.laundry);
    expect(
      [for (final f in _laundryDraft.fees) '${f.label}=${f.amount}'],
      ['Muatan - Sedang=10000'],
    );
    expect(HouseholdService.rumah.loadOptions, isNull);
  });

  testWidgets('ubin Pakaian membuka form', (tester) async {
    await _pumpNarrow(tester, const HouseholdPage(category: _household));
    await tester.tap(find.text('Pakaian'));
    await tester.pumpAndSettle();
    expect(find.byType(HouseOrderFormPage), findsOneWidget);
  });

  testWidgets('form Pakaian: muatan kg, bukan ukuran; judul gelap', (
    tester,
  ) async {
    await _pumpNarrow(
      tester,
      const HouseOrderFormPage(
        service: HouseholdService.pakaian,
        category: _household,
      ),
    );

    expect(find.text('Alamat Rumah'), findsOneWidget);
    expect(find.text('Cari lokasi rumah anda'), findsOneWidget);
    expect(find.text('Kecil (<3 kg) + Rp 0'), findsOneWidget);
    expect(find.text('Lebar :'), findsNothing);

    final title = tester.widget<Text>(find.text('Pakaian'));
    expect(title.style?.color, AppColors.textPrimary);
  });

  testWidgets('detail pesanan Pakaian dengan rincian terbuka', (tester) async {
    await _pumpNarrow(tester, OrderReviewPage(draft: _laundryDraft));
    expect(find.text('Muatan:'), findsOneWidget);
    expect(find.text('Ukuran rumah:'), findsNothing);

    await tester.tap(find.text('Total'));
    await tester.pump();
    expect(find.text('Muatan - Sedang'), findsOneWidget);
    expect(find.text('Rp50.000'), findsOneWidget);
  });
}
