import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/format/rupiah.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../order/order_style.dart';
import '../../order/widgets/order_widgets.dart';
import '../household_models.dart';

/// Kotak pilihan bergaris. Terpilih: latar pink pucat dan garis merah.
const selectedFill = Color(0xFFFFF5F5);
const cardBorder = Color(0xFFDDDDDD);

/// Header berwarna dengan tombol kembali, judul, dan aksi opsional.
///
/// Ukuran diukur dari desain Rumah dan Household (frame Android Compact
/// 412 dp, status bar 52 dp): header berakhir 95 dp di bawah status bar,
/// dan pusat tombol kembali 33 dp di bawahnya. Dihitung dari tepi bawah
/// status bar perangkat, jadi di iPhone dengan status bar tinggi
/// proporsinya tetap sama.
class ColoredHeader extends StatelessWidget {
  const ColoredHeader({
    super.key,
    required this.title,
    required this.color,
    this.trailing,
    this.decoration,
  });

  final String title;
  final Color color;
  final Widget? trailing;

  /// Hiasan di sisi kanan, misal ilustrasi sapu.
  final Widget? decoration;

  static const _height = 95.0; // di bawah status bar
  static const _buttonSize = 34.0;
  static const _buttonCenter = 33.0; // dari tepi bawah status bar

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        height: top + _height,
        color: color,
        child: Stack(
          children: [
            if (decoration != null)
              Positioned(right: 22, bottom: 10, child: decoration!),
            Positioned(
              top: top + _buttonCenter - _buttonSize / 2,
              left: 22,
              right: 22,
              height: _buttonSize,
              child: Row(
                children: [
                  SquareIconButton.back(context, size: _buttonSize),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        size: 24,
                        weight: AppTypography.semiBold,
                        color: AppColors.light,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol bantuan bulat putih di header pesanan aktif.
class SupportButton extends StatelessWidget {
  const SupportButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.light,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox.square(
          dimension: 30,
          child: Icon(
            Icons.headset_mic_outlined,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.style(size: 14, weight: AppTypography.semiBold),
    );
  }
}

/// Kartu pilihan: satu judul, keterangan opsional.
class SelectCard extends StatelessWidget {
  const SelectCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool centered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedFill : AppColors.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? AppColors.primary : cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            // Tinggi sesuai desain: tanpa keterangan 36 dp, dengan
            // keterangan 60 dp.
            padding: EdgeInsets.symmetric(
              horizontal: centered ? 8 : 20,
              vertical: sub == null ? 9 : 14,
            ),
            child: Column(
              crossAxisAlignment: centered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                // Tombol berdampingan (versi centered) dikunci satu baris
                // dan mengecil sendiri, supaya tingginya tetap sama.
                // "Alat Tidak Disediakan" pecah 2 baris di iPhone 390 dp.
                if (centered)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: AppTypography.style(
                        size: 13,
                        weight: AppTypography.regular,
                        height: 1.4,
                      ),
                    ),
                  )
                else
                  Text(
                    title,
                    style: AppTypography.style(
                      size: 13,
                      weight: AppTypography.regular,
                      height: 1.4,
                    ),
                  ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: AppTypography.style(
                      size: 9,
                      weight: AppTypography.regular,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilihan durasi 1–5 jam: satu baris kotak sama lebar, dengan gaya yang
/// sama seperti tombol "Alat Disediakan" ([SelectCard]) supaya form seragam.
/// Selalu satu baris; teks mengecil sendiri di layar sangat sempit.
class DurationChips extends StatelessWidget {
  const DurationChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<int> options;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: SelectCard(
              title: '${options[i]} Jam',
              centered: true,
              selected: options[i] == selected,
              onTap: () => onSelected(options[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// Kotak bergaris tipis berisi baris-baris label–nilai.
class OutlinedBox extends StatelessWidget {
  const OutlinedBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.light,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(
    this.label,
    this.value, {
    super.key,
    this.muted = false,
    this.bold = false,
  });

  final String label;
  final String value;

  /// Abu-abu, untuk baris rincian harga.
  final bool muted;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppColors.textSecondary : AppColors.textPrimary;
    // 12 dp, diukur dari desain Detail Pesanan; baris setinggi 26 dp.
    final style = AppTypography.style(
      size: 12,
      weight: bold ? AppTypography.semiBold : AppTypography.regular,
      color: color,
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        // Label selebar teksnya (selalu pendek dan tetap), nilai mengisi
        // sisanya dan rata kanan seperti desain. Nilai panjang (nama helper)
        // turun baris, bukan meluap.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: style),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: style.copyWith(
                fontWeight: bold || !muted
                    ? AppTypography.semiBold
                    : AppTypography.regular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alamat pesanan: ikon pin, label, dan alamat lengkap.
class AddressBox extends StatelessWidget {
  const AddressBox({super.key, required this.address, this.onTap});

  final SavedAddress address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Ukuran dari desain Detail Pesanan: pin 12 dp di 11 dp dari tepi,
    // label 12 dp sesudah pin, alamat 10 dp di bawah label.
    return OutlinedBox(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(11, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: OrderIcon(OrderStyle.iconLocationPin, size: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.label,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.semiBold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  address.fullAddress,
                  style: AppTypography.style(
                    size: 10,
                    weight: AppTypography.regular,
                    color: AppColors.textDescription,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }
}

/// Baris "Detail Pengerjaan" untuk satu pesanan.
List<Widget> workDetailRows(HouseholdOrderDraft draft, {int? totalHours}) => [
  InfoRow(
    // Desain: "Ukuran rumah:" — hanya huruf pertama kapital.
    '${draft.service.sizeLabel[0]}'
        '${draft.service.sizeLabel.substring(1).toLowerCase()}:',
    'L: ${meterLabel(draft.widthM)} m, P: ${meterLabel(draft.lengthM)} m',
  ),
  InfoRow('Ketersediaan alat:', draft.tools?.label ?? '-'),
  InfoRow('Waktu pengerjaan:', draft.timeLabel),
  InfoRow('Helper :', draft.helper.name),
  InfoRow('Durasi :', '${totalHours ?? draft.hours} Jam'),
  InfoRow('Catatan tambahan :', draft.note ?? '-'),
];

/// Baris "Rincian harga": satu baris per blok durasi, potongan, total.
List<Widget> priceRows(PriceBreakdown price) => [
  InfoRow(
    'Biaya helper x ${price.baseHours} jam',
    rupiah(price.baseCost),
    muted: true,
  ),
  for (final hours in price.extraHours)
    InfoRow(
      'Biaya helper x $hours jam',
      rupiah(hours * price.hourlyRate),
      muted: true,
    ),
  if (price.discount > 0)
    InfoRow('Potongan vocher', rupiah(-price.discount), muted: true),
  InfoRow('Total', rupiah(price.total, spaced: false), bold: true),
];

/// Bilah bawah pesanan aktif: helper dan jam penting (tiba/selesai).
class HelperFooter extends StatelessWidget {
  const HelperFooter({
    super.key,
    required this.helper,
    required this.caption,
    required this.time,
    this.onTap,
  });

  final HourlyHelper helper;
  final String caption;
  final String time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.light,
      child: InkWell(
        onTap: onTap,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 26, 16),
            child: Row(
              children: [
                HelperAvatar(
                  name: helper.name,
                  photoUrl: helper.photoUrl,
                  size: 46,
                ),
                const SizedBox(width: 14),
                // mainAxisSize.min: bilah ini dipasang sebagai
                // bottomNavigationBar, tanpa itu tingginya memenuhi layar.
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        helper.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.medium,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StarRow(rating: helper.rating, size: 12, gap: 1),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      caption,
                      style: AppTypography.style(
                        size: 11,
                        weight: AppTypography.regular,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: AppTypography.style(
                        size: 18,
                        weight: AppTypography.semiBold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dua potongan cincin merah bergradasi (aset Figma) di latar halaman
/// Detail Pesanan. Halaman rating punya cincinnya sendiri.
class RingBackground extends StatelessWidget {
  const RingBackground({super.key, required this.child});

  final Widget child;

  /// Posisi di desain (frame 412 dp, status bar 52 dp), dari atas layar.
  /// Ukuran SVG = ukuran di Figma, jadi dipasang apa adanya.
  static const _designStatusBar = 52.0;
  static const _leftTop = 236.0;
  static const _rightTop = 270.0;

  @override
  Widget build(BuildContext context) {
    // Digeser mengikuti tinggi status bar perangkat, supaya posisinya
    // terhadap konten sama dengan desain.
    final shift = MediaQuery.paddingOf(context).top - _designStatusBar;

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: _leftTop + shift,
          child: SvgPicture.asset(OrderStyle.ringLeft),
        ),
        Positioned(
          right: 0,
          top: _rightTop + shift,
          child: SvgPicture.asset(OrderStyle.ringRight),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
