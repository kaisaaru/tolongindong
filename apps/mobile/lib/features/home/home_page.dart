import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../models/auth_user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../auth/auth_repository.dart';
import '../auth/login_page.dart';

/// Beranda sementara. Fungsinya membuktikan sesi berjalan: menampilkan profil
/// dari token yang tersimpan, memuat ulang lewat `GET /me`, dan keluar lewat
/// `POST /logout`.
///
/// Nanti diganti beranda sungguhan (kategori layanan, pesanan berjalan).
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.user});

  final AuthUser user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authRepo = AuthRepository();

  late AuthUser _user = widget.user;
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final fresh = await _authRepo.me();
      if (mounted) setState(() => _user = fresh);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    await _authRepo.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang profil',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Halo, ${_user.fullName}',
              style: AppTypography.style(
                size: AppTypography.h5,
                weight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _user.email,
              style: AppTypography.style(
                size: AppTypography.caption,
                weight: AppTypography.regular,
                color: AppColors.textDescription,
              ),
            ),
            const SizedBox(height: 24),
            _InfoTile(
              label: 'Status verifikasi',
              value: _statusLabel(_user.verificationStatus),
              color: _statusColor(_user.verificationStatus),
            ),
            _InfoTile(
              label: 'Saldo TD-Wallet',
              value: _rupiah(_user.wallet.availableBalance),
            ),
            if (_user.wallet.heldBalance > 0)
              _InfoTile(
                label: 'Saldo tertahan',
                value: _rupiah(_user.wallet.heldBalance),
                color: AppColors.warning,
              ),
            _InfoTile(label: 'Nomor HP', value: _user.phoneNumber ?? '-'),
            if (_user.isAdmin)
              const _InfoTile(
                label: 'Peran',
                value: 'Administrator',
                color: AppColors.info,
              ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _busy ? null : _logout,
              child: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(VerificationStatus status) => switch (status) {
        VerificationStatus.unverified => 'Belum diajukan',
        VerificationStatus.pending => 'Sedang ditinjau',
        VerificationStatus.verified => 'Terverifikasi',
        VerificationStatus.rejected => 'Ditolak',
      };

  static Color _statusColor(VerificationStatus status) => switch (status) {
        VerificationStatus.verified => AppColors.success,
        VerificationStatus.pending => AppColors.warning,
        VerificationStatus.rejected => AppColors.error,
        VerificationStatus.unverified => AppColors.textDescription,
      };

  /// Backend mengirim rupiah sebagai bilangan bulat, jadi cukup disisipi titik.
  static String _rupiah(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return 'Rp $buffer';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      // Keduanya Flexible: nama panjang atau layar sempit tidak boleh
      // membuat baris ini meluber.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                size: AppTypography.caption,
                weight: AppTypography.regular,
                color: AppColors.textDescription,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                size: AppTypography.caption,
                weight: AppTypography.bold,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
