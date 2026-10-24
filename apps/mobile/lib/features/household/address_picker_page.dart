import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../address/add_address_page.dart';
import '../address/address_repository.dart';
import '../order/order_style.dart';
import '../order/widgets/order_widgets.dart';
import 'household_models.dart';
import 'widgets/household_widgets.dart';

/// Pilih alamat tersimpan (`GET /addresses`), bisa dicari, atau tambah
/// alamat baru. Mengetuk alamat langsung kembali ke form membawa alamat itu.
///
/// Pesanan dibuat memakai id alamat, jadi hanya alamat tersimpan yang bisa
/// dipilih. Riwayat dan pencarian lokasi (geocoding) belum ada di backend.
class AddressPickerPage extends StatefulWidget {
  const AddressPickerPage({super.key});

  @override
  State<AddressPickerPage> createState() => _AddressPickerPageState();
}

class _AddressPickerPageState extends State<AddressPickerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            children: [
              // Baris judul standar; posisi panah sama dengan halaman lain.
              ArrowTitleBar(
                '',
                leading: Row(
                  children: [
                    const OrderIcon(OrderStyle.iconLocationPin, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                        style: AppTypography.style(
                          size: 12,
                          weight: AppTypography.regular,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Mau dianter kemana',
                          filled: true,
                          fillColor: AppColors.light,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enabledBorder: _border(),
                          focusedBorder: _border(width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AddressListCard(
                  query: _query,
                  onPicked: (address) => Navigator.of(context).pop(address),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _border({double width = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide(color: AppColors.primary, width: width),
  );
}

/// Kartu bergaris berisi alamat tersimpan yang disaring [query], dan
/// tombol tambah alamat baru. Dipakai pemilih alamat Rumah/Kamar, pemilih
/// rute Pindahan, dan Delivery.
class AddressListCard extends StatefulWidget {
  const AddressListCard({
    super.key,
    required this.query,
    required this.onPicked,
  });

  final String query;

  /// Alamat yang diketuk, termasuk alamat yang baru ditambahkan.
  final ValueChanged<SavedAddress> onPicked;

  @override
  State<AddressListCard> createState() => _AddressListCardState();
}

class _AddressListCardState extends State<AddressListCard> {
  late Future<List<SavedAddress>> _addresses = _fetch();

  Future<List<SavedAddress>> _fetch() =>
      context.read<AddressRepository>().list();

  void _reload() => setState(() {
    _addresses = _fetch();
  });

  List<SavedAddress> _visible(List<SavedAddress> all) {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final a in all)
        if (a.label.toLowerCase().contains(q) ||
            a.fullAddress.toLowerCase().contains(q))
          a,
    ];
  }

  Future<void> _add() async {
    final added = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => const AddAddressPage()),
    );
    if (added == null || !mounted) return;
    _reload();
    widget.onPicked(added);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 17, 14, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textPrimary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap: dengan font HP besar di layar sempit, tombol turun
            // baris alih-alih meluap.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _ListTitle('Tersimpan'),
                _AddNewButton(onTap: _add),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: FutureBuilder<List<SavedAddress>>(
                future: _addresses,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final error = snapshot.error;
                  if (error != null) {
                    return _Message(
                      error is ApiException
                          ? error.message
                          : 'Alamat gagal dimuat.',
                      onRetry: _reload,
                    );
                  }
                  final all = snapshot.data ?? const <SavedAddress>[];
                  if (all.isEmpty) {
                    return const _Message(
                      'Belum ada alamat tersimpan. Tambahkan alamat baru '
                      'dulu.',
                    );
                  }
                  final visible = _visible(all);
                  if (visible.isEmpty) {
                    return const _Message('Alamat tidak ditemukan.');
                  }
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 40, endIndent: 30),
                    itemBuilder: (context, index) => _AddressRow(
                      address: visible[index],
                      onTap: () => widget.onPicked(visible[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.style(
                size: AppTypography.small,
                weight: AppTypography.regular,
                color: AppColors.textDescription,
                height: 1.5,
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

/// Judul daftar: pil pink "Tersimpan", seperti tab aktif di desain.
class _ListTitle extends StatelessWidget {
  const _ListTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          size: 11,
          weight: AppTypography.semiBold,
          color: const Color(0xFF9A1919),
        ),
      ),
    );
  }
}

class _AddNewButton extends StatelessWidget {
  const _AddNewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2ECC40),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 15,
                color: AppColors.light,
              ),
              const SizedBox(width: 6),
              Text(
                'Tambah alamat baru',
                style: AppTypography.style(
                  size: 11,
                  weight: AppTypography.semiBold,
                  color: AppColors.light,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.onTap});

  final SavedAddress address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 17, 10, 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AddressKindIcon(address.kind),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.label,
                    style: AppTypography.style(
                      size: 12,
                      weight: AppTypography.semiBold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.fullAddress,
                    style: AppTypography.style(
                      size: 10,
                      weight: AppTypography.regular,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
