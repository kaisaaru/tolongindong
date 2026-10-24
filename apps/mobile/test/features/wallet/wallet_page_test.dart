import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/wallet/wallet_page.dart';
import 'package:mobile/features/wallet/wallet_repository.dart';

import '../../helpers/fake_wallet_repository.dart';
import '../../helpers/pump_page.dart';

WalletTransaction _tx(int id, WalletTxType type, int amount) =>
    WalletTransaction(
      id: id,
      type: type,
      amount: amount,
      balanceAfter: 0,
      createdAt: DateTime(2026, 10, 21, 9),
    );

Future<void> _openTopup(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Isi Saldo'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saldo, dana ditahan, dan mutasi bertanda +/-', (tester) async {
    final repo = FakeWalletRepository(
      balance: 150000,
      held: 40000,
      history: [
        _tx(2, WalletTxType.hold, 50000),
        _tx(1, WalletTxType.topup, 200000),
      ],
    );
    await pumpPage(tester, WalletPage(), walletRepo: repo);
    await tester.pumpAndSettle();

    expect(find.text('Rp 150.000'), findsOneWidget);
    expect(
      find.text('Ditahan untuk pesanan berjalan: Rp 40.000'),
      findsOneWidget,
    );
    expect(find.text('-Rp50.000'), findsOneWidget);
    expect(find.text('+Rp200.000'), findsOneWidget);
    expect(find.text('Dana ditahan untuk pesanan'), findsOneWidget);
  });

  testWidgets('belum ada mutasi: ajakan isi saldo', (tester) async {
    await pumpPage(tester, WalletPage(), walletRepo: FakeWalletRepository());
    await tester.pumpAndSettle();

    expect(find.text('Belum ada transaksi'), findsOneWidget);
  });

  testWidgets('isi saldo lewat pilihan nominal', (tester) async {
    final repo = FakeWalletRepository(balance: 150000);
    await pumpPage(tester, WalletPage(), walletRepo: repo);
    await tester.pumpAndSettle();

    await _openTopup(tester);
    await tester.tap(find.text('Rp 50.000'));
    await tester.pump();
    await tester.tap(find.text('Isi Rp 50.000'));
    await tester.pumpAndSettle();

    expect(find.text('Rp 200.000'), findsOneWidget); // saldo baru
    expect(find.text('Saldo bertambah Rp 50.000.'), findsOneWidget);
    expect(find.text('+Rp50.000'), findsOneWidget); // mutasi baru
  });

  testWidgets('nominal di bawah minimal ditolak tanpa ke server', (
    tester,
  ) async {
    final repo = FakeWalletRepository();
    await pumpPage(tester, WalletPage(), walletRepo: repo);
    await tester.pumpAndSettle();

    await _openTopup(tester);
    await tester.enterText(find.byType(TextField), '5000');
    await tester.pump();
    await tester.tap(find.text('Isi Rp 5.000'));
    await tester.pump();

    expect(find.text('Minimal Rp 10.000'), findsOneWidget);
    expect(repo.topupKeys, isEmpty);
  });

  testWidgets('mengulang setelah gagal memakai kunci yang sama', (
    tester,
  ) async {
    final repo = FakeWalletRepository()
      ..failNextTopup = const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Tidak bisa menghubungi server.',
      );
    await pumpPage(tester, WalletPage(), walletRepo: repo);
    await tester.pumpAndSettle();

    await _openTopup(tester);
    await tester.tap(find.text('Rp 50.000'));
    await tester.pump();
    await tester.tap(find.text('Isi Rp 50.000'));
    await tester.pump();
    expect(find.text('Tidak bisa menghubungi server.'), findsOneWidget);

    // Diulang: kunci sama, jadi saldo tidak bisa bertambah dua kali.
    await tester.tap(find.text('Isi Rp 50.000'));
    await tester.pumpAndSettle();
    expect(repo.topupKeys, hasLength(2));
    expect(repo.topupKeys[0], repo.topupKeys[1]);
    expect(repo.balance, 50000);
  });
}
