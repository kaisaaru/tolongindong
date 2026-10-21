import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../order/widgets/order_widgets.dart';
import 'address_picker_page.dart';
import 'household_models.dart';
import 'household_samples.dart';
import 'hourly_helper_list_page.dart';
import 'order_review_page.dart';
import 'schedule_sheet.dart';
import 'widgets/household_widgets.dart';

/// Form pesanan Rumah/Kamar/Pakaian: alamat, ukuran (Rumah/Kamar) atau
/// estimasi muatan (Pakaian), alat, waktu, helper, durasi.
///
/// "Lanjut Pesan" aktif setelah alamat, ukuran/muatan, waktu, dan helper
/// terisi. Ketersediaan alat boleh kosong (di desain tombolnya tetap aktif
/// tanpa memilih alat).
class HouseOrderFormPage extends StatefulWidget {
  const HouseOrderFormPage({
    super.key,
    required this.service,
    required this.category,
  });

  final HouseholdService service;
  final ServiceCategory category;

  @override
  State<HouseOrderFormPage> createState() => _HouseOrderFormPageState();
}

class _HouseOrderFormPageState extends State<HouseOrderFormPage> {
  final _width = TextEditingController();
  final _length = TextEditingController();

  SavedAddress? _address;
  LoadOption? _load;
  ToolOption? _tools;

  /// Null + [_timeChosen] true = "Sekarang".
  TimeSlot? _slot;
  bool _timeChosen = false;
  HourlyHelper? _helper;
  int _hours = HouseholdSamples.durationOptions.first;

  /// Diisi untuk Pakaian: bagian ukuran diganti estimasi muatan.
  List<LoadOption>? get _loadOptions => widget.service.loadOptions;

  double? get _widthM => parseMeter(_width.text);
  double? get _lengthM => parseMeter(_length.text);

  bool get _sizeFilled => _loadOptions == null
      ? (_widthM ?? 0) > 0 && (_lengthM ?? 0) > 0
      : _load != null;

  bool get _complete =>
      _address != null && _sizeFilled && _timeChosen && _helper != null;

  /// Sebelum helper dipilih, total menampilkan tarif dasar kategori.
  int get _total => _helper == null
      ? widget.category.baseFee
      : _helper!.hourlyRate * _hours + (_load?.fee ?? 0);

  @override
  void initState() {
    super.initState();
    _width.addListener(_onChanged);
    _length.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _width.dispose();
    _length.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => const AddressPickerPage()),
    );
    if (picked != null && mounted) setState(() => _address = picked);
  }

  Future<void> _pickSchedule() async {
    final picked = await showScheduleSheet(context, initial: _slot);
    if (picked != null && mounted) {
      setState(() {
        _slot = picked;
        _timeChosen = true;
      });
    }
  }

  Future<void> _pickHelper() async {
    final picked = await Navigator.of(context).push<HourlyHelper>(
      MaterialPageRoute(
        builder: (_) => HourlyHelperListPage(selected: _helper),
      ),
    );
    if (picked != null && mounted) setState(() => _helper = picked);
  }

  void _next() {
    final usesLoad = _loadOptions != null;
    final draft = HouseholdOrderDraft(
      service: widget.service,
      address: _address!,
      widthM: usesLoad ? null : _widthM,
      lengthM: usesLoad ? null : _lengthM,
      load: usesLoad ? _load : null,
      tools: _tools,
      slot: _slot,
      helper: _helper!,
      hours: _hours,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OrderReviewPage(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final loadOptions = _loadOptions;

    return Scaffold(
      backgroundColor: AppColors.light,
      body: Column(
        children: [
          ColoredHeader.of(service),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(36, 23, 36, 24),
              children: [
                SectionLabel(service.addressLabel),
                const SizedBox(height: 17),
                AddressField(
                  address: _address,
                  hint: service.addressHint,
                  onTap: _pickAddress,
                ),
                const SizedBox(height: 28),
                SectionLabel(service.sizeLabel),
                const SizedBox(height: 17),
                if (loadOptions != null)
                  LoadRadioGroup(
                    options: loadOptions,
                    selected: _load,
                    onSelected: (load) => setState(() => _load = load),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _MeterField(
                          label: 'Lebar :',
                          controller: _width,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MeterField(
                          label: 'Panjang:',
                          controller: _length,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 28),
                const SectionLabel('Ketersediaan alat'),
                const SizedBox(height: 17),
                Row(
                  children: [
                    for (final option in ToolOption.values) ...[
                      if (option != ToolOption.values.first)
                        const SizedBox(width: 12),
                      Expanded(
                        child: SelectCard(
                          // Desain memakai huruf kapital tiap kata di tombol.
                          title: option == ToolOption.provided
                              ? 'Alat Disediakan'
                              : 'Alat Tidak Disediakan',
                          centered: true,
                          selected: _tools == option,
                          onTap: () => setState(
                            () => _tools = _tools == option ? null : option,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                const SectionLabel('Waktu Pengerjaan'),
                const SizedBox(height: 17),
                WorkTimeCards(
                  slot: _slot,
                  chosen: _timeChosen,
                  onNow: () => setState(() {
                    _slot = null;
                    _timeChosen = true;
                  }),
                  onSchedule: _pickSchedule,
                ),
                const SizedBox(height: 28),
                const SectionLabel('Pilih Helper'),
                const SizedBox(height: 17),
                HelperPickerField(helper: _helper, onTap: _pickHelper),
                const SizedBox(height: 28),
                const SectionLabel('Tentukan Durasi'),
                const SizedBox(height: 17),
                DurationChips(
                  options: HouseholdSamples.durationOptions,
                  selected: _hours,
                  onSelected: (h) => setState(() => _hours = h),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: OrderBottomBar(
        caption: 'Total',
        amount: rupiah(_total),
        enabled: _complete,
        button: PrimaryButton(
          label: 'Lanjut Pesan',
          onPressed: _complete ? _next : null,
        ),
      ),
    );
  }
}

/// Isian angka meter dengan label di kiri dan satuan "m" di kanan.
class _MeterField extends StatelessWidget {
  const _MeterField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.style(size: 14, weight: AppTypography.regular);
    const tight = BoxConstraints(minWidth: 0, minHeight: 0);

    // Label dan "m" dipasang sebagai ikon TextField: label tampil utuh dan
    // kolom angka mengisi sisanya. Di layar sangat sempit yang menyusut
    // kolom angkanya, bukan meluap. Mengetuk di mana pun di kotak ini
    // langsung memfokuskan isian.
    //
    // Padding sengaja tipis: di iPhone (390 dp) kotak ini cuma ±149 dp,
    // dan "Panjang:" sudah memakan ±61 dp. Sisa ±44 dp cukup untuk "12,5".
    return OutlinedBox(
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        // Kamar sering berukuran pecahan (3,5 m), jadi desimal diizinkan.
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [_MeterFormatter()],
        textAlign: TextAlign.center,
        style: style,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: '0',
          hintStyle: style.copyWith(color: AppColors.disabled),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Text(label, style: style),
          ),
          prefixIconConstraints: tight,
          suffixIcon: Padding(
            padding: const EdgeInsets.only(left: 4, right: 14),
            child: Text('m', style: style),
          ),
          suffixIconConstraints: tight,
        ),
      ),
    );
  }
}

/// Hanya menerima ukuran meter yang masuk akal: maksimal 3 digit bulat dan
/// 1 digit desimal, dengan koma atau titik ("12", "3,5", "999.9").
/// Ketikan yang membuatnya tidak valid ditolak, isian lama dipertahankan.
class _MeterFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d{0,3}([.,]\d?)?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}
