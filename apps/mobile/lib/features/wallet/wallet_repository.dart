import '../../core/api/api_client.dart';
import '../../core/api/paged.dart';
import '../../models/auth_user.dart';

/// Jenis mutasi TD-Wallet, sama dengan `transaction_type` di backend.
enum WalletTxType {
  topup('topup', 'Isi saldo', incoming: true),
  hold('hold', 'Dana ditahan untuk pesanan', incoming: false),
  release('release', 'Pembayaran pesanan diterima', incoming: true),
  advanceReimbursement(
    'advance_reimbursement',
    'Penggantian talangan',
    incoming: true,
  ),
  refund('refund', 'Pengembalian dana', incoming: true),
  payout('payout', 'Pencairan saldo', incoming: false),
  cancellationFee('cancellation_fee', 'Kompensasi pembatalan', incoming: true),
  unknown('', 'Transaksi', incoming: true);

  const WalletTxType(this.code, this.label, {required this.incoming});

  final String code;
  final String label;

  /// Menambah saldo pengguna. Backend selalu mengirim nominal positif;
  /// arahnya ditentukan jenis transaksinya.
  final bool incoming;

  static WalletTxType fromCode(String? code) => values.firstWhere(
    (t) => t.code == code,
    orElse: () => WalletTxType.unknown,
  );
}

/// Satu baris riwayat `GET /wallet/transactions`.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.description,
    this.orderId,
  });

  final int id;
  final WalletTxType type;

  /// Selalu positif, dalam rupiah.
  final int amount;
  final int balanceAfter;
  final DateTime createdAt;
  final String? description;
  final int? orderId;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: WalletTxType.fromCode(json['transaction_type'] as String?),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse('${json['created_at']}')?.toLocal() ??
            DateTime.now(),
        description: json['description'] as String?,
        orderId: (json['order_id'] as num?)?.toInt(),
      );
}

/// Saldo dan mutasi TD-Wallet (API-WLT-01 s/d 03).
class WalletRepository {
  WalletRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Batas minimal isi saldo (FR-WLT-006).
  static const minTopup = 10000;

  Future<Wallet> wallet() async {
    final data = await _api.get('/wallet');
    return Wallet.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Terbaru di atas, 20 per halaman.
  Future<Paged<WalletTransaction>> transactions({int page = 1}) async {
    final data = await _api.get(
      '/wallet/transactions',
      query: {'page': page, 'per_page': 20},
    );
    return Paged.fromJson(
      (data as Map).cast<String, dynamic>(),
      WalletTransaction.fromJson,
    );
  }

  /// Isi saldo. Backend belum punya payment gateway, jadi saldo langsung
  /// bertambah. [idempotencyKey] yang sama tidak menambah saldo dua kali,
  /// misal saat permintaan diulang karena jaringan putus.
  Future<Wallet> topup(int amount, {required String idempotencyKey}) async {
    final data = await _api.post(
      '/wallet/topup',
      body: {'amount': amount, 'idempotency_key': idempotencyKey},
    );
    final wallet = (data as Map)['wallet'] as Map;
    return Wallet.fromJson(wallet.cast<String, dynamic>());
  }
}
