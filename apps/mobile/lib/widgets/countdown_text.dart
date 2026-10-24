import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// "04:32" menuju [until], berdetak tiap detik; "00:00" setelah lewat.
class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.until,
    required this.clock,
    this.style,
  });

  final DateTime until;
  final DateTime Function() clock;
  final TextStyle? style;

  /// Sisa waktu, tidak pernah negatif.
  static Duration remaining(DateTime until, DateTime now) {
    final left = until.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  static String label(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _tick;
  late String _label = _current;

  String get _current => CountdownText.label(
    CountdownText.remaining(widget.until, widget.clock()),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(CountdownText old) {
    super.didUpdateWidget(old);
    _label = _current;
    _sync();
  }

  /// Dibangun ulang hanya saat angkanya berubah, dan berhenti berdetak
  /// setelah habis.
  void _sync() {
    final running =
        CountdownText.remaining(widget.until, widget.clock()) > Duration.zero;
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final label = _current;
        if (label != _label) setState(() => _label = label);
        if (CountdownText.remaining(widget.until, widget.clock()) ==
            Duration.zero) {
          _tick?.cancel();
          _tick = null;
        }
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label,
      style:
          widget.style ??
          AppTypography.style(
            size: 12,
            weight: AppTypography.bold,
            color: const Color(0xFFE5383B),
          ),
    );
  }
}
