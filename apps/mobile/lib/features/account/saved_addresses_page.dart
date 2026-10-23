import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../address/add_address_page.dart';
import '../address/address_repository.dart';
import '../household/household_models.dart';
import '../household/widgets/household_widgets.dart';
import 'widgets/account_menu.dart';

/// Alamat Tersimpan (`/addresses`): daftar, tambah, jadikan utama, hapus.
/// Alamat utama dipakai sebagai lokasi awal Delivery dan lokasi Personal.
class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  late final _repo = context.read<AddressRepository>();
  late Future<List<SavedAddress>> _addresses = _repo.list();

  /// Alamat yang sedang diubah (jadikan utama/hapus).
  int? _busyId;

  void _reload() => setState(() {
    _addresses = _repo.list();
  });

  void _show(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add() async {
    final added = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => const AddAddressPage()),
    );
    if (added == null || !mounted) return;
    _reload();
    _show('Alamat ${added.label} disimpan.');
  }

  Future<void> _run(
    SavedAddress address,
    Future<void> Function() action,
    String done,
  ) async {
    setState(() => _busyId = address.id);
    try {
      await action();
      if (!mounted) return;
      _reload();
      _show(done);
    } on ApiException catch (e) {
      if (mounted) _show(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _setPrimary(SavedAddress address) => _run(
    address,
    () => _repo.setPrimary(address.id!),
    '${address.label} jadi alamat utama.',
  );

  Future<void> _delete(SavedAddress address) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus alamat?'),
        content: Text(
          '${address.label} dihapus dari alamat tersimpan. Pesanan lama '
          'tidak lagi menampilkan alamat ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _run(
      address,
      () => _repo.delete(address.id!),
      '${address.label} dihapus.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            children: [
              const AccountTitleBar('Alamat Tersimpan'),
              Expanded(
                child: FutureBuilder<List<SavedAddress>>(
                  future: _addresses,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final error = snapshot.error;
                    if (error != null) {
                      return EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Alamat gagal dimuat',
                        message: error is ApiException
                            ? error.message
                            : 'Coba lagi sebentar lagi.',
                        actionLabel: 'Coba lagi',
                        onAction: _reload,
                      );
                    }
                    final addresses = snapshot.data ?? const [];
                    if (addresses.isEmpty) {
                      return const EmptyState(
                        icon: Icons.location_off_outlined,
                        title: 'Belum ada alamat tersimpan',
                        message:
                            'Simpan alamat rumah atau kantor supaya memesan '
                            'helper lebih cepat.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _addresses.catchError((_) => <SavedAddress>[]);
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AccountStyle.side,
                          20,
                          AccountStyle.side,
                          20,
                        ),
                        itemCount: addresses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final address = addresses[i];
                          return _AddressCard(
                            address: address,
                            busy: _busyId != null && _busyId == address.id,
                            onSetPrimary: () => _setPrimary(address),
                            onDelete: () => _delete(address),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AccountStyle.side,
                  8,
                  AccountStyle.side,
                  16,
                ),
                child: PrimaryButton(
                  label: 'Tambah Alamat',
                  onPressed: _busyId == null ? _add : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Action { primary, delete }

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.busy,
    required this.onSetPrimary,
    required this.onDelete,
  });

  final SavedAddress address;
  final bool busy;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final landmark = address.landmarkNote;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: address.isPrimary ? AppColors.primary : AccountStyle.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddressKindIcon(address.kind),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        address.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.semiBold,
                          color: AccountStyle.ink,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (address.isPrimary) ...[
                      const SizedBox(width: 8),
                      const _PrimaryBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address.fullAddress,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.regular,
                    color: AccountStyle.muted,
                    height: 1.5,
                  ),
                ),
                if (landmark != null && landmark.isNotEmpty)
                  Text(
                    'Patokan: $landmark',
                    style: AppTypography.style(
                      size: 11,
                      weight: AppTypography.regular,
                      color: AccountStyle.muted,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<_Action>(
              tooltip: 'Pilihan alamat',
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AccountStyle.muted,
              ),
              onSelected: (action) => switch (action) {
                _Action.primary => onSetPrimary(),
                _Action.delete => onDelete(),
              },
              itemBuilder: (_) => [
                if (!address.isPrimary)
                  const PopupMenuItem(
                    value: _Action.primary,
                    child: Text('Jadikan alamat utama'),
                  ),
                const PopupMenuItem(
                  value: _Action.delete,
                  child: Text('Hapus'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Utama',
        style: AppTypography.style(
          size: 9,
          weight: AppTypography.semiBold,
          color: AppColors.primary,
          height: 1.4,
        ),
      ),
    );
  }
}
