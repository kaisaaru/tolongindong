import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/rupiah.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../household/household_models.dart';
import '../../order/order_repository.dart';
import '../../order/widgets/order_widgets.dart';

/// Warna dan ikon mode Helper, diukur dari desain Helper (frame 412 dp).
abstract final class HelperStyle {
  static const background = Color(0xFFFFF7F7);
  static const cardBorder = Color(0xFFF5E4E4);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const red = Color(0xFFE5383B);
  static const softRed = Color(0xFFFFEEEE);
  static const green = Color(0xFF16A34A);
  static const softGreen = Color(0xFFEAF7EF);
  static const side = 16.0;

  static const iconDelivery = 'assets/icons/helper/delivery.svg';
  static const iconPersonal = 'assets/icons/helper/personal.svg';
  static const iconHousehold = 'assets/icons/helper/household.svg';
  static const iconVerified = 'assets/icons/helper/badge_check.svg';
  static const iconUserEdit = 'assets/icons/helper/user_edit.svg';
  static const iconSliders = 'assets/icons/helper/sliders.svg';
  static const iconHourglass = 'assets/icons/helper/hourglass.svg';
  static const iconPencil = 'assets/icons/helper/pencil.svg';
  static const iconPickup = 'assets/icons/helper/pickup.svg';
  static const iconDropoff = 'assets/icons/helper/dropoff.svg';
  static const iconChat = 'assets/icons/helper/chat.svg';
  static const iconWallet = 'assets/icons/helper/wallet.svg';

  /// Ikon kategori layanan.
  static String categoryIcon(String code) => switch (code) {
    'delivery' => iconDelivery,
    'personal' => iconPersonal,
    _ => iconHousehold,
  };

  /// "Delivery", "Personal", "Household".
  static String categoryName(String code) =>
      code.isEmpty ? 'Pesanan' : '${code[0].toUpperCase()}${code.substring(1)}';

  /// Tahap pekerjaan dilihat dari helper, misal "Menuju lokasi".
  static String statusText(OrderStatus status) => switch (status) {
    _ when status.isWaiting => 'Menunggu penawaran',
    OrderStatus.accepted => 'Siap berangkat',
    OrderStatus.onTheWay => 'Menuju lokasi',
    OrderStatus.arrived => 'Tiba di lokasi',
    OrderStatus.inProgress ||
    OrderStatus.priceAdjustment => 'Sedang dikerjakan',
    OrderStatus.awaitingConfirmation => 'Menunggu konfirmasi Client',
    _ => status.label,
  };
}

/// Kapan pekerjaan yang ditandai selesai dikonfirmasi otomatis: 24 jam
/// setelahnya (FR-ORD-012). Hanya ditampilkan; backend belum menjalankan
/// konfirmasi otomatis.
DateTime? autoConfirmAt(ServerOrder job) =>
    (job.helperFinishedAt ?? job.enteredAt(OrderStatus.awaitingConfirmation))
        ?.add(const Duration(hours: 24));

/// Header merah selebar layar: panah kembali (kalau bukan isi tab), judul,
/// dan keterangan.
class HelperHeader extends StatelessWidget {
  const HelperHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.back = true,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// False untuk isi tab (Beranda, Pesanan, Chat, Profil).
  final bool back;

  /// Pengganti panah, misal foto di Beranda.
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final leading = this.leading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              back ? 4 : HelperStyle.side,
              14,
              16,
              18,
            ),
            child: Row(
              children: [
                if (back)
                  IconButton(
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.light,
                    ),
                  ),
                if (leading != null) ...[leading, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          size: 20,
                          weight: AppTypography.bold,
                          color: AppColors.light,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            size: 10,
                            weight: AppTypography.regular,
                            color: AppColors.light.withValues(alpha: 0.9),
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu putih bergaris pink tipis. Berupa [Material] supaya efek sentuh
/// baris di dalamnya (menu, pilihan) tetap terlihat.
class HelperCard extends StatelessWidget {
  const HelperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.light,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: HelperStyle.cardBorder),
      ),
      child: Padding(
        padding: padding,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

enum BannerTone { red, green, gray }

/// Kotak keterangan berwarna: judul tebal lalu penjelasan.
class HelperBanner extends StatelessWidget {
  const HelperBanner({
    super.key,
    required this.title,
    this.message,
    this.tone = BannerTone.red,
    this.trailing,
  });

  final String title;
  final String? message;
  final BannerTone tone;

  /// Di kanan judul, misal hitung mundur.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    final (background, color) = switch (tone) {
      BannerTone.red => (HelperStyle.softRed, HelperStyle.red),
      BannerTone.green => (HelperStyle.softGreen, HelperStyle.green),
      BannerTone.gray => (const Color(0xFFF1F1F1), HelperStyle.muted),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.semiBold,
                    color: color,
                    height: 1.4,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 3),
            Text(
              message,
              style: AppTypography.style(
                size: 10,
                weight: AppTypography.regular,
                color: HelperStyle.muted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lencana kategori pink kecil, misal "Delivery".
class CategoryTag extends StatelessWidget {
  const CategoryTag(this.label, {super.key, this.tone = BannerTone.red});

  final String label;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, color) = switch (tone) {
      BannerTone.red => (HelperStyle.softRed, HelperStyle.red),
      BannerTone.green => (HelperStyle.softGreen, HelperStyle.green),
      BannerTone.gray => (const Color(0xFFF1F1F1), HelperStyle.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          size: 9,
          weight: AppTypography.medium,
          color: color,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Tombol penuh mode Helper: merah ([soft] false) atau pink lembut.
class HelperButton extends StatelessWidget {
  const HelperButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.soft = false,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool soft;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final foreground = soft ? HelperStyle.red : AppColors.light;
    final background = soft ? HelperStyle.softRed : AppColors.primary;
    final icon = this.icon;

    return SizedBox(
      height: 46,
      width: double.infinity,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: enabled ? background : AppColors.disabled,
          foregroundColor: foreground,
          disabledForegroundColor: AppColors.light,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: AppTypography.style(
            size: 13,
            weight: AppTypography.semiBold,
          ),
        ),
        child: isLoading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(foreground),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 6),
                    Icon(icon, size: 16),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Bilah tombol di bawah halaman, di atas latar putih.
class HelperBottomBar extends StatelessWidget {
  const HelperBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.light,
        border: Border(top: BorderSide(color: HelperStyle.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris label kiri, nilai kanan.
class HelperRow extends StatelessWidget {
  const HelperRow(
    this.label,
    this.value, {
    super.key,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      textAlign: TextAlign.right,
      style: AppTypography.style(
        size: bold ? 15 : 11,
        weight: bold ? AppTypography.bold : AppTypography.medium,
        color: valueColor ?? HelperStyle.ink,
        height: 1.4,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // Nilai rata kanan, paling lebar 60% baris; label mengisi sisanya.
      child: LayoutBuilder(
        builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.style(
                  size: 11,
                  weight: AppTypography.regular,
                  color: HelperStyle.muted,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
              child: valueText,
            ),
          ],
        ),
      ),
    );
  }
}

/// Harga disepakati (atau penawaran), komisi 10%, dan pendapatan bersih.
class EarningBreakdown extends StatelessWidget {
  const EarningBreakdown({
    super.key,
    required this.price,
    this.priceLabel = 'Harga disepakati',
    this.netLabel = 'Estimasi pendapatan bersih',
    this.commission,
  });

  final int price;
  final String priceLabel;
  final String netLabel;

  /// Dari server kalau sudah ada; kalau belum, dihitung 10%.
  final int? commission;

  @override
  Widget build(BuildContext context) {
    final fee = commission ?? platformCommissionOf(price);
    return Column(
      children: [
        HelperRow(priceLabel, rupiah(price, spaced: false)),
        HelperRow('Komisi platform (10%)', rupiah(-fee, spaced: false)),
        const Divider(height: 18, color: HelperStyle.cardBorder),
        HelperRow(
          netLabel,
          rupiah(price - fee, spaced: false),
          bold: true,
          valueColor: HelperStyle.red,
        ),
      ],
    );
  }
}

/// "#ORD-... [Delivery]", judul, pemesan dan waktu pesan; opsional alamat
/// dan detail dari form pelanggan.
class JobSummary extends StatelessWidget {
  const JobSummary({
    super.key,
    required this.order,
    this.details = true,
    this.onChat,
  });

  final ServerOrder order;

  /// Alamat dan baris detail pesanan.
  final bool details;

  /// Tombol chat di samping pemesan.
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final parsed = order.parsed;
    final client = order.client;
    final pickup = order.pickup;
    final destination = order.destination;
    final onChat = this.onChat;
    final freeText = parsed.freeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '#${order.number}',
                style: AppTypography.style(
                  size: 10,
                  weight: AppTypography.regular,
                  color: HelperStyle.muted,
                ),
              ),
            ),
            CategoryTag(HelperStyle.categoryName(order.categoryCode)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          order.title,
          style: AppTypography.style(
            size: 14,
            weight: AppTypography.semiBold,
            color: HelperStyle.ink,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (client != null) ...[
              HelperAvatar(
                name: client.name,
                photoUrl: client.photoUrl,
                size: 32,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client?.name ?? 'Client',
                    style: AppTypography.style(
                      size: 11,
                      weight: AppTypography.semiBold,
                      color: HelperStyle.ink,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    '${dateLabel(order.createdAt)} · '
                    '${clockLabel(order.createdAt)}',
                    style: AppTypography.style(
                      size: 9,
                      weight: AppTypography.regular,
                      color: HelperStyle.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (onChat != null)
              IconButton(
                tooltip: 'Chat client',
                onPressed: onChat,
                icon: const OrderIcon(HelperStyle.iconChat, size: 20),
              ),
          ],
        ),
        if (details) ...[
          if (pickup != null || destination != null) ...[
            const Divider(height: 22, color: HelperStyle.cardBorder),
            if (pickup != null)
              _AddressLine(
                icon: HelperStyle.iconPickup,
                label: 'Titik jemput',
                address: pickup,
              ),
            if (destination != null)
              _AddressLine(
                icon: HelperStyle.iconDropoff,
                label: pickup == null ? 'Lokasi pengerjaan' : 'Titik antar',
                address: destination,
              ),
          ],
          if (parsed.rows.isNotEmpty || freeText != null) ...[
            const SizedBox(height: 4),
            for (final row in parsed.rows) HelperRow(row.label, row.value),
            if (freeText != null) HelperRow('Catatan Client', freeText),
          ],
        ],
      ],
    );
  }
}

/// Ringkasan pesanan yang menempel di atas obrolan: nomor dan tahap,
/// judul, lalu waktu pesan.
class JobChatCard extends StatelessWidget {
  const JobChatCard({super.key, required this.order});

  final ServerOrder order;

  @override
  Widget build(BuildContext context) {
    return HelperCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${order.number} · ${HelperStyle.statusText(order.status)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              size: 10,
              weight: AppTypography.semiBold,
              color: HelperStyle.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            order.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              size: 12,
              weight: AppTypography.medium,
              color: HelperStyle.ink,
              height: 1.4,
            ),
          ),
          Text(
            '${dateLabel(order.createdAt)} · ${clockLabel(order.createdAt)}',
            style: AppTypography.style(
              size: 9,
              weight: AppTypography.regular,
              color: HelperStyle.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.icon,
    required this.label,
    required this.address,
  });

  final String icon;
  final String label;
  final SavedAddress address;

  @override
  Widget build(BuildContext context) {
    final landmark = address.landmarkNote;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: OrderIcon(icon, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.style(
                    size: 8,
                    weight: AppTypography.regular,
                    color: HelperStyle.muted,
                    height: 1.4,
                  ),
                ),
                Text(
                  address.fullAddress,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.medium,
                    color: HelperStyle.ink,
                    height: 1.4,
                  ),
                ),
                if (landmark != null && landmark.isNotEmpty)
                  Text(
                    'Patokan: $landmark',
                    style: AppTypography.style(
                      size: 9,
                      weight: AppTypography.regular,
                      color: HelperStyle.muted,
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
