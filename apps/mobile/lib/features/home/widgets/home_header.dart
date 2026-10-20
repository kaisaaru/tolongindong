import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../models/auth_user.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../home_metrics.dart';

/// Header merah beranda: sapaan, lokasi aktif, dan lonceng notifikasi.
/// Memenuhi FR-PRF-004 (lokasi aktif di atas) dan FR-NOT-001 (penanda
/// notifikasi belum dibaca).
///
/// Tingginya sampai sedikit melewati tepi lembar putih, supaya warna merah
/// tetap terlihat di balik sudut lembar yang membulat.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.user,
    required this.location,
    this.hasUnreadNotification = false,
    this.onNotificationTap,
  });

  final AuthUser user;

  /// Alamat utama tersimpan (FR-PRF-002), atau ajakan mengatur alamat.
  final String location;

  final bool hasUnreadNotification;
  final VoidCallback? onNotificationTap;

  /// Posisi tepi atas lembar putih di perangkat ini.
  static double sheetTopOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      HomeMetrics.headerTopGap +
      HomeMetrics.avatarSize +
      HomeMetrics.headerBottomGap;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final sheetTop = sheetTopOf(context);
    final height = sheetTop + HomeMetrics.sheetRadius;

    return SizedBox(
      height: height,
      child: ClipRect(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: _backgroundGradient(
              height,
              MediaQuery.sizeOf(context).height,
            ),
          ),
          child: CustomPaint(
            painter: _HeaderBandsPainter(
              shift: sheetTop - HomeMetrics.designSheetTop,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: safeTop + HomeMetrics.headerTopGap,
                left: HomeMetrics.headerPadding,
                right: HomeMetrics.headerPadding,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: HomeMetrics.avatarSize,
                  child: Row(
                    children: [
                      _Avatar(photoUrl: user.photoUrl, name: user.fullName),
                      const SizedBox(width: HomeMetrics.avatarTextGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Hallo, ${_firstName(user.fullName)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                size: HomeMetrics.greetingSize,
                                weight: AppTypography.bold,
                                color: AppColors.light,
                              ),
                            ),
                            const SizedBox(height: HomeMetrics.greetingPillGap),
                            _LocationPill(label: location),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Transform.translate(
                        offset: const Offset(0, -HomeMetrics.bellRaise),
                        child: _NotificationButton(
                          hasUnread: hasUnreadNotification,
                          onTap: onNotificationTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Latar frame beranda di Figma adalah gradien vertikal `#FF4B4B` ->
  /// `#992D2D` sepanjang tinggi layar penuh (dicek terhadap 12 titik di
  /// desain, galat maksimal 1/255). Header hanya menempati bagian atasnya,
  /// jadi warna di tepi bawah header dihitung dari posisinya di layar.
  static const _gradientTop = AppColors.primary;
  static const _gradientBottom = Color(0xFF992D2D);

  static LinearGradient _backgroundGradient(
    double boxHeight,
    double screenHeight,
  ) {
    final t = screenHeight <= 0 ? 0.0 : (boxHeight / screenHeight).clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_gradientTop, Color.lerp(_gradientTop, _gradientBottom, t)!],
    );
  }

  static String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

/// Tiga pita miring di latar header.
///
/// Geometrinya diambil dari ekspor SVG Figma (persegi panjang `#E22C2C`
/// diputar -19,78° dengan inner shadow), lalu diposisikan sesuai pengukuran
/// desain. Digambar langsung alih-alih memakai berkas SVG-nya karena
/// `flutter_svg` tidak mendukung elemen `<filter>`, sehingga inner shadow-nya
/// akan hilang.
class _HeaderBandsPainter extends CustomPainter {
  const _HeaderBandsPainter({required this.shift});

  /// Selisih tepi lembar putih perangkat ini terhadap desain. Pita digeser
  /// sebesar ini supaya titik temunya dengan tepi lembar tetap sama.
  final double shift;

  static const _angle = -19.7817 * math.pi / 180;
  static const _color = Color(0xFFE22C2C);
  static const _innerShadow = Color(0x40000000); // hitam 25%

  // Koordinat frame desain (dp), titik asal = sudut kiri-atas sebelum diputar.
  //
  // 22525 diambil dari Dev Mode Figma (Left -19.77, Top 2.55). Top di sana
  // adalah tepi atas kotak pembatas, jadi y asal = 2,55 + 314,64 x sin(19,78°).
  // Dua pita lainnya masih hasil pengukuran piksel dari screenshot desain.
  static const _bands = [
    _Band(-19.77, 109.04, 314.64, 98.37, 22), // Rectangle 22525 (Dev Mode)
    _Band(66.4629, 196.391, 480.232, 143, 27), // Rectangle 22524
    _Band(287.859, -18.5127, 314.642, 113.828, 22), // Rectangle 22526
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _color;
    final shadow = Paint()
      ..color = _innerShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (final band in _bands) {
      final path = band.toPath(shift, _angle);
      canvas.drawPath(path, fill);

      // Inner shadow sesuai filter SVG aslinya: jatuh 4 dp ke bawah, blur 2,
      // dan hanya terlihat di dalam pita (menggelapkan tepi atasnya).
      canvas.save();
      canvas.clipPath(path);
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(path.getBounds().inflate(12))
        ..addPath(path.shift(const Offset(0, 4)), Offset.zero);
      canvas.drawPath(ring, shadow);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HeaderBandsPainter old) => old.shift != shift;
}

class _Band {
  const _Band(this.x, this.y, this.width, this.height, this.radius);

  final double x;
  final double y;
  final double width;
  final double height;
  final double radius;

  /// Persegi panjang membulat yang diputar pada sudut kiri-atasnya sendiri,
  /// sama seperti `transform="rotate(a x y)"` di SVG.
  Path toPath(double shift, double angle) {
    final origin = Offset(x, y + shift);
    final rrect = RRect.fromRectAndRadius(
      origin & Size(width, height),
      Radius.circular(radius),
    );
    final rotation = Matrix4.translationValues(origin.dx, origin.dy, 0)
      ..multiply(Matrix4.rotationZ(angle))
      ..multiply(Matrix4.translationValues(-origin.dx, -origin.dy, 0));
    return (Path()..addRRect(rrect)).transform(rotation.storage);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.name});

  final String? photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;

    return ClipOval(
      child: SizedBox.square(
        dimension: HomeMetrics.avatarSize,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                // Foto profil bisa gagal dimuat (URL R2 belum lengkap).
                // Jangan sampai header ikut rusak karenanya.
                errorBuilder: (_, _, _) => _InitialAvatar(name: name),
              )
            : _InitialAvatar(name: name),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return ColoredBox(
      color: AppColors.primaryLight,
      child: Center(
        child: Text(
          initial,
          style: AppTypography.style(
            size: AppTypography.h6,
            weight: AppTypography.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3.6, 14, 3.6),
      decoration: BoxDecoration(
        // Hitam transparan, jadi warnanya ikut gelap-terang pita di belakangnya.
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 12,
            color: Color(0xFFFF7B7B),
          ),
          const SizedBox(width: 6),
          // Fleksibel supaya alamat panjang tidak melebar keluar layar.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                size: HomeMetrics.locationSize,
                weight: AppTypography.regular,
                color: AppColors.light,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.hasUnread, this.onTap});

  final bool hasUnread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.light,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: HomeMetrics.bellSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Garis tipis seperti desain; ikon Material terlalu tebal.
              const Icon(
                CupertinoIcons.bell,
                size: 21,
                color: AppColors.textPrimary,
              ),
              // Badge dot merah kalau ada notifikasi belum dibaca (FR-NOT-001).
              if (hasUnread)
                Positioned(
                  top: 8,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.light, width: 1.2),
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
