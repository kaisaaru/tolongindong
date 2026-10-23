import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../home_metrics.dart';

/// Satu tips "Seputar TolongDong": kartu ringkas di beranda, langkah
/// lengkapnya di lembar bawah.
class AppTip {
  const AppTip({
    required this.title,
    required this.summary,
    required this.icon,
    required this.color,
    required this.points,
  });

  final String title;
  final String summary;
  final IconData icon;

  /// Latar ikon dan kartu.
  final Color color;
  final List<String> points;

  /// Isinya statis: backend belum punya endpoint artikel. Hanya menjelaskan
  /// alur yang memang ada di aplikasi.
  static const all = [
    AppTip(
      title: 'Cara pesan helper',
      summary: 'Pilih layanan, isi detail, lalu konfirmasi pesanan.',
      icon: Icons.touch_app_outlined,
      color: Color(0xFFFFE4E4),
      points: [
        'Pilih kategori di beranda: Personal, Delivery, atau Household.',
        'Isi kebutuhanmu: alamat, waktu, dan detail pekerjaan.',
        'Pilih helper, voucher, dan metode pembayaran, lalu tekan Pesan.',
        'Pantau pesanan di tab Aktifitas sampai selesai, lalu beri rating.',
      ],
    ),
    AppTip(
      title: 'Helper terverifikasi',
      summary: 'Identitas helper dicek sebelum boleh menerima pesanan.',
      icon: Icons.verified_user_outlined,
      color: Color(0xFFE4F6EA),
      points: [
        'Setiap helper wajib lolos verifikasi identitas sebelum menerima '
            'pesanan.',
        'Cek rating dan jumlah tugas selesai di profil helper.',
        'Masih ragu? Ngobrol dulu lewat tombol chat di profil helper.',
      ],
    ),
    AppTip(
      title: 'Pembayaran aman',
      summary: 'Dana ditahan dulu sampai pesananmu selesai.',
      icon: Icons.lock_outline_rounded,
      color: Color(0xFFE6E8FF),
      points: [
        'Pembayaran tidak langsung diteruskan ke helper, tapi ditahan dulu.',
        'Dana baru diteruskan setelah kamu menyatakan pesanan selesai.',
        'Ada kendala? Jangan tandai selesai dulu, sampaikan lewat chat.',
      ],
    ),
  ];
}

/// Lembar bawah berisi langkah lengkap satu tips.
Future<void> showTipSheet(BuildContext context, AppTip tip) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.light,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _TipIcon(tip: tip, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    tip.title,
                    style: AppTypography.style(
                      size: 18,
                      weight: AppTypography.semiBold,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            for (var i = 0; i < tip.points.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: AppTypography.style(
                          size: 11,
                          weight: AppTypography.semiBold,
                          color: AppColors.light,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tip.points[i],
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.regular,
                          color: AppColors.textDescription,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Kartu tips mendatar di beranda, setinggi dan selebar kartu jasa.
class TipsSection extends StatelessWidget {
  const TipsSection({super.key});

  static const _cardWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: HomeMetrics.bodyPadding,
        ),
        itemCount: AppTip.all.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: HomeMetrics.offerCardGap),
        itemBuilder: (context, index) {
          final tip = AppTip.all[index];
          return Material(
            color: AppColors.light,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HomeMetrics.offerCardRadius),
              side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(HomeMetrics.offerCardRadius),
              onTap: () => showTipSheet(context, tip),
              child: SizedBox(
                width: _cardWidth,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TipIcon(tip: tip, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        tip.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.semiBold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Mengisi sisa kartu; dua baris, sisanya dipotong.
                      Expanded(
                        child: Text(
                          tip.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            size: 11,
                            weight: AppTypography.regular,
                            color: AppColors.textDescription,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TipIcon extends StatelessWidget {
  const _TipIcon({required this.tip, required this.size});

  final AppTip tip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tip.color, shape: BoxShape.circle),
      child: Icon(tip.icon, size: size * 0.55, color: AppColors.primary),
    );
  }
}
