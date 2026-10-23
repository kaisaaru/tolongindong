import 'package:flutter/material.dart';

import '../../core/format/rupiah.dart';
import '../../models/auth_user.dart';
import '../../theme/app_typography.dart';
import '../order/widgets/order_widgets.dart';
import 'help_page.dart';
import 'saved_addresses_page.dart';
import 'widgets/account_menu.dart';

/// Tab "Akun" dengan judul "Profil Saya" (desain Profil Saya): profil,
/// lalu menu Akun & Keamanan, Layanan & Fitur, Pengaturan & Bantuan, dan
/// Keluar Akun. Data dari `GET /me` yang sudah dimuat beranda.
///
/// Desain tidak punya kartu saldo; TD-Wallet jadi satu menu di Layanan &
/// Fitur, karena hanya dari sini saldo bisa diisi.
class AccountView extends StatelessWidget {
  const AccountView({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onOpenWallet,
    required this.onChangePassword,
    required this.onOpenNotifications,
  });

  final AuthUser user;

  /// Dipanggil setelah pengguna mengonfirmasi keluar.
  final VoidCallback onLogout;

  /// Buka halaman TD-Wallet (saldo, isi saldo, mutasi).
  final VoidCallback onOpenWallet;
  final VoidCallback onChangePassword;
  final VoidCallback onOpenNotifications;

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

  /// Menu yang backend-nya belum ada.
  static void _soon(BuildContext context, String feature) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$feature belum tersedia.')));

  static void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Kembali di tab ini membawa ke Beranda (PopScope di beranda).
          const AccountTitleBar('Profil Saya'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AccountStyle.side,
                13,
                AccountStyle.side,
                24,
              ),
              children: [
                _ProfileHeader(user: user),
                const SizedBox(height: 30),
                const AccountSectionTitle('Akun & Keamanan'),
                AccountMenuCard(
                  children: [
                    AccountMenuRow(
                      asset: AccountStyle.iconUser,
                      tint: const Color(0xFFEEF2FF),
                      label: 'Edit Profil',
                      // Backend belum punya endpoint ubah profil.
                      onTap: () => _soon(context, 'Edit profil'),
                    ),
                    AccountMenuRow(
                      asset: AccountStyle.iconLocation,
                      tint: const Color(0xFFECFDF5),
                      label: 'Alamat Tersimpan',
                      onTap: () => _push(context, const SavedAddressesPage()),
                    ),
                    AccountMenuRow(
                      asset: AccountStyle.iconShield,
                      tint: const Color(0xFFEFF6FF),
                      label: 'Keamanan & Kata Sandi',
                      onTap: onChangePassword,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const AccountSectionTitle('Layanan & Fitur'),
                AccountMenuCard(
                  children: [
                    AccountMenuRow(
                      icon: Icons.account_balance_wallet_outlined,
                      tint: const Color(0xFFFFF1F1),
                      label: 'TD-Wallet',
                      trailing: rupiah(user.wallet.availableBalance),
                      onTap: onOpenWallet,
                    ),
                    AccountMenuRow(
                      asset: AccountStyle.iconBriefcase,
                      tint: const Color(0xFFFFF7ED),
                      label: 'Daftar Jadi Helper',
                      badge: 'Baru',
                      // Pendaftaran helper butuh unggah KTP dan selfie.
                      onTap: () => _soon(context, 'Daftar jadi helper'),
                    ),
                    AccountMenuRow(
                      asset: AccountStyle.iconTicket,
                      tint: const Color(0xFFFAF5FF),
                      label: 'Voucher Saya',
                      // Voucher belum bisa dipakai di pesanan.
                      onTap: () => _soon(context, 'Voucher'),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const AccountSectionTitle('Pengaturan & Bantuan'),
                AccountMenuCard(
                  children: [
                    AccountMenuRow(
                      asset: AccountStyle.iconBell,
                      tint: const Color(0xFFFEFCE8),
                      label: 'Notifikasi',
                      onTap: onOpenNotifications,
                    ),
                    AccountMenuRow(
                      asset: AccountStyle.iconHelp,
                      tint: const Color(0xFFF0F9FF),
                      label: 'Pusat Bantuan & Kebijakan',
                      onTap: () => _push(context, const HelpPage()),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AccountMenuCard(
                  children: [
                    AccountMenuRow(
                      asset: AccountStyle.iconLogout,
                      tint: const Color(0xFFFEF2F2),
                      label: 'Keluar Akun',
                      color: AccountStyle.danger,
                      showChevron: false,
                      onTap: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto 75 dp, nama, email, dan status verifikasi.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HelperAvatar(name: user.fullName, photoUrl: user.photoUrl, size: 75),
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
                  size: 18,
                  weight: AppTypography.semiBold,
                  color: AccountStyle.ink,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  size: 12,
                  weight: AppTypography.regular,
                  color: AccountStyle.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              _VerificationBadge(user.verificationStatus),
            ],
          ),
        ),
      ],
    );
  }
}

/// Status verifikasi identitas (FR-VER-003). Desain: "ID Verified" biru.
class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge(this.status);

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      VerificationStatus.verified => (
        'ID Verified',
        const Color(0xFF2563EB),
        const Color(0xFFEFF6FF),
      ),
      VerificationStatus.pending => (
        'Menunggu verifikasi',
        const Color(0xFFB45309),
        const Color(0xFFFFFBEB),
      ),
      VerificationStatus.rejected => (
        'Verifikasi ditolak',
        AccountStyle.danger,
        const Color(0xFFFEF2F2),
      ),
      VerificationStatus.unverified => (
        'Belum verifikasi',
        AccountStyle.muted,
        const Color(0xFFF1F5F9),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == VerificationStatus.verified)
            const OrderIcon(AccountStyle.iconVerified, size: 13)
          else
            Icon(Icons.info_outline_rounded, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.style(
              size: 11,
              weight: AppTypography.semiBold,
              color: color,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
