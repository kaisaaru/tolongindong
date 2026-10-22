import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../order/order_style.dart';
import '../order/widgets/order_widgets.dart';
import 'household_models.dart';
import 'household_samples.dart';

enum HelperFilter {
  semua('Semua'),
  rating5('Rating 5'),
  rating4('Rating 4'),
  task500('Task 500+'),
  task1000('Task 1000+');

  const HelperFilter(this.label);
  final String label;

  bool matches(HourlyHelper h) => switch (this) {
    semua => true,
    rating5 => h.rating >= 5,
    rating4 => h.rating >= 4 && h.rating < 5,
    task500 => h.completedCount >= 500,
    task1000 => h.completedCount >= 1000,
  };
}

/// "Daftar Helper": helper per jam terdekat. Mengetuk kartu kembali ke form
/// membawa helper itu.
///
/// Sesuai `GET /helpers?sort_by=distance`: radius 10 km dari alamat utama,
/// diurutkan dari yang terdekat.
class HourlyHelperListPage extends StatefulWidget {
  const HourlyHelperListPage({super.key, this.selected, this.helpers});

  final HourlyHelper? selected;

  /// Diisi saat pengujian. Default: data contoh.
  final List<HourlyHelper>? helpers;

  @override
  State<HourlyHelperListPage> createState() => _HourlyHelperListPageState();
}

class _HourlyHelperListPageState extends State<HourlyHelperListPage> {
  late final _helpers = [...(widget.helpers ?? HouseholdSamples.helpers)]
    ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

  HelperFilter _filter = HelperFilter.semua;
  String _query = '';

  List<HourlyHelper> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final h in _helpers)
        if (_filter.matches(h) &&
            (q.isEmpty || h.name.toLowerCase().contains(q)))
          h,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: OrderStyle.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tata letak sama dengan halaman Personal (desainnya serupa).
              const SquareTitleBar('Daftar Helper'),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: _SearchField(
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 37,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 5,
                  ),
                  itemCount: HelperFilter.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final f = HelperFilter.values[index];
                    return _FilterChip(
                      label: f.label,
                      active: f == _filter,
                      onTap: () => setState(() => _filter = f),
                    );
                  },
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada helper yang cocok.',
                          style: AppTypography.style(
                            size: AppTypography.small,
                            weight: AppTypography.regular,
                            color: AppColors.textDescription,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          21,
                          22,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final h = visible[index];
                          return _HelperCard(
                            helper: h,
                            selected: h.id == widget.selected?.id,
                            onTap: () => Navigator.of(context).pop(h),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Sama dengan kolom cari di halaman Personal.
    final hint = AppTypography.style(
      size: AppTypography.small,
      weight: AppTypography.regular,
      color: AppColors.textSecondary,
    );

    return Container(
      height: 37,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration.collapsed(
                hintText: 'Cari jasa yang kamu butuhkan',
                hintStyle: hint,
              ),
              style: hint.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.light,
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.style(
              size: 13,
              weight: AppTypography.semiBold,
              color: active ? AppColors.light : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _HelperCard extends StatelessWidget {
  const _HelperCard({
    required this.helper,
    required this.selected,
    required this.onTap,
  });

  final HourlyHelper helper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final km = helper.distanceKm == helper.distanceKm.roundToDouble()
        ? helper.distanceKm.toInt().toString()
        : helper.distanceKm.toStringAsFixed(1).replaceAll('.', ',');

    return Material(
      color: AppColors.light,
      elevation: 3,
      shadowColor: OrderStyle.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? const BorderSide(color: AppColors.primary)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // Ukuran sama dengan kartu helper di halaman Personal.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          child: Row(
            children: [
              HelperAvatar(
                name: helper.name,
                photoUrl: helper.photoUrl,
                size: OrderStyle.inset(context, 68),
              ),
              SizedBox(width: OrderStyle.inset(context, 18)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NamePriceLine(
                      name: helper.name,
                      price: '${rupiah(helper.hourlyRate)}/Jam',
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StarRow(rating: helper.rating, size: 13),
                        const SizedBox(width: 12),
                        Text(
                          '(${helper.reviewCount})',
                          style: AppTypography.style(
                            size: 10,
                            weight: AppTypography.regular,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Jarak $km km',
                      style: AppTypography.style(
                        size: 12,
                        weight: AppTypography.regular,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
