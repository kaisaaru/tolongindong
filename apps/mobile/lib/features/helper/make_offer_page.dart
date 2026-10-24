import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../theme/app_typography.dart';
import '../household/household_models.dart';
import '../order/order_repository.dart';
import '../order/widgets/order_widgets.dart';
import 'helper_store.dart';
import 'widgets/helper_widgets.dart';

/// Buat penawaran untuk permintaan direct: harga, komisi 10%, pendapatan
/// bersih. Setelah dikirim, tampil [OfferSentPage]; Client punya 5 menit
/// untuk menyetujui.
class MakeOfferPage extends StatefulWidget {
  const MakeOfferPage({super.key, required this.job, this.initialPrice});

  final ServerOrder job;

  /// Harga awal, misal penawaran sebelumnya saat mengirim ulang.
  final int? initialPrice;

  /// Minimal dari backend (`proposed_price` min 1000).
  static const minPrice = 1000;

  @override
  State<MakeOfferPage> createState() => _MakeOfferPageState();
}

class _MakeOfferPageState extends State<MakeOfferPage> {
  late final _store = context.read<HelperStore>();

  /// Awalnya [MakeOfferPage.initialPrice], estimasi Client, atau tarif per
  /// jam kalau Client tidak mengisi estimasi.
  late final _price = TextEditingController(
    text: _digits(
      widget.initialPrice ??
          (widget.job.estimatedPrice > 0
              ? widget.job.estimatedPrice
              : _store.status.hourlyRate),
    ),
  );
  final _focus = FocusNode();
  bool _sending = false;

  static String _digits(int value) => value <= 0 ? '' : thousands(value);

  int get _value => int.tryParse(_price.text.replaceAll('.', '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _price.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _price.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final price = _value;
    if (price < MakeOfferPage.minPrice || _sending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sending = true);
    try {
      await _store.submitOffer(widget.job.id, price);
      // Halaman pekerjaan di bawahnya sudah berganti jadi "Menunggu
      // keputusan"; tombol di halaman berikut kembali ke sana.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => OfferSentPage(orderId: widget.job.id),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final price = _value;
    final valid = price >= MakeOfferPage.minPrice;

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          const HelperHeader(
            title: 'Buat penawaran',
            subtitle: 'Tentukan harga untuk pekerjaan ini',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                HelperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      JobSummary(order: job, details: false),
                      const Divider(height: 22, color: HelperStyle.cardBorder),
                      HelperRow(
                        'Estimasi dari Client',
                        job.estimatedPrice > 0
                            ? rupiah(job.estimatedPrice, spaced: false)
                            : '-',
                      ),
                      Text(
                        'Estimasi ini bukan harga yang disepakati.',
                        style: AppTypography.style(
                          size: 9,
                          weight: AppTypography.regular,
                          color: HelperStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HelperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harga penawaranmu',
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.semiBold,
                          color: HelperStyle.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PriceField(
                        controller: _price,
                        focus: _focus,
                        error: price > 0 && !valid
                            ? 'Minimal ${rupiah(MakeOfferPage.minPrice)}'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      EarningBreakdown(
                        price: price,
                        priceLabel: 'Penawaran Helper',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const HelperBanner(
                  title: 'Selanjutnya: menunggu keputusan Client',
                  message:
                      'Client punya 5 menit (300 detik) untuk menyetujui. '
                      'Mengirim penawaran belum membuat pesanan aktif.',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: HelperBottomBar(
        children: [
          HelperButton(
            label: 'Kirim Penawaran',
            isLoading: _sending,
            onPressed: valid ? _send : null,
          ),
        ],
      ),
    );
  }
}

/// "Penawaran berhasil dikirim": batas keputusan Client, ringkasan, lalu
/// kembali ke halaman pekerjaan yang kini menunggu keputusan.
class OfferSentPage extends StatelessWidget {
  const OfferSentPage({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HelperStore>();
    final job = store.byId(orderId);
    final offer = job == null ? null : store.myOffer(job);
    final client = job?.client?.name ?? 'Client';
    final validUntil = offer?.validUntil;
    final sentAt = validUntil?.subtract(const Duration(minutes: 5));
    final muted = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      color: HelperStyle.muted,
      height: 1.5,
    );

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          HelperHeader(
            title: 'Penawaran terkirim',
            subtitle: 'Penawaran untuk $client',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: HelperStyle.softGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: HelperStyle.green,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Penawaran berhasil dikirim',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    size: 17,
                    weight: AppTypography.semiBold,
                    color: HelperStyle.ink,
                  ),
                ),
                if (sentAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${dateLabel(sentAt)} · ${clockLabel(sentAt)}',
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                ],
                const SizedBox(height: 18),
                HelperBanner(
                  title: 'Menunggu keputusan Client',
                  message: sentAt == null || validUntil == null
                      ? '$client punya 300 detik (5 menit) untuk menyetujui.'
                      : '$client punya 300 detik (5 menit) sejak pengiriman '
                            '${clockLabel(sentAt)}, sampai '
                            '${clockLabel(validUntil)}.',
                ),
                if (job != null && offer != null) ...[
                  const SizedBox(height: 12),
                  HelperCard(
                    child: Column(
                      children: [
                        JobSummary(order: job, details: false),
                        const Divider(
                          height: 22,
                          color: HelperStyle.cardBorder,
                        ),
                        EarningBreakdown(
                          price: offer.price,
                          priceLabel: 'Penawaran Helper',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Penawaranmu sudah terkirim. Pekerjaan belum aktif sebelum '
                  '$client menyetujuinya.',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: HelperBottomBar(
        children: [
          HelperButton(
            label: 'Lihat status penawaran',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Kotak harga besar bergaris merah: "Rp 100.000" dan ikon pensil.
class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.focus,
    this.error,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.style(
      size: 22,
      weight: AppTypography.bold,
      color: HelperStyle.ink,
    );
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: 1.5),
    );

    return TextField(
      controller: controller,
      focusNode: focus,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
        _ThousandsFormatter(),
      ],
      style: style,
      decoration: InputDecoration(
        errorText: error,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Text(
            'Rp',
            style: style.copyWith(
              fontSize: 14,
              fontWeight: AppTypography.regular,
              color: HelperStyle.muted,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        suffixIcon: IconButton(
          tooltip: 'Ubah harga',
          onPressed: focus.requestFocus,
          icon: const OrderIcon(HelperStyle.iconPencil, size: 16),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: border(HelperStyle.red),
        focusedBorder: border(HelperStyle.red),
        errorBorder: border(HelperStyle.red),
        focusedErrorBorder: border(HelperStyle.red),
      ),
    );
  }
}

/// Titik ribuan saat mengetik: "100000" → "100.000".
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final value = int.parse(digits);
    final text = thousands(value);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
