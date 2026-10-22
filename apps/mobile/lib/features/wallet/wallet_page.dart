import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../models/auth_user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../household/household_models.dart' show clockLabel, dateLabel;
import '../order/widgets/order_widgets.dart';
import 'wallet_repository.dart';

/// TD-Wallet: saldo tersedia, saldo yang ditahan untuk pesanan, isi saldo,
/// dan riwayat mutasi (FR-WLT-001, FR-WLT-004 s/d 006).
class WalletPage extends StatefulWidget {
  const WalletPage({super.key, this.repo, this.initial});

  /// Diisi saat pengujian. Default: [WalletRepository] ke server.
  final WalletRepository? repo;

  /// Saldo dari `/me`, tampil selagi saldo terbaru dimuat.
  final Wallet? initial;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late final _repo = widget.repo ?? WalletRepository();
  late Wallet? _wallet = widget.initial;

  final _items = <WalletTransaction>[];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = await _repo.wallet();
      final first = await _repo.transactions();
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _items
          ..clear()
          ..addAll(first.items);
        _page = first.page;
        _hasMore = first.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final next = await _repo.transactions(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(next.items);
        _page = next.page;
        _hasMore = next.hasMore;
      });
    } on ApiException {
      // Halaman berikutnya gagal: berhenti memuat, yang sudah tampil tetap.
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _topup() async {
    final result = await showTopupSheet(context, repo: _repo);
    if (result == null || !mounted) return;
    setState(() => _wallet = result.wallet);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saldo bertambah ${rupiah(result.amount)}.')),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ArrowTitleBar('TD-Wallet'),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reload,
                  // Muat halaman berikutnya saat hampir sampai bawah.
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 300) _loadMore();
                      return false;
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        16,
                        24,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        _BalanceCard(wallet: _wallet, onTopup: _topup),
                        const SizedBox(height: 28),
                        Text(
                          'Riwayat Transaksi',
                          style: AppTypography.style(
                            size: 14,
                            weight: AppTypography.semiBold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._history(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _history() {
    final error = _error;
    // EmptyState bisa digulir sendiri, jadi diberi tinggi tetap di dalam
    // ListView.
    if (error != null && _items.isEmpty) {
      return [
        SizedBox(
          height: 280,
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Riwayat gagal dimuat',
            message: error.message,
            actionLabel: 'Coba lagi',
            onAction: _reload,
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      if (_loading) {
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      }
      return const [
        SizedBox(
          height: 260,
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada transaksi',
            message: 'Isi saldo dulu supaya bisa langsung memesan helper.',
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < _items.length; i++) ...[
        if (i > 0) const Divider(height: 1),
        _TransactionRow(tx: _items[i]),
      ],
      if (_hasMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
    ];
  }
}

/// Kartu merah saldo dengan tombol isi saldo.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet, required this.onTopup});

  final Wallet? wallet;
  final VoidCallback onTopup;

  @override
  Widget build(BuildContext context) {
    final wallet = this.wallet;
    final held = wallet?.heldBalance ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFFC53030)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 18,
                color: AppColors.light,
              ),
              const SizedBox(width: 8),
              Text(
                'Saldo tersedia',
                style: AppTypography.style(
                  size: 12,
                  weight: AppTypography.medium,
                  color: AppColors.light,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              wallet == null ? 'Rp -' : rupiah(wallet.availableBalance),
              style: AppTypography.style(
                size: 28,
                weight: AppTypography.bold,
                color: AppColors.light,
                height: 1.3,
              ),
            ),
          ),
          if (held > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Ditahan untuk pesanan berjalan: ${rupiah(held)}',
              style: AppTypography.style(
                size: 11,
                weight: AppTypography.regular,
                color: AppColors.light.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onTopup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.light,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 44),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Isi Saldo'),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});

  final WalletTransaction tx;

  IconData get _icon => switch (tx.type) {
    WalletTxType.topup => Icons.add_card_rounded,
    WalletTxType.hold => Icons.lock_clock_outlined,
    WalletTxType.release => Icons.payments_outlined,
    WalletTxType.advanceReimbursement => Icons.receipt_outlined,
    WalletTxType.refund => Icons.undo_rounded,
    WalletTxType.payout => Icons.account_balance_outlined,
    WalletTxType.cancellationFee => Icons.event_busy_outlined,
    WalletTxType.unknown => Icons.swap_vert_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final incoming = tx.type.incoming;
    final color = incoming ? AppColors.success : AppColors.primary;
    final description = tx.description;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.label,
                  style: AppTypography.style(
                    size: 13,
                    weight: AppTypography.semiBold,
                    height: 1.4,
                  ),
                ),
                if (description != null && description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: 11,
                      weight: AppTypography.regular,
                      color: AppColors.textDescription,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${dateLabel(tx.createdAt)}, ${clockLabel(tx.createdAt)}',
                  style: AppTypography.style(
                    size: 10,
                    weight: AppTypography.regular,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${incoming ? '+' : '-'}${rupiah(tx.amount, spaced: false)}',
            style: AppTypography.style(
              size: 13,
              weight: AppTypography.semiBold,
              color: incoming ? AppColors.success : AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hasil isi saldo: nominalnya dan saldo terbaru.
typedef TopupResult = ({int amount, Wallet wallet});

/// Lembar isi saldo: pilihan nominal cepat atau nominal lain. Null kalau
/// ditutup tanpa mengisi.
Future<TopupResult?> showTopupSheet(
  BuildContext context, {
  required WalletRepository repo,
}) {
  return showModalBottomSheet<TopupResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.light,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TopupSheet(repo: repo),
  );
}

class _TopupSheet extends StatefulWidget {
  const _TopupSheet({required this.repo});

  final WalletRepository repo;

  @override
  State<_TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<_TopupSheet> {
  static const _presets = [10000, 25000, 50000, 100000, 200000];
  static const _max = 10000000;

  final _custom = TextEditingController();
  int? _amount;
  String? _error;
  bool _loading = false;

  /// Satu kunci per nominal: mengulang permintaan yang sama (jaringan putus)
  /// tidak menambah saldo dua kali, tapi nominal baru tetap diproses.
  late String _key = _newKey();

  static String _newKey() =>
      'topup-${DateTime.now().microsecondsSinceEpoch}-'
      '${Random().nextInt(1 << 32)}';

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _setAmount(int? amount) => setState(() {
    if (amount != _amount) _key = _newKey();
    _amount = amount;
    _error = null;
  });

  Future<void> _submit() async {
    final amount = _amount;
    if (amount == null || _loading) return;
    if (amount < WalletRepository.minTopup) {
      setState(
        () => _error = 'Isi saldo minimal ${rupiah(WalletRepository.minTopup)}',
      );
      return;
    }
    if (amount > _max) {
      setState(() => _error = 'Maksimal ${rupiah(_max)} sekali isi');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);

    try {
      final wallet = await widget.repo.topup(amount, idempotencyKey: _key);
      if (mounted) Navigator.of(context).pop((amount: amount, wallet: wallet));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.fieldErrors['amount'] ?? e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amount;

    return Padding(
      // Lembar naik di atas keyboard saat mengetik nominal.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Isi Saldo',
                style: AppTypography.style(
                  size: 18,
                  weight: AppTypography.semiBold,
                ),
              ),
              const SizedBox(height: 6),
              // Backend belum punya payment gateway (API-WLT-03 simulasi).
              Text(
                'Mode uji: belum ada pembayaran sungguhan, saldo langsung '
                'bertambah.',
                style: AppTypography.style(
                  size: 12,
                  weight: AppTypography.regular,
                  color: AppColors.textDescription,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in _presets)
                    _AmountChip(
                      label: rupiah(preset),
                      selected: amount == preset && _custom.text.isEmpty,
                      onTap: () {
                        _custom.clear();
                        _setAmount(preset);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Nominal lain',
                hint: 'Minimal ${rupiah(WalletRepository.minTopup)}',
                controller: _custom,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                textInputAction: TextInputAction.done,
                errorText: _error,
                onChanged: (v) => _setAmount(int.tryParse(v)),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: amount == null ? 'Isi Saldo' : 'Isi ${rupiah(amount)}',
                isLoading: _loading,
                onPressed: amount == null ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : AppColors.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: AppTypography.style(
                size: 12,
                weight: AppTypography.semiBold,
                color: selected ? AppColors.light : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
