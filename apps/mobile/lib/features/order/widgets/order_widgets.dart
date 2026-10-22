import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          child: SizedBox.square(
            dimension: size,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Baris judul halaman putih: panah kembali lalu judul tebal. Pusat panah
/// [OrderStyle.backCenter] di bawah status bar, sama seperti tombol kotak di
/// halaman lain. Dipasang di dalam SafeArea.
class ArrowTitleBar extends StatelessWidget {
  const ArrowTitleBar(this.title, {super.key, this.leading});

  final String title;

  /// Pengganti judul teks, misal kolom pencarian alamat.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // IconButton setinggi 48, jadi pusatnya 24 dari tepi atasnya.
      padding: const EdgeInsets.fromLTRB(8, OrderStyle.backCenter - 24, 22, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                leading ??
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    size: 20,
                    weight: AppTypography.bold,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Baris judul dengan tombol kotak putih: dipakai halaman berlatar pink
/// (Personal, Daftar Helper) dan Checkout. Dipasang di dalam SafeArea.
class SquareTitleBar extends StatelessWidget {
  const SquareTitleBar(
    this.title, {
    super.key,
    this.shadow = false,
    this.trailing,
  });

  /// Null berarti hanya tombol kembali (Checkout).
  final String? title;

  /// Bayangan tipis untuk tombol di atas latar putih.
  final bool shadow;

  /// Di ujung kanan, misal tombol bantuan.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final button = SquareIconButton.back(context, size: OrderStyle.backSize);
    final text = title;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        22,
        OrderStyle.backCenter - OrderStyle.backSize / 2,
        22,
        0,
      ),
      child: Row(
        children: [
          if (shadow)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: OrderStyle.shadow,
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: button,
            )
          else
            button,
          if (text != null) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  size: OrderStyle.pageTitleSize,
                  weight: AppTypography.semiBold,
                ),
              ),
            ),
          ] else if (trailing != null)
            const Spacer(),
          ?trailing,
        ],
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
  const StarRow({
    super.key,
    required this.rating,
    this.size = 16,
    this.gap = 3,
  });

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

/// Nama helper (tebal) dan harganya di kartu daftar helper. Nama dipotong
/// kalau kepanjangan, harga selalu utuh. Kalau keduanya tidak muat sebaris
/// (layar 320 dp, font HP diperbesar), harga turun ke baris berikutnya.
class NamePriceLine extends StatelessWidget {
  const NamePriceLine({super.key, required this.name, required this.price});

  final String name;
  final String price;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final nameText = Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.style(
            size: 12,
            weight: AppTypography.semiBold,
            height: 1.5,
          ),
        );
        final priceText = Text(
          price,
          maxLines: 1,
          style: AppTypography.style(
            size: 12,
            weight: AppTypography.regular,
            height: 1.5,
          ),
        );

        // Nama minimal ±40% baris; kurang dari itu harga pindah ke bawah.
        final painter = TextPainter(
          text: TextSpan(text: price, style: priceText.style),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final fits = painter.width + 8 <= box.maxWidth * 0.6;
        painter.dispose();

        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [nameText, priceText],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: nameText),
            const SizedBox(width: 8),
            priceText,
          ],
        );
      },
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
        children: [
          icon,
          const SizedBox(width: 6),
          // Flexible: di layar sempit dengan font besar, teks dipotong
          // alih-alih meluap keluar pil.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
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
    this.enabled = true,
  });

  final String caption;
  final String amount;
  final Widget button;

  /// False saat form belum lengkap: teks total ikut pudar seperti desain.
  final bool enabled;

  static const _buttonWidth = 210.0;

  /// Lebar isi bilah di frame desain: 412 dikurangi padding 24 + 22.
  static const _designContentWidth = 366.0;

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
          child: LayoutBuilder(
            builder: (context, box) {
              // Di desain (412 dp) tombol 210 dari 366 dp lebar isi. Di layar
              // lebih sempit tombol menyusut dengan rasio yang sama, supaya
              // harga seperti "Rp 200.000" tetap satu baris.
              final buttonWidth = math.min(
                _buttonWidth,
                box.maxWidth * _buttonWidth / _designContentWidth,
              );

              return Row(
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
                            color: enabled
                                ? AppColors.textPrimary
                                : AppColors.disabled,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Tetap satu baris; kalau masih kepanjangan (font HP
                        // diperbesar), teks mengecil alih-alih turun baris.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            amount,
                            maxLines: 1,
                            style: AppTypography.style(
                              size: 20,
                              weight: AppTypography.bold,
                              color: enabled
                                  ? AppColors.textPrimary
                                  : AppColors.disabled,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: buttonWidth, child: button),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Halaman pesanan yang pesanannya sudah ditutup dari tempat lain
/// (dibatalkan, dinilai, selesai). Tetap ada jalan kembali, bukan layar
/// kosong tanpa tombol.
class OrderEndedView extends StatelessWidget {
  const OrderEndedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            children: [
              const ArrowTitleBar(''),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Pesanan ini sudah selesai.\nLihat riwayatnya di Aktifitas.',
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        size: AppTypography.small,
                        weight: AppTypography.regular,
                        color: AppColors.textDescription,
                        height: 1.5,
                      ),
                    ),
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

/// Status pesanan yang sedang berjalan: ikon merah, status tebal, dan
/// keterangan (misal jam pesan). Dipakai halaman pesanan Personal dan
/// Delivery, yang tidak punya hitung mundur seperti Household.
class OrderStatusBanner extends StatelessWidget {
  const OrderStatusBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: OrderStyle.tagBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.light),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.style(
                    size: 13,
                    weight: AppTypography.semiBold,
                    height: 1.4,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.regular,
                    color: AppColors.textDescription,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
