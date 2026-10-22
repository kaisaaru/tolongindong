import 'package:flutter/material.dart';

import '../../core/format/rupiah.dart';
import '../../models/auth_user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../home/widgets/tips_section.dart';
import '../order/widgets/order_widgets.dart';

/// Isi tab "Akun": profil, saldo TD-Wallet, status verifikasi, pintasan
/// pesanan dan obrolan, bantuan, dan keluar.
///
/// Desain Akun belum ada; tata letaknya mengikuti tab Aktifitas (judul 24,
/// kartu bergaris 24 dp dari tepi). Data dari `GET /me` yang sudah dimuat
/// beranda.
class AccountView extends StatelessWidget {
  const AccountView({
    super.key,
    required this.user,
    required this.onLogout,
    this.onOpenOrders,
    this.onOpenChats,
  });

  final AuthUser user;

  /// Dipanggil setelah pengguna mengonfirmasi keluar.
  final VoidCallback onLogout;

  /// Pindah ke tab Aktifitas dan Obrolan. Null: barisnya tidak tampil.
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenChats;

  Future<void> _confirmLogout(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu masuk lagi untuk memesan helper.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (sure == true) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = user.wallet;
    final phone = user.phoneNumber;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Text(
            'Akun',
            style: AppTypography.style(
              size: 24,
              weight: AppTypography.semiBold,
            ),
          ),
          const SizedBox(height: 22),
          _Card(
            child: Row(
              children: [
                HelperAvatar(
                  name: user.fullName,
                  photoUrl: user.photoUrl,
                  size: 56,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          size: 16,
                          weight: AppTypography.semiBold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _Detail(user.email),
                      if (phone != null && phone.isNotEmpty) _Detail(phone),
                      const SizedBox(height: 8),
                      _VerificationChip(user.verificationStatus),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo TD-Wallet',
                        style: AppTypography.style(
                          size: 12,
                          weight: AppTypography.regular,
                          color: AppColors.textDescription,
                          height: 1.4,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          rupiah(wallet.availableBalance),
                          style: AppTypography.style(
                            size: 20,
                            weight: AppTypography.bold,
                            height: 1.4,
                          ),
                        ),
                      ),
                      // Saldo yang ditahan untuk pesanan berjalan (escrow).
                      if (wallet.heldBalance > 0)
                        _Detail('Ditahan ${rupiah(wallet.heldBalance)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onOpenOrders != null || onOpenChats != null) ...[
            const SizedBox(height: 14),
            _Card(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (onOpenOrders case final open?)
                    _MenuRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Pesanan saya',
                      onTap: open,
                    ),
                  if (onOpenChats case final open?)
                    _MenuRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Obrolan',
                      onTap: open,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'Bantuan',
            style: AppTypography.style(
              size: 14,
              weight: AppTypography.semiBold,
            ),
          ),
          const SizedBox(height: 10),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final tip in AppTip.all)
                  _MenuRow(
                    icon: tip.icon,
                    label: tip.title,
                    onTap: () => showTipSheet(context, tip),
                  ),
                _MenuRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Tentang TolonginDong',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'TolonginDong',
                    applicationVersion: '1.0.0',
                    applicationLegalese:
                        'Bantuan helper terverifikasi untuk tugas harianmu.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

/// Kartu bergaris seperti kartu di tab Aktifitas.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: child,
    );
  }
}

/// Satu baris menu: ikon, label, panah.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.style(
                  size: 13,
                  weight: AppTypography.medium,
                  height: 1.4,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.style(
        size: 12,
        weight: AppTypography.regular,
        color: AppColors.textDescription,
        height: 1.5,
      ),
    );
  }
}

/// Status verifikasi identitas (FR-VER-003): hijau kalau sudah, kuning
/// saat menunggu admin, merah kalau ditolak.
class _VerificationChip extends StatelessWidget {
  const _VerificationChip(this.status);

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      VerificationStatus.verified => ('Terverifikasi', AppColors.success),
      VerificationStatus.pending => ('Menunggu verifikasi', AppColors.warning),
      VerificationStatus.rejected => ('Verifikasi ditolak', AppColors.error),
      VerificationStatus.unverified => (
        'Belum verifikasi',
        AppColors.textSecondary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          size: 10,
          weight: AppTypography.semiBold,
          color: color,
          height: 1.5,
        ),
      ),
    );
  }
}
