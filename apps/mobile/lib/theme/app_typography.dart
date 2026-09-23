// app_typography.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // ===== Ukuran Heading/Body (font: Poppins) =====
  static const double h1 = 80;
  static const double h2 = 60;
  static const double h3 = 40;
  static const double h4 = 30;
  static const double h5 = 24;
  static const double h6 = 20;
  static const double body = 16;
  static const double caption = 14;
  static const double small = 12;
  static const double tiny = 10;

  static const FontWeight heavy = FontWeight.w800;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight thin = FontWeight.w200;

  // Ganti weight lewat parameter, jangan copyWith(fontWeight: ...):
  // google_fonts memuat file font per weight.
  static TextStyle style({
    required double size,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
    double height = 1.0, // naikkan untuk teks multi-baris, misal 1.5
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      // 0 seperti di Figma. Kalau dikosongkan, Text ikut letterSpacing tema
      // Material 3 (0.25-0.5), jadi teks lebih lebar dari desain.
      letterSpacing: 0,
    );
  }

  static TextStyle buttonXlarge({Color color = AppColors.dark}) => TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 23,
    fontWeight: FontWeight.w600,
    height: 32 / 23,
    color: color,
  );

  static TextStyle buttonLarge({Color color = AppColors.dark}) => TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 32 / 18,
    color: color,
  );

  static TextStyle buttonMedium({Color color = AppColors.dark}) => TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 24 / 14,
    color: color,
  );

  static TextStyle buttonSmall({Color color = AppColors.dark}) => TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    color: color,
  );
}
