import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/storage/app_preferences.dart';
import '../../theme/app_typography.dart';
import '../auth/session_store.dart';
import '../home/home_page.dart';
import '../order/widgets/order_widgets.dart';
import 'helper_settings_page.dart';
import 'helper_store.dart';
import 'helper_work_repository.dart';
import 'widgets/helper_widgets.dart';

/// Profil mode Helper: identitas, layanan, pengaturan, dan beralih ke
/// mode Client tanpa akun baru.
class HelperProfileView extends StatelessWidget {
  const HelperProfileView({super.key});

  Future<void> _switchToClient(BuildContext context) async {
    final navigator = Navigator.of(context);
    await AppPreferences().setMode(AppMode.client);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionStore>().user;
    final status = context.watch<HelperStore>().status;
    final phone = user?.phoneNumber;
    final contact = [
      if (user != null) user.email,
      if (phone != null && phone.isNotEmpty) phone,
    ].join(' · ');
    final muted = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      color: HelperStyle.muted,
      height: 1.5,
    );

    return Column(
      children: [
        const HelperHeader(
          title: 'Profil',
          subtitle: 'Akun TolonginDong kamu',
          back: false,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              HelperCard(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Column(
                  children: [
                    HelperAvatar(
                      name: user?.fullName ?? '',
                      photoUrl: user?.photoUrl,
                      size: 72,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.fullName ?? '',
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        size: 20,
                        weight: AppTypography.bold,
                        color: HelperStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const CategoryTag('Mode Helper'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const OrderIcon(
                          HelperStyle.iconVerified,
                          size: 14,
                          color: HelperStyle.green,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            status.isVerifiedHelper
                                ? 'Identitas terverifikasi'
                                : 'Menunggu verifikasi',
                            style: AppTypography.style(
                              size: 11,
                              weight: AppTypography.medium,
                              color: HelperStyle.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _RatingLine(status: status),
                    const Divider(height: 24, color: HelperStyle.cardBorder),
                    Text(contact, textAlign: TextAlign.center, style: muted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              HelperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Layanan kamu',
                            style: AppTypography.style(
                              size: 13,
                              weight: AppTypography.semiBold,
                              color: HelperStyle.ink,
                            ),
                          ),
                        ),
                        CategoryTag(
                          status.available ? 'Tersedia' : 'Tidak tersedia',
                          tone: status.available
                              ? BannerTone.green
                              : BannerTone.gray,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (status.categories.isEmpty)
                      Text('Belum ada kategori layanan.', style: muted)
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in status.categories)
                            CategoryTag(c.name),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              HelperCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuRow(
                      icon: HelperStyle.iconUserEdit,
                      label: 'Edit informasi profil',
                      onTap: () => ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Edit profil belum tersedia.'),
                          ),
                        ),
                    ),
                    const Divider(height: 1, color: HelperStyle.cardBorder),
                    _MenuRow(
                      icon: HelperStyle.iconSliders,
                      label: 'Kategori dan ketersediaan',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HelperSettingsPage(),
                        ),
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
                      'Satu akun, dua peran',
                      style: AppTypography.style(
                        size: 13,
                        weight: AppTypography.semiBold,
                        color: HelperStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kamu sedang menggunakan mode Helper. Beralih ke Client '
                      'untuk meminta bantuan tanpa membuat akun baru.',
                      style: muted,
                    ),
                    const SizedBox(height: 12),
                    HelperButton(
                      label: 'Beralih ke Client',
                      soft: true,
                      onPressed: () => _switchToClient(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lima bintang dari rata-rata rating, lalu "4,9 · 12 selesai".
class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.status});

  final HelperStatus status;

  @override
  Widget build(BuildContext context) {
    final rated = status.ratingCount > 0;
    final average = status.rating.toStringAsFixed(1).replaceAll('.', ',');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            Icons.star_rounded,
            size: 16,
            color: rated && status.rating >= i - 0.5
                ? HelperStyle.red
                : HelperStyle.cardBorder,
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            rated
                ? '$average · ${status.completedCount} selesai'
                : 'Belum ada rating · ${status.completedCount} selesai',
            style: AppTypography.style(
              size: 11,
              weight: AppTypography.medium,
              color: HelperStyle.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            OrderIcon(icon, size: 17),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.style(
                  size: 12,
                  weight: AppTypography.medium,
                  color: HelperStyle.ink,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: HelperStyle.muted),
          ],
        ),
      ),
    );
  }
}
