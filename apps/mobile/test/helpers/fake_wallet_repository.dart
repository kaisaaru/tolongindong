import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/core/api/paged.dart';
import 'package:mobile/features/wallet/wallet_repository.dart';
import 'package:mobile/models/auth_user.dart';

/// Pengganti [WalletRepository] untuk widget test: saldo di memori.
class FakeWalletRepository implements WalletRepository {
  FakeWalletRepository({
    this.balance = 0,
    this.held = 0,
    this.history = const [],
  });

  int balance;
  int held;
  List<WalletTransaction> history;

  /// Kalau diisi, isi saldo berikutnya gagal dengan error ini (sekali).
  ApiException? failNextTopup;

  /// Kunci idempotensi tiap percobaan isi saldo, berurutan.
  final topupKeys = <String>[];

  Wallet get _wallet =>
      Wallet(availableBalance: balance, heldBalance: held, currency: 'IDR');

  @override
  Future<Wallet> wallet() async => _wallet;

  @override
  Future<Paged<WalletTransaction>> transactions({int page = 1}) async =>
      Paged(items: history, page: 1, lastPage: 1);

  @override
  Future<Wallet> topup(int amount, {required String idempotencyKey}) async {
    topupKeys.add(idempotencyKey);
    final fail = failNextTopup;
    if (fail != null) {
      failNextTopup = null;
      throw fail;
    }
    balance += amount;
    history = [
      WalletTransaction(
        id: history.length + 1,
        type: WalletTxType.topup,
        amount: amount,
        balanceAfter: balance,
        createdAt: DateTime(2026, 10, 22, 10),
      ),
      ...history,
    ];
    return _wallet;
  }
}
