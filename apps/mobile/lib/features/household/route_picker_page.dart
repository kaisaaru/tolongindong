import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../order/order_style.dart';
import '../order/widgets/order_widgets.dart';
import 'address_picker_page.dart';
import 'household_models.dart';
import 'widgets/household_widgets.dart';

/// Lokasi awal dan tujuan pesanan Pindahan.
typedef MoveRoute = ({SavedAddress origin, SavedAddress destination});

/// Pilih rute Pindahan dan Delivery: kolom lokasi awal (belah ketupat biru)
/// dan tujuan (pin merah), di atas daftar alamat tersimpan.
///
/// Alamat yang diketuk mengisi kolom yang sedang aktif (garis merah). Kalau
/// kolom lainnya masih kosong, kolom itu jadi aktif; kalau keduanya sudah
/// terisi, halaman ditutup membawa rutenya.
class RoutePickerPage extends StatefulWidget {
  const RoutePickerPage({
    super.key,
    this.origin,
    this.destination,
    this.editOrigin = false,
  });

  /// Null: belum dipilih. Pesanan memakai id alamat tersimpan, jadi "Lokasi
  /// saat ini" di desain diganti alamat tersimpan atau alamat baru.
  final SavedAddress? origin;
  final SavedAddress? destination;

  /// True: kolom lokasi awal yang aktif saat dibuka.
  final bool editOrigin;

  @override
  State<RoutePickerPage> createState() => _RoutePickerPageState();
}

class _RoutePickerPageState extends State<RoutePickerPage> {
  late SavedAddress? _origin = widget.origin;
  late SavedAddress? _destination = widget.destination;

  late final _originText = TextEditingController(text: _origin?.fullAddress);
  late final _destinationText = TextEditingController(
    text: _destination?.fullAddress,
  );
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();

  late bool _editingOrigin = widget.editOrigin;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _originFocus.addListener(() => _onFocus(_originFocus, origin: true));
    _destinationFocus.addListener(
      () => _onFocus(_destinationFocus, origin: false),
    );
  }

  void _onFocus(FocusNode node, {required bool origin}) {
    if (!node.hasFocus || _editingOrigin == origin) return;
    setState(() {
      _editingOrigin = origin;
      _query = '';
    });
  }

  @override
  void dispose() {
    _originText.dispose();
    _destinationText.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  /// Mengetik di kolom berarti mencari alamat baru untuk kolom itu.
  void _onTyped(String text, {required bool origin}) {
    setState(() {
      if (origin) {
        _origin = null;
      } else {
        _destination = null;
      }
      _query = text;
    });
  }

  void _pick(SavedAddress address) {
    final other = _editingOrigin ? _destination : _origin;
    final same =
        other != null &&
        (other.id != null
            ? other.id == address.id
            : other.fullAddress == address.fullAddress);
    if (same) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi awal dan tujuan tidak boleh sama.'),
        ),
      );
      return;
    }

    setState(() {
      if (_editingOrigin) {
        _origin = address;
        _originText.text = address.fullAddress;
      } else {
        _destination = address;
        _destinationText.text = address.fullAddress;
      }
      _query = '';
    });

    final origin = _origin;
    final destination = _destination;
    if (origin != null && destination != null) {
      Navigator.of(
        context,
      ).pop<MoveRoute>((origin: origin, destination: destination));
      return;
    }
    (origin == null ? _originFocus : _destinationFocus).requestFocus();
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
              Padding(
                // Panah sejajar kolom pertama; pusatnya sama dengan
                // ArrowTitleBar di halaman lain.
                padding: const EdgeInsets.fromLTRB(
                  8,
                  OrderStyle.backCenter - 24,
                  22,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          children: [
                            _RouteField(
                              icon: OrderStyle.iconLocationOrigin,
                              hint: 'Dijemput dari mana',
                              controller: _originText,
                              focusNode: _originFocus,
                              active: _editingOrigin,
                              autofocus: _editingOrigin,
                              onChanged: (v) => _onTyped(v, origin: true),
                            ),
                            const _RouteDots(),
                            _RouteField(
                              icon: OrderStyle.iconLocationPin,
                              hint: 'Mau dianter kemana',
                              controller: _destinationText,
                              focusNode: _destinationFocus,
                              active: !_editingOrigin,
                              autofocus: !_editingOrigin,
                              onChanged: (v) => _onTyped(v, origin: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: AddressListCard(query: _query, onPicked: _pick),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  const _RouteField({
    required this.icon,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.active,
    required this.autofocus,
    required this.onChanged,
  });

  final String icon;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Kolom yang akan diisi alamat yang diketuk: bergaris merah.
  final bool active;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: active ? AppColors.primary : cardBorder),
    );

    return Row(
      children: [
        SizedBox(width: 24, child: Center(child: OrderIcon(icon, size: 20))),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            style: AppTypography.style(size: 12, weight: AppTypography.medium),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: AppColors.light,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: border.borderSide.copyWith(width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Titik-titik penghubung ikon lokasi awal dan tujuan.
class _RouteDots extends StatelessWidget {
  const _RouteDots();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 24,
        height: 16,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < 3; i++)
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFB9C9D9),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 2.5),
              ),
          ],
        ),
      ),
    );
  }
}
