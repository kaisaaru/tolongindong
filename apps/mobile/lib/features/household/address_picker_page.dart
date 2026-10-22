import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../order/order_style.dart';
import '../order/widgets/order_widgets.dart';
import 'household_models.dart';
import 'household_samples.dart';

/// Pilih alamat: tab Terakhir (riwayat) dan Tersimpan, plus pencarian.
/// Mengetuk alamat langsung kembali ke form membawa alamat itu.
///
/// Isinya contoh. Alamat tersimpan nanti dari `GET /addresses`, dan
/// "Tambah alamat baru" ke `POST /addresses`. Riwayat dan pencarian lokasi
/// (geocoding) belum ada di backend.
class AddressPickerPage extends StatefulWidget {
  const AddressPickerPage({super.key, this.recent, this.saved});

  /// Diisi saat pengujian. Default: data contoh.
  final List<SavedAddress>? recent;
  final List<SavedAddress>? saved;

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
                  recent: widget.recent ?? HouseholdSamples.recentAddresses,
                  saved: widget.saved ?? HouseholdSamples.savedAddresses,
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

/// Kartu bergaris berisi tab Terakhir/Tersimpan dan daftar alamat yang
/// disaring [query]. Dipakai pemilih alamat Rumah/Kamar dan pemilih rute
/// Pindahan.
class AddressListCard extends StatefulWidget {
  const AddressListCard({
    super.key,
    required this.recent,
    required this.saved,
    required this.query,
    required this.onPicked,
  });

  final List<SavedAddress> recent;
  final List<SavedAddress> saved;
  final String query;
  final ValueChanged<SavedAddress> onPicked;

  @override
  State<AddressListCard> createState() => _AddressListCardState();
}

class _AddressListCardState extends State<AddressListCard> {
  bool _showSaved = false;

  List<SavedAddress> get _visible {
    final source = _showSaved ? widget.saved : widget.recent;
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return [
      for (final a in source)
        if (a.label.toLowerCase().contains(q) ||
            a.fullAddress.toLowerCase().contains(q))
          a,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

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
            // Wrap: dengan font HP besar di layar sempit, tab kedua turun
            // baris alih-alih meluap.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tab(
                  label: 'Terakhir',
                  active: !_showSaved,
                  onTap: () => setState(() => _showSaved = false),
                ),
                _Tab(
                  label: 'Tersimpan',
                  active: _showSaved,
                  onTap: () => setState(() => _showSaved = true),
                ),
              ],
            ),
            if (_showSaved) ...[
              const SizedBox(height: 14),
              _AddNewButton(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tambah alamat belum tersedia.'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'Alamat tidak ditemukan.',
                        style: AppTypography.style(
                          size: AppTypography.small,
                          weight: AppTypography.regular,
                          color: AppColors.textDescription,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 40, endIndent: 30),
                      itemBuilder: (context, index) => _AddressRow(
                        address: visible[index],
                        onTap: () => widget.onPicked(visible[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppTypography.style(
              size: 11,
              weight: AppTypography.semiBold,
              color: active ? const Color(0xFF9A1919) : AppColors.textSecondary,
            ),
          ),
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
    final icon = switch (address.kind) {
      // Ikon target di desain belum diekspor; ikon Material yang mirip,
      // dengan merah tua yang sama seperti ikon riwayat.
      AddressKind.current => const Icon(
        Icons.my_location_rounded,
        size: 22,
        color: Color(0xFF9A1919),
      ),
      AddressKind.home => const OrderIcon(OrderStyle.iconAddressHome, size: 22),
      AddressKind.office => const OrderIcon(
        OrderStyle.iconAddressOffice,
        size: 22,
      ),
      AddressKind.recent => const OrderIcon(
        OrderStyle.iconAddressRecent,
        size: 22,
      ),
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 17, 10, 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
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
