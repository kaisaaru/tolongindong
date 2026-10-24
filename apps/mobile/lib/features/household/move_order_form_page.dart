import 'package:flutter/material.dart';

import '../../core/format/rupiah.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../order/order_style.dart';
import '../order/widgets/order_widgets.dart';
import 'hourly_helper_list_page.dart';
import 'household_models.dart';
import 'order_review_page.dart';
import 'route_picker_page.dart';
import 'schedule_sheet.dart';
import 'widgets/household_widgets.dart';

/// Form pesanan Pindahan: alamat asal & tujuan, estimasi muatan, armada,
/// waktu, dan helper.
///
/// Desain tidak punya pilihan durasi; biaya helper dihitung 1 jam, dan
/// durasi masih bisa ditambah saat pesanan berjalan.
class MoveOrderFormPage extends StatefulWidget {
  const MoveOrderFormPage({super.key, required this.category});

  final ServiceCategory category;

  @override
  State<MoveOrderFormPage> createState() => _MoveOrderFormPageState();
}

class _MoveOrderFormPageState extends State<MoveOrderFormPage> {
  static const _hours = 1;

  SavedAddress? _origin;
  SavedAddress? _destination;
  LoadOption? _load;
  FleetOption? _fleet;

  /// Null + [_timeChosen] true = "Sekarang".
  TimeSlot? _slot;
  bool _timeChosen = false;
  HourlyHelper? _helper;

  bool get _complete =>
      _origin != null &&
      _destination != null &&
      _load != null &&
      _fleet != null &&
      _timeChosen &&
      _helper != null;

  /// Sebelum helper dipilih, total menampilkan tarif dasar kategori, sama
  /// seperti form Rumah.
  int get _total {
    final helper = _helper;
    if (helper == null) return widget.category.baseFee;
    return extraFees(
      _load,
      _fleet,
    ).fold(helper.hourlyRate * _hours, (sum, f) => sum + f.amount);
  }

  Future<void> _pickRoute({required bool editOrigin}) async {
    final picked = await Navigator.of(context).push<MoveRoute>(
      MaterialPageRoute(
        builder: (_) => RoutePickerPage(
          origin: _origin,
          destination: _destination,
          editOrigin: editOrigin,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _origin = picked.origin;
        _destination = picked.destination;
      });
    }
  }

  Future<void> _pickSchedule() async {
    final picked = await showScheduleSheet(
      context,
      initial: _slot,
      title: 'Pilih waktu pengerjaan',
    );
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
        builder: (_) => HourlyHelperListPage(
          categoryId: widget.category.id,
          selected: _helper,
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _helper = picked);
  }

  void _next() {
    final draft = HouseholdOrderDraft(
      service: HouseholdService.pindahan,
      address: _origin!,
      destination: _destination,
      load: _load,
      fleet: _fleet,
      slot: _slot,
      helper: _helper!,
      hours: _hours,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OrderReviewPage(draft: draft, category: widget.category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const service = HouseholdService.pindahan;
    final side = formSideInset(context);

    return Scaffold(
      backgroundColor: AppColors.light,
      body: Column(
        children: [
          ColoredHeader.of(service),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(side, 23, side, 24),
              children: [
                SectionLabel(service.addressLabel),
                const SizedBox(height: 17),
                AddressField(
                  address: _origin,
                  hint: 'Dijemput dari mana',
                  icon: OrderStyle.iconLocationOrigin,
                  onTap: () => _pickRoute(editOrigin: true),
                ),
                const SizedBox(height: 12),
                AddressField(
                  address: _destination,
                  hint: 'Mau dianter kemana',
                  onTap: () => _pickRoute(editOrigin: false),
                ),
                const SizedBox(height: 28),
                SectionLabel(service.sizeLabel),
                const SizedBox(height: 17),
                LoadRadioGroup(
                  options: LoadOption.moving,
                  selected: _load,
                  onSelected: (load) => setState(() => _load = load),
                ),
                const SizedBox(height: 28),
                const SectionLabel('Kebutuhan Armada'),
                const SizedBox(height: 17),
                SideBySide(
                  children: [
                    for (final fleet in FleetOption.values)
                      SelectCard(
                        title: fleet.label,
                        subtitle: fleet.ratePerKm == 0
                            ? rupiah(0)
                            : '${rupiah(fleet.ratePerKm)}/km',
                        centered: true,
                        selected: _fleet == fleet,
                        onTap: () => setState(() => _fleet = fleet),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                // Frame 171 menulis "Kebutuhan Armada" dua kali; frame
                // berikutnya membetulkannya jadi "Waktu Pengerjaan".
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
