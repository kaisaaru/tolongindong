import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Input kode OTP berbentuk kotak per digit.
///
/// Kotak-kotaknya cuma tampilan. Input aslinya satu TextField tak terlihat
/// yang menutupi kotak, jadi paste, hapus, dan autofill kode dari SMS tetap
/// jalan seperti text field biasa. Keyboard langsung muncul saat halaman dibuka.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    this.controller,
    this.hasError = false,
    this.onChanged,
    this.onSubmitted,
  });

  final int length;

  /// Diisi kalau halaman perlu mengosongkan kode dari luar, misalnya
  /// setelah server menolak kodenya.
  final TextEditingController? controller;

  /// Memerahkan semua kotak. Pesannya sendiri ditampilkan halaman.
  final bool hasError;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final _focusNode = FocusNode();

  /// Controller milik halaman tidak boleh ikut dibuang di sini.
  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCodeChanged);
    // Rebuild supaya kotak aktif ikut hilang/muncul saat fokus berubah.
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.removeListener(_onCodeChanged);
    if (_ownsController) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    // Kursor dikunci di akhir, supaya digit baru tidak nyelip di tengah
    // kalau user mengetuk kotak yang sudah terisi.
    final end = TextSelection.collapsed(offset: _controller.text.length);
    if (_controller.selection != end) _controller.selection = end;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    // Kotak yang menunggu digit berikutnya. Kalau sudah penuh, kotak terakhir.
    final activeIndex = math.min(code.length, widget.length - 1);

    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _OtpBox(
                  digit: i < code.length ? code[i] : '',
                  isActive: _focusNode.hasFocus && i == activeIndex,
                  hasError: widget.hasError,
                ),
              ),
            ],
          ],
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            alwaysIncludeSemantics: true, // tetap terbaca screen reader
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              showCursor: false,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              decoration: const InputDecoration.collapsed(hintText: 'Kode OTP'),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.isActive,
    this.hasError = false,
  });

  final String digit;
  final bool isActive;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(8),
        // Sama seperti focusedBorder text field di theme.
        border: hasError
            ? Border.all(color: AppColors.error, width: 1.5)
            : isActive
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
      ),
      child: Text(
        digit,
        style: AppTypography.style(
          size: AppTypography.h6,
          weight: AppTypography.medium,
        ),
      ),
    );
  }
}
