// Tes yang menembak backend sungguhan di http://127.0.0.1:8000, sama seperti
// auth_live_test.dart. Hanya membaca: isi saldo dan ganti password sengaja
// tidak dipanggil supaya database bersama tidak berubah.
//
//   flutter test test/account_live_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/features/auth/auth_repository.dart';
import 'package:mobile/features/notification/notification_repository.dart';
import 'package:mobile/features/wallet/wallet_repository.dart';

import 'auth_live_test.dart' show MemoryTokenStorage;

void main() {
  const baseUrl = 'http://127.0.0.1:8000';
  late ApiClient api;

  setUp(() async {
    final storage = MemoryTokenStorage();
    api = ApiClient(storage: storage, baseUrl: baseUrl);
    await AuthRepository(
      api: api,
      storage: storage,
    ).login(identifier: 'admin@admin.com', password: 'password');
  });

  test('saldo dan riwayat mutasi terbaca', () async {
    final repo = WalletRepository(api: api);

    final wallet = await repo.wallet();
    expect(wallet.currency, 'IDR');
    expect(wallet.availableBalance, greaterThanOrEqualTo(0));

    final page = await repo.transactions();
    expect(page.page, 1);
    for (final tx in page.items) {
      expect(tx.type, isNot(WalletTxType.unknown));
      expect(tx.amount, greaterThan(0));
    }
  });

  test('notifikasi dan jumlah belum dibaca terbaca', () async {
    final feed = await NotificationRepository(api: api).list();
    expect(feed.unreadCount, greaterThanOrEqualTo(0));
    expect(feed.page.page, 1);
  });
}
