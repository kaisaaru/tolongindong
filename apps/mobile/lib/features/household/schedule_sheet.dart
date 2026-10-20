import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'household_models.dart';
import 'household_samples.dart';
import 'widgets/household_widgets.dart';

/// Lembar "Pilih waktu pengantaran": tujuh hari ke depan, lalu slot per jam.
/// Slot hari ini yang jamnya sudah lewat disembunyikan.
Future<TimeSlot?> showScheduleSheet(
  BuildContext context, {
  TimeSlot? initial,
  DateTime? now,
}) {
  return showModalBottomSheet<TimeSlot>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.light,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _ScheduleSheet(initial: initial, now: now ?? DateTime.now()),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.initial, required this.now});

  final TimeSlot? initial;
  final DateTime now;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  static const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  late final DateTime _today = DateTime(
    widget.now.year,
    widget.now.month,
    widget.now.day,
  );
  late final List<DateTime> _days = [
    for (var i = 0; i < 7; i++) _today.add(Duration(days: i)),
  ];

  late DateTime _day = widget.initial?.day ?? _today;
  late TimeSlot? _slot = widget.initial;

  List<TimeSlot> get _slots => [
    for (
      var h = HouseholdSamples.firstSlotHour;
      h < HouseholdSamples.lastSlotHour;
      h++
    )
      if (_day != _today || h > widget.now.hour)
        TimeSlot(day: _day, startHour: h),
  ];

  @override
  Widget build(BuildContext context) {
    final slots = _slots;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
          child: Column(
            children: [
              Text(
                'Pilih waktu pengantaran',
                style: AppTypography.style(
                  size: 22,
                  weight: AppTypography.semiBold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final day in _days)
                    _DayCell(
                      label: day == _today
                          ? 'Hari ini'
                          : _weekdays[day.weekday - 1],
                      date: day.day,
                      selected: day == _day,
                      isToday: day == _today,
                      onTap: () => setState(() {
                        _day = day;
                        if (_slot?.day != day) _slot = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: slots.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada slot tersisa hari ini.',
                          style: AppTypography.style(
                            size: AppTypography.small,
                            weight: AppTypography.regular,
                            color: AppColors.textDescription,
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final slot in slots)
                            _SlotRow(
                              label: slot.hourLabel,
                              selected: slot == _slot,
                              onTap: () => setState(() => _slot = slot),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _slot == null
                      ? null
                      : () => Navigator.of(context).pop(_slot),
                  child: const Text('Tetapkan Waktu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final int date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              label,
              style: AppTypography.style(
                size: 11,
                weight: AppTypography.regular,
                color: isToday ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : null,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$date',
                style: AppTypography.style(
                  size: 13,
                  weight: AppTypography.regular,
                  color: selected ? AppColors.light : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? selectedFill : AppColors.light,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Text(
                label,
                style: AppTypography.style(
                  size: 14,
                  weight: selected
                      ? AppTypography.medium
                      : AppTypography.regular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
