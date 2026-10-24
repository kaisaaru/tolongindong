import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../household/household_models.dart';
import '../order/widgets/order_widgets.dart';
import 'address_repository.dart';
import 'location_service.dart';

/// Tambah alamat tersimpan (`POST /addresses`). Koordinat wajib, diambil
/// dari GPS: dipakai mencari helper terdekat dan menghitung ongkos kirim.
/// Berhasil: kembali membawa alamat baru.
class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  static const _quickLabels = ['Rumah', 'Kantor', 'Kos'];

  final _label = TextEditingController(text: 'Rumah');
  final _address = TextEditingController();
  final _landmark = TextEditingController();

  ({double latitude, double longitude})? _location;
  String? _locationError;
  bool _locating = false;
  bool _primary = false;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};

  bool get _complete =>
      _label.text.trim().isNotEmpty &&
      _address.text.trim().length >= 5 &&
      _location != null;

  @override
  void initState() {
    super.initState();
    _label.addListener(_onChanged);
    _address.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _fieldErrors = const {});

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final location = await context.read<LocationService>().current();
      if (mounted) setState(() => _location = location);
    } on LocationException catch (e) {
      if (mounted) setState(() => _locationError = e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final location = _location;
    if (!_complete || location == null || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);

    try {
      final landmark = _landmark.text.trim();
      final saved = await context.read<AddressRepository>().create(
        label: _label.text.trim(),
        fullAddress: _address.text.trim(),
        latitude: location.latitude,
        longitude: location.longitude,
        landmarkNote: landmark.isEmpty ? null : landmark,
        isPrimary: _primary,
      );
      if (mounted) Navigator.of(context).pop<SavedAddress>(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      final fields = e.fieldErrors;
      if (e.code == 'VALIDATION_ERROR' && fields.isNotEmpty) {
        setState(() => _fieldErrors = fields);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            children: [
              const ArrowTitleBar('Tambah Alamat'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    const _Label('Simpan sebagai'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final quick in _quickLabels)
                          ChoiceChip(
                            label: Text(quick),
                            selected: _label.text.trim() == quick,
                            onSelected: (_) => _label.text = quick,
                            selectedColor: AppColors.primaryLight,
                            labelStyle: AppTypography.style(
                              size: 12,
                              weight: AppTypography.medium,
                              color: _label.text.trim() == quick
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                            showCheckmark: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _label,
                      hint: 'Misal: Rumah, Kantor, Rumah Ibu',
                      errorText: _fieldErrors['label'],
                    ),
                    const SizedBox(height: 18),
                    const _Label('Alamat lengkap', required: true),
                    _Field(
                      controller: _address,
                      hint: 'Nama jalan, nomor, RT/RW, kelurahan, kota',
                      maxLines: 3,
                      capitalization: TextCapitalization.sentences,
                      errorText: _fieldErrors['full_address'],
                    ),
                    const SizedBox(height: 18),
                    const _Label('Patokan'),
                    _Field(
                      controller: _landmark,
                      hint: 'Misal: pagar hitam, sebelah warung',
                      capitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 18),
                    const _Label('Titik lokasi', required: true),
                    Text(
                      'Helper terdekat dan ongkos kirim dihitung dari titik '
                      'ini. Ambil saat berada di alamat tersebut.',
                      style: AppTypography.style(
                        size: 11,
                        weight: AppTypography.regular,
                        color: AppColors.textDescription,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _locating ? null : _locate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      icon: _locating
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(
                        location == null
                            ? 'Gunakan lokasi saat ini'
                            : 'Ambil ulang lokasi',
                      ),
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Lokasi didapat '
                              '(${location.latitude.toStringAsFixed(5)}, '
                              '${location.longitude.toStringAsFixed(5)})',
                              style: AppTypography.style(
                                size: 11,
                                weight: AppTypography.regular,
                                color: AppColors.textDescription,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_locationError case final error?) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: AppTypography.style(
                          size: 11,
                          weight: AppTypography.regular,
                          color: AppColors.error,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      value: _primary,
                      onChanged: (v) => setState(() => _primary = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      title: Text(
                        'Jadikan alamat utama',
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.regular,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: PrimaryButton(
                  label: 'Simpan Alamat',
                  isLoading: _saving,
                  onPressed: _complete ? _save : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.style(size: 12, weight: AppTypography.medium);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: style,
          children: [
            if (required)
              TextSpan(
                text: '*',
                style: style.copyWith(color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

/// Isian bergaris tipis, sama seperti form Penerima Delivery.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.words,
    this.errorText,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextCapitalization capitalization;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
    );

    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: maxLines,
      textCapitalization: capitalization,
      style: AppTypography.style(size: 12, weight: AppTypography.regular),
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        isDense: true,
        filled: true,
        fillColor: AppColors.light,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        enabledBorder: border(const Color(0xFFBDBDBD)),
        focusedBorder: border(AppColors.primary),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error),
      ),
    );
  }
}
