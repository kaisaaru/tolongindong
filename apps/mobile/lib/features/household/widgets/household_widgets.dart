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
    this.darkText = false,
    this.trailing,
    this.decoration,
  });

  /// Header untuk satu layanan, dengan warna dan warna teksnya.
  ColoredHeader.of(
    HouseholdService service, {
    Key? key,
    String? title,
    Widget? trailing,
  }) : this(
         key: key,
         title: title ?? service.label,
         color: service.headerColor,
         darkText: service.headerDarkText,
         trailing: trailing,
       );

  final String title;
  final Color color;

  /// True untuk header berwarna muda (Pakaian): judul dan ikon status bar
  /// gelap, bukan putih.
  final bool darkText;
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
      value: darkText ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
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
                        color: darkText
                            ? AppColors.textPrimary
                            : AppColors.light,
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

/// Tombol chat bulat pink: menghubungi helper pesanan yang berjalan.
class ChatHelperButton extends StatelessWidget {
  const ChatHelperButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // container: tetap tombol tersendiri, tidak melebur ke kartu helper.
    return Semantics(
      container: true,
      button: true,
      label: 'Chat helper',
      excludeSemantics: true,
      child: Material(
        color: AppColors.primaryLight,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox.square(
            dimension: 40,
            child: Center(
              child: OrderIcon(
                OrderStyle.iconChat,
                size: 18,
                color: AppColors.primary,
              ),
            ),
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

/// Dua isian sama lebar yang berdampingan, seperti desain. Di layar sangat
/// sempit (320 dp) keduanya ditumpuk: berdampingan, teks seperti "Alat
/// Tidak Disediakan" harus mengecil sampai sulit dibaca.
class SideBySide extends StatelessWidget {
  const SideBySide({
    super.key,
    required this.children,
    this.gap = 12,
    this.stackBelow = 290,
  });

  final List<Widget> children;
  final double gap;

  /// Lebar minimal agar tetap berdampingan. Di 360 dp lebar form ±297 dp.
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Jarak kiri-kanan form pesanan: 36 dp di desain, menyempit seimbang di
/// layar yang lebih kecil.
double formSideInset(BuildContext context) => OrderStyle.inset(context, 36);

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

/// "Waktu Pengerjaan": Sekarang, atau Terjadwal yang membuka pemilih jadwal.
class WorkTimeCards extends StatelessWidget {
  const WorkTimeCards({
    super.key,
    required this.slot,
    required this.chosen,
    required this.onNow,
    required this.onSchedule,
  });

  /// Null + [chosen] true = "Sekarang".
  final TimeSlot? slot;
  final bool chosen;
  final VoidCallback onNow;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final slot = this.slot;

    // stretch: kartu selebar form, bukan selebar teksnya.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectCard(
          title: 'Sekarang',
          subtitle: 'Helper akan datang paling lama 1 jam',
          selected: chosen && slot == null,
          onTap: onNow,
        ),
        const SizedBox(height: 10),
        SelectCard(
          title: 'Terjadwal',
          subtitle: slot == null
              ? 'Helper akan datang sesuai jadwal yang ditentukan'
              : 'Jadwal pengerjaan: ${dateLabel(slot.day)} - '
                    '${slot.hourLabel}',
          selected: slot != null,
          onTap: onSchedule,
        ),
      ],
    );
  }
}

/// "Estimasi Muatan": pilihan radio dalam satu kotak. Pilihan yang tidak
/// terpilih berteks abu-abu, seperti komponen "Muatan / Radio".
class LoadRadioGroup extends StatelessWidget {
  const LoadRadioGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<LoadOption> options;
  final LoadOption? selected;
  final ValueChanged<LoadOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedBox(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final load in options)
            _LoadRadio(
              load: load,
              selected: load == selected,
              onTap: () => onSelected(load),
            ),
        ],
      ),
    );
  }
}

class _LoadRadio extends StatelessWidget {
  const _LoadRadio({
    required this.load,
    required this.selected,
    required this.onTap,
  });

  final LoadOption load;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                child: selected
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(dimension: 8),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${load.label} (${load.detail}) + ${rupiah(load.fee)}',
                  style: AppTypography.style(
                    size: 13,
                    weight: AppTypography.regular,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    height: 1.4,
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

/// Isian alamat di form: ikon lokasi lalu alamat terpilih atau petunjuk.
class AddressField extends StatelessWidget {
  const AddressField({
    super.key,
    required this.address,
    required this.hint,
    required this.onTap,
    this.icon = OrderStyle.iconLocationPin,
  });

  final SavedAddress? address;
  final String hint;
  final VoidCallback onTap;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final value = address;

    return OutlinedBox(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          OrderIcon(icon, size: 15),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value?.fullAddress ?? hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                size: 12,
                weight: value == null
                    ? AppTypography.regular
                    : AppTypography.medium,
                color: value == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Isian "Pilih Helper" di form: avatar kosong sampai helper dipilih.
class HelperPickerField extends StatelessWidget {
  const HelperPickerField({
    super.key,
    required this.helper,
    required this.onTap,
  });

  final HourlyHelper? helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = helper;

    return OutlinedBox(
      onTap: onTap,
      // Tinggi kartu 62 dp sesuai desain: avatar 44 + padding 9.
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Row(
        children: [
          if (value == null)
            const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFE0E0E0),
              child: Icon(
                Icons.person_outline_rounded,
                color: AppColors.light,
                size: 24,
              ),
            )
          else
            HelperAvatar(name: value.name, photoUrl: value.photoUrl, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value?.name ?? 'Helper',
                  style: AppTypography.style(
                    size: value == null ? 13 : 10,
                    weight: AppTypography.regular,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value == null
                      ? 'Pilih helper disini'
                      : '${rupiah(value.hourlyRate)}/Jam',
                  style: AppTypography.style(
                    size: value == null ? 9 : 13,
                    weight: value == null
                        ? AppTypography.regular
                        : AppTypography.semiBold,
                    color: value == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
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
      child: LayoutBuilder(
        builder: (context, box) => Row(
          // Label selebar teksnya, nilai mengisi sisanya dan rata kanan
          // seperti desain. Nilai panjang (nama helper) turun baris, bukan
          // meluap. Label dibatasi 60% lebar: di layar 360 dp dengan teks
          // diperbesar, "Ketersediaan alat:" bisa lebih lebar dari kotaknya.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
              child: Text(label, style: style),
            ),
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
      ),
    );
  }
}

/// Ikon jenis alamat tersimpan: rumah, kantor, atau lainnya.
class AddressKindIcon extends StatelessWidget {
  const AddressKindIcon(this.kind, {super.key, this.size = 22});

  final AddressKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      // Ikon target di desain belum diekspor; ikon Material yang mirip,
      // dengan merah tua yang sama seperti ikon riwayat.
      AddressKind.current => Icon(
        Icons.my_location_rounded,
        size: size,
        color: const Color(0xFF9A1919),
      ),
      AddressKind.home => OrderIcon(OrderStyle.iconAddressHome, size: size),
      AddressKind.office => OrderIcon(OrderStyle.iconAddressOffice, size: size),
      AddressKind.recent => OrderIcon(OrderStyle.iconAddressRecent, size: size),
    };
  }
}

/// Alamat pesanan: ikon, judul (default label alamat), dan alamat lengkap.
class AddressBox extends StatelessWidget {
  const AddressBox({
    super.key,
    required this.address,
    this.onTap,
    this.title,
    this.icon = OrderStyle.iconLocationPin,
    this.maxLines,
  });

  final SavedAddress address;
  final VoidCallback? onTap;

  /// Misal "Lokasi awal" di Pindahan.
  final String? title;
  final String icon;

  /// Pindahan menampilkan alamat satu baris saja, seperti desain.
  final int? maxLines;

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
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: OrderIcon(icon, size: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? address.label,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.semiBold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  address.fullAddress,
                  maxLines: maxLines,
                  overflow: maxLines == null ? null : TextOverflow.ellipsis,
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

/// Bagian "Alamat" di Detail Pesanan dan pesanan aktif. Pindahan punya dua
/// kotak: lokasi awal dan lokasi tujuan.
List<Widget> orderAddressBoxes(
  HouseholdOrderDraft draft, {
  VoidCallback? onTapOrigin,
  VoidCallback? onTapDestination,
}) {
  final destination = draft.destination;
  if (destination == null) {
    return [AddressBox(address: draft.address, onTap: onTapOrigin)];
  }
  return [
    AddressBox(
      address: draft.address,
      title: 'Lokasi awal',
      icon: OrderStyle.iconLocationOrigin,
      maxLines: 1,
      onTap: onTapOrigin,
    ),
    const SizedBox(height: 10),
    AddressBox(
      address: destination,
      title: 'Lokasi tujuan',
      maxLines: 1,
      onTap: onTapDestination,
    ),
  ];
}

/// Baris "Detail Pengerjaan" untuk satu pesanan.
List<Widget> workDetailRows(HouseholdOrderDraft draft) => [
  // Desain Pindahan dan Pakaian menulis "Ukuran rumah: ..." (salin dari
  // frame Rumah); yang sebenarnya diisi di form adalah estimasi muatan.
  if (draft.load case final load?) InfoRow('Muatan:', load.label),
  if (draft.isMove)
    InfoRow('Kebutuhan Armada:', draft.fleet?.label ?? '-')
  else ...[
    if (draft.widthM != null)
      InfoRow(
        // Desain: "Ukuran rumah:" — hanya huruf pertama kapital.
        '${draft.service.sizeLabel[0]}'
            '${draft.service.sizeLabel.substring(1).toLowerCase()}:',
        'L: ${meterLabel(draft.widthM!)} m, '
            'P: ${meterLabel(draft.lengthM ?? 0)} m',
      ),
    InfoRow('Ketersediaan alat:', draft.tools?.label ?? '-'),
  ],
  InfoRow('Waktu pengerjaan:', draft.timeLabel),
  InfoRow('Helper :', draft.helper.name),
  // Desain Pindahan tidak punya baris durasi.
  if (!draft.isMove) InfoRow('Durasi :', '${draft.hours} Jam'),
  InfoRow('Catatan tambahan :', draft.note ?? '-'),
];

/// Tombol di dialog pesanan. [outlined]: latar putih, garis dan teks
/// [color] ("Tambah" di dialog waktu habis); selain itu latar [color], teks
/// putih.
class DialogButton extends StatelessWidget {
  const DialogButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: outlined ? BorderSide(color: color) : BorderSide.none,
    );

    return Material(
      color: outlined ? AppColors.light : color,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Center(
            child: Text(
              label,
              style: AppTypography.style(
                size: 13,
                weight: AppTypography.medium,
                color: outlined ? color : AppColors.light,
              ),
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
