import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../household/household_models.dart';
import '../household/schedule_sheet.dart';
import '../household/widgets/household_widgets.dart';
import 'delivery_models.dart';

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);

/// "Kapan barang ini mau kamu kirimkan?" — Antar Sekarang atau Antar Nanti
/// (membuka "Pilih waktu pengantaran"). Null kalau ditutup tanpa memilih.
Future<DeliverySchedule?> showDeliveryTimeSheet(
  BuildContext context, {
  DeliverySchedule? initial,
  DateTime? now,
}) {
  return showModalBottomSheet<DeliverySchedule>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.light,
    shape: _sheetShape,
    builder: (_) => _TimeSheet(initial: initial, now: now ?? DateTime.now()),
  );
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial, required this.now});

  final DeliverySchedule? initial;
  final DateTime now;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late DeliverySchedule? _choice = widget.initial;

  Future<void> _pickLater() async {
    final slot = await showScheduleSheet(
      context,
      initial: _choice?.slot,
      now: widget.now,
    );
    if (slot != null && mounted) {
      setState(() => _choice = DeliverySchedule.at(slot));
    }
  }

  @override
  Widget build(BuildContext context) {
    final choice = _choice;
    final slot = choice?.slot;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Kapan barang ini mau kamu kirimkan?',
              style: AppTypography.style(
                size: 18,
                weight: AppTypography.semiBold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            _TimeOption(
              icon: Icons.inventory_2_outlined,
              title: 'Antar Sekarang',
              subtitle:
                  'Akan diantar sebelum jam ${clockLabel(deliverBy(widget.now))}',
              selected: choice != null && choice.isNow,
              onTap: () =>
                  setState(() => _choice = const DeliverySchedule.now()),
            ),
            const SizedBox(height: 10),
            _TimeOption(
              icon: Icons.update_rounded,
              title: 'Antar Nanti',
              // Desain: "Diantar tanggal 22, jam 10.00".
              subtitle: slot == null
                  ? 'Pilih tanggal dan jam pengantaran'
                  : 'Diantar tanggal ${slot.day.day}, '
                        'jam ${clockLabel(slot.start)}',
              selected: slot != null,
              chevron: true,
              onTap: _pickLater,
            ),
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: 230,
                child: PrimaryButton(
                  label: 'Pilih Pengantaran ini',
                  onPressed: choice == null
                      ? null
                      : () => Navigator.of(context).pop(choice),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeOption extends StatelessWidget {
  const _TimeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.chevron = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool chevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedFill : AppColors.light,
        // Desain: pilihan yang tidak terpilih tanpa garis.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: selected
              ? const BorderSide(color: AppColors.primary)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.medium,
                          height: 1.4,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.style(
                          size: 9,
                          weight: AppTypography.regular,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (chevron)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Barang apa ya mau dikirim?" — ukuran, berat, jenis. Null kalau ditutup.
Future<DeliveryItem?> showItemSheet(
  BuildContext context, {
  DeliveryItem? initial,
}) {
  return showModalBottomSheet<DeliveryItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.light,
    shape: _sheetShape,
    builder: (_) => _ItemSheet(initial: initial),
  );
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.initial});

  final DeliveryItem? initial;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  // Desain: ukuran S terpilih sejak awal.
  late ItemSize _size = widget.initial?.size ?? ItemSize.s;
  late ItemType? _type = widget.initial?.type;
  late final _weight = TextEditingController(
    text: widget.initial?.weightKg.toString(),
  );

  int get _weightKg => int.tryParse(_weight.text) ?? 0;

  bool get _complete => _weightKg > 0 && _type != null;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = _type;

    return Padding(
      // Lembar naik di atas keyboard saat mengisi berat.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Barang apa ya mau dikirim?',
                      style: AppTypography.style(
                        size: 16,
                        weight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Ukuran'),
                    const SizedBox(height: 8),
                    Text(
                      _size.dimensions,
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _SizeToggle(
                      selected: _size,
                      onSelected: (s) => setState(() => _size = s),
                    ),
                    const SizedBox(height: 22),
                    const _FieldLabel('Berat'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: TextField(
                            controller: _weight,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            textAlign: TextAlign.center,
                            style: AppTypography.style(
                              size: 18,
                              weight: AppTypography.regular,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              enabledBorder: _weightBorder(),
                              focusedBorder: _weightBorder(width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Kg',
                          style: AppTypography.style(
                            size: 18,
                            weight: AppTypography.regular,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _FieldLabel('Jenis Barang'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in ItemType.values)
                          _TypeChip(
                            type: t,
                            selected: t == type,
                            onTap: () => setState(() => _type = t),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Desain: tombol Selesai selebar lembar.
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Selesai',
                    onPressed: _complete
                        ? () => Navigator.of(context).pop(
                            DeliveryItem(
                              size: _size,
                              weightKg: _weightKg,
                              type: type!,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _weightBorder({double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary, width: width),
      );
}

/// S | M | L berdempetan; yang terpilih merah penuh.
class _SizeToggle extends StatelessWidget {
  const _SizeToggle({required this.selected, required this.onSelected});

  final ItemSize selected;
  final ValueChanged<ItemSize> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final size in ItemSize.values)
          Semantics(
            button: true,
            selected: size == selected,
            label: 'Ukuran ${size.label}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onSelected(size),
              child: Container(
                width: 48,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: size == selected
                      ? AppColors.primary
                      : const Color(0xFFFFF1F1),
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(size == ItemSize.s ? 4 : 0),
                    right: Radius.circular(size == ItemSize.l ? 4 : 0),
                  ),
                ),
                child: Text(
                  size.label,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.semiBold,
                    color: size == selected
                        ? AppColors.light
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ItemType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.light : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        // Desain belum punya tampilan terpilih; dipakai merah penuh seperti
        // tombol ukuran yang terpilih.
        color: selected ? AppColors.primary : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  type.label,
                  style: AppTypography.style(
                    size: 10,
                    weight: AppTypography.medium,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(type.icon, size: 13, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label bagian di lembar barang: lebih kecil dan tipis dari [SectionLabel],
/// seperti Frame 84.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.style(size: 13, weight: AppTypography.medium),
    );
  }
}
