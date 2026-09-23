import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Warna Utama
  static const Color primary = Color(0xFFFF4B4B);
  static const Color primaryLight = Color(0xFFFFE4E4); // latar pink muda
  static const Color dark = Color(0xFF292929);
  static const Color light = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF121212);
  static const Color textSecondary = Color(0xFFACACAC); // teks pendukung
  static const Color textDescription = Color(0xFF7C7C7C); // paragraf deskripsi
  static const Color textMuted = Color(0xFF7F7F7F); // teks tombol outline

  // Netral
  static const Color inputFill = Color(0xFFF2F2F2); // latar text field
  static const Color outline = Color(0xFFB1B1B1); // outline tombol, ikon mata
  static const Color border = Color(0xFFD0D0D0); // divider
  static const Color disabled = Color(0xFFE0E0E0); // tombol disabled

  // Semantic Color
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}
