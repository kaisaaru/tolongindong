import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../order/widgets/order_widgets.dart';

/// Ukuran dan warna menu Profil Saya, diukur dari desain (frame 412 dp).
abstract final class AccountStyle {
  /// Jarak isi dari tepi layar.
  static const side = 20.0;

  /// Teks dan ikon gelap (slate 800 di desain).
  static const ink = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFEEF2F6);
  static const danger = Color(0xFFFF4D4D);

  static const iconUser = 'assets/icons/account/user.svg';
  static const iconLocation = 'assets/icons/account/location.svg';
  static const iconShield = 'assets/icons/account/shield.svg';
  static const iconBriefcase = 'assets/icons/account/briefcase.svg';
  static const iconTicket = 'assets/icons/account/ticket.svg';
  static const iconBell = 'assets/icons/account/bell.svg';
  static const iconHelp = 'assets/icons/account/help.svg';
  static const iconLogout = 'assets/icons/account/logout.svg';
  static const iconVerified = 'assets/icons/account/verified.svg';
}

/// Judul bagian, misal "Akun & Keamanan".
class AccountSectionTitle extends StatelessWidget {
  const AccountSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: AppTypography.style(
          size: 16,
          weight: AppTypography.semiBold,
          color: AccountStyle.ink,
        ),
      ),
    );
  }
}

/// Kartu bergaris berisi beberapa [AccountMenuRow], dipisah garis tipis.
class AccountMenuCard extends StatelessWidget {
  const AccountMenuCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountStyle.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AccountStyle.divider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Satu menu: ikon dalam lingkaran berwarna, label, lencana opsional,
/// keterangan di kanan, lalu panah.
class AccountMenuRow extends StatelessWidget {
  const AccountMenuRow({
    super.key,
    required this.label,
    required this.tint,
    required this.onTap,
    this.asset,
    this.icon,
    this.badge,
    this.trailing,
    this.color = AccountStyle.ink,
    this.showChevron = true,
  }) : assert(asset != null || icon != null);

  final String label;

  /// Ikon SVG dari desain; [icon] untuk menu yang belum punya aset.
  final String? asset;
  final IconData? icon;

  /// Warna lingkaran ikon.
  final Color tint;
  final VoidCallback onTap;

  /// Lencana kecil setelah label, misal "Baru".
  final String? badge;

  /// Keterangan di kanan, misal saldo.
  final String? trailing;

  /// Warna label (merah untuk Keluar Akun).
  final Color color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    final badge = this.badge;
    final trailing = this.trailing;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 7, 16, 7),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: asset != null
                  ? OrderIcon(asset, size: 15)
                  : Icon(icon, size: 16, color: AccountStyle.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        size: 12,
                        weight: AppTypography.medium,
                        color: color,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    _Badge(badge),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  trailing,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.medium,
                    color: AccountStyle.muted,
                  ),
                ),
              ),
            if (showChevron)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AccountStyle.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTypography.style(
          size: 8,
          weight: AppTypography.medium,
          color: AccountStyle.danger,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Baris judul Profil Saya: tombol kembali kotak bergaris, judul, lalu
/// garis pemisah selebar layar.
class AccountTitleBar extends StatelessWidget {
  const AccountTitleBar(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AccountStyle.side, 16, 20, 12),
          child: Row(
            children: [
              // Di depan: tombolnya sendiri berlatar putih penuh.
              DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AccountStyle.border),
                ),
                child: SquareIconButton.back(context, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    size: 20,
                    weight: AppTypography.semiBold,
                    color: AccountStyle.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AccountStyle.border),
      ],
    );
  }
}
