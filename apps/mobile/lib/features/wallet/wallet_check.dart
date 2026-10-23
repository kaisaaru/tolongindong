import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../auth/session_store.dart';
import 'wallet_page.dart';
import 'wallet_repository.dart';

/// Pesanan dibayar dari TD-Wallet: saldo ditahan saat helper menerima, dan
/// helper gagal menerima kalau saldo kurang. Jadi sebelum memesan, saldo
/// terbaru dicek; kalau kurang, pengguna diajak isi saldo dulu.
///
/// True kalau saldo cukup untuk [total].
Future<bool> ensureWalletBalance(BuildContext context, int total) async {
  final session = context.read<SessionStore>();
  final repo = context.read<WalletRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  final int available;
  try {
    final wallet = await repo.wallet();
    session.updateWallet(wallet);
    available = wallet.availableBalance;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
  if (available >= total) return true;
  if (!context.mounted) return false;

  final topup = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Saldo TD-Wallet kurang'),
      content: Text(
        'Total pesanan ${rupiah(total)}, saldomu ${rupiah(available)}. '
        'Isi saldo dulu, lalu pesan lagi.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Nanti'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Isi Saldo'),
        ),
      ],
    ),
  );
  if (topup == true) {
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const WalletPage()),
    );
  }
  return false;
}

/// Muat ulang saldo tanpa indikator, supaya baris metode pembayaran
/// menampilkan saldo terbaru. Gagal: saldo lama tetap tampil.
Future<void> refreshWalletBalance(BuildContext context) async {
  final session = context.read<SessionStore>();
  final repo = context.read<WalletRepository>();
  try {
    session.updateWallet(await repo.wallet());
  } on ApiException {
    // Dicek ulang saat memesan (ensureWalletBalance).
  }
}

/// "TD-Wallet · Saldo Rp 250.000" untuk baris metode pembayaran.
String walletPaymentLabel(BuildContext context) {
  final balance = context.watch<SessionStore>().user?.wallet.availableBalance;
  return balance == null ? 'TD-Wallet' : 'TD-Wallet · Saldo ${rupiah(balance)}';
}

/// Buka TD-Wallet dari baris metode pembayaran, misal untuk isi saldo.
void openWallet(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const WalletPage()));
