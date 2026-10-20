import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../order_style.dart';

/// Tombol kotak putih bersudut membulat, dipakai untuk kembali, chat, dan
/// favorit di halaman pesanan.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.label,
    this.size = 40,
  });

  /// Tombol kembali dengan ikon chevron.
  factory SquareIconButton.back(BuildContext context, {double size = 40}) =>
      SquareIconButton(
        label: 'Kembali',
        size: size,
        onTap: () => Navigator.of(context).maybePop(),
        child: const Icon(
          Icons.chevron_left_rounded,
          size: 28,
          color: AppColors.textPrimary,
        ),
      );

  final Widget child;
  final VoidCallback onTap;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(8),
        elevation: 0,
        shadowColor: OrderStyle.shadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(dimension: size, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Ikon SVG satu warna. Ikon ekspor Figma berwarna hitam, jadi bisa
/// diwarnai ulang lewat [color].
class OrderIcon extends StatelessWidget {
  const OrderIcon(this.asset, {super.key, this.size = 16, this.color});

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: c == null ? null : ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}

/// Foto helper dalam lingkaran. Tanpa foto, atau foto gagal dimuat,
/// tampil huruf awal nama.
class HelperAvatar extends StatelessWidget {
  const HelperAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 64,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final initial = _Initial(name: name, size: size);

    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initial,
              )
            : initial,
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return ColoredBox(
      color: AppColors.primaryLight,
      child: Center(
        child: Text(
          trimmed.isEmpty ? '?' : trimmed[0].toUpperCase(),
          style: AppTypography.style(
            size: size * 0.38,
            weight: AppTypography.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Deretan lima bintang merah. Bintang di atas [rating] dibuat pudar.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 16, this.gap = 3});

  final double rating;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Opacity(
            // Rating 4,5 dibulatkan ke bintang penuh, sama seperti desain.
            opacity: i < rating.round() ? 1 : 0.25,
            child: OrderIcon(OrderStyle.iconStar, size: size),
          ),
        ],
      ],
    );
  }
}

/// Label kecil keahlian helper.
class TagChip extends StatelessWidget {
  const TagChip(
    this.label, {
    super.key,
    this.background = OrderStyle.tagBackground,
    this.foreground = AppColors.primary,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  /// Versi besar untuk bagian "Jasa" di halaman detail.
  const TagChip.skill(this.label, {super.key})
      : background = OrderStyle.skillBackground,
        foreground = AppColors.light,
        fontSize = 13,
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 3);

  final String label;
  final Color background;
  final Color foreground;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          size: fontSize,
          weight: AppTypography.regular,
          color: foreground,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Rating dan jumlah tugas selesai, dipakai di detail helper dan checkout.
/// [pill] true memberi latar putih bulat untuk header merah.
class HelperStats extends StatelessWidget {
  const HelperStats({
    super.key,
    required this.rating,
    required this.completedCount,
    this.pill = false,
  });

  final double rating;
  final int completedCount;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      height: 1.5,
    );

    Widget item(Widget icon, String text) {
      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(width: 6), Text(text, style: style)],
      );
      if (!pill) return content;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.light,
          borderRadius: BorderRadius.circular(20),
        ),
        child: content,
      );
    }

    return Wrap(
      spacing: pill ? 8 : 22,
      runSpacing: 6,
      children: [
        item(
          const OrderIcon(OrderStyle.iconStar, size: 12),
          rating.toStringAsFixed(1),
        ),
        item(
          const OrderIcon(
            OrderStyle.iconClipboard,
            size: 11,
            color: AppColors.textPrimary,
          ),
          '$completedCount Tugas selesai',
        ),
      ],
    );
  }
}

/// Bilah bawah berisi ringkasan harga dan tombol aksi.
class OrderBottomBar extends StatelessWidget {
  const OrderBottomBar({
    super.key,
    required this.caption,
    required this.amount,
    required this.button,
  });

  final String caption;
  final String amount;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.light,
        border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 22, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: AppTypography.style(
                        size: AppTypography.small,
                        weight: AppTypography.regular,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount,
                      style: AppTypography.style(
                        size: 19,
                        weight: AppTypography.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 210, child: button),
            ],
          ),
        ),
      ),
    );
  }
}
