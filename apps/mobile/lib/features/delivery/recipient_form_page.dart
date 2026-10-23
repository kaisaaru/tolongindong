import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../household/household_models.dart';
import '../order/order_style.dart';
import '../order/widgets/order_widgets.dart';
import 'delivery_models.dart';

/// "Penerima": alamat tujuan, lantai/no. rumah, nama, nomor kontak, dan
/// catatan untuk pengemudi. "Konfirmasi" aktif setelah nama dan nomor
/// kontak (wajib, bertanda *) terisi.
class RecipientFormPage extends StatefulWidget {
  const RecipientFormPage({super.key, required this.address, this.initial});

  final SavedAddress address;
  final Recipient? initial;

  @override
  State<RecipientFormPage> createState() => _RecipientFormPageState();
}

class _RecipientFormPageState extends State<RecipientFormPage> {
  late final _floor = TextEditingController(text: widget.initial?.floor);
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _note = TextEditingController(text: widget.initial?.note);

  /// Nomor HP Indonesia 10–13 digit; dilonggarkan 9–15.
  bool get _complete =>
      _name.text.trim().isNotEmpty &&
      _phone.text.length >= 9 &&
      _phone.text.length <= 15;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onChanged);
    _phone.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _floor.dispose();
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  void _confirm() => Navigator.of(context).pop(
    Recipient(
      name: _name.text.trim(),
      phone: _phone.text,
      floor: _optional(_floor),
      note: _optional(_note),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            children: [
              const ArrowTitleBar(''),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  decoration: OrderStyle.card(),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(32, 22, 32, 16),
                          children: [
                            Text(
                              'Penerima',
                              style: AppTypography.style(
                                size: 16,
                                weight: AppTypography.semiBold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const _Label('Alamat', required: true),
                            _ReadOnlyField(widget.address.label),
                            const SizedBox(height: 14),
                            _MapPlaceholder(label: widget.address.label),
                            const SizedBox(height: 18),
                            const _Label('Lantai atau no. rumah'),
                            _Field(
                              controller: _floor,
                              hint: 'Tambah lantai atau nomor rumah',
                            ),
                            const SizedBox(height: 18),
                            const _Label('Nama', required: true),
                            _Field(
                              controller: _name,
                              hint: 'Masukkan nama penerima',
                              capitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 18),
                            const _Label('Nomor kontak', required: true),
                            _Field(
                              controller: _phone,
                              hint: 'Masukkan nomor telfon',
                              keyboardType: TextInputType.phone,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(15),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const _Label('Catatan tambahan'),
                            _Field(
                              controller: _note,
                              hint: 'Masukkan catatan untuk pengemudi',
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 8, 32, 26),
                        child: SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: PrimaryButton(
                            label: 'Konfirmasi',
                            onPressed: _complete ? _confirm : null,
                          ),
                        ),
                      ),
                    ],
                  ),
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

OutlineInputBorder _border({Color color = const Color(0xFFBDBDBD)}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
    );

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.formatters,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      textCapitalization: capitalization,
      style: AppTypography.style(size: 12, weight: AppTypography.regular),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.light,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        enabledBorder: _border(),
        focusedBorder: _border(color: AppColors.primary),
      ),
    );
  }
}

/// Alamat tujuan sudah dipilih di halaman sebelumnya, jadi hanya dibaca.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.style(size: 12, weight: AppTypography.medium),
      ),
    );
  }
}

/// Pengganti peta di desain. Peta asli butuh paket peta dan API key yang
/// belum dipasang di app.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OrderIcon(OrderStyle.iconLocationPin, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  size: 10,
                  weight: AppTypography.medium,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
