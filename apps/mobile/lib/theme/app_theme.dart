// app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.light,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        error: AppColors.error,
        brightness: Brightness.light,
      ),

      // ===== AppBar =====
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.light,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.style(
          size: AppTypography.h6,
          weight: AppTypography.bold,
        ),
      ),

      // ===== Tombol solid (misal: "Login") =====
      // Elevation dimatikan, glow di desain dipasang lewat PrimaryButton.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.light,
          disabledBackgroundColor: AppColors.disabled, // state form belum valid
          disabledForegroundColor: AppColors.light,
          textStyle: AppTypography.style(
            size: AppTypography.body,
            weight: AppTypography.semiBold,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 48),
          // Bentuk pill, sesuai contoh Login.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ).copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),

      // ===== Tombol outline (misal: "Login dengan Google") =====
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          textStyle: AppTypography.style(
            size: AppTypography.caption,
            weight: AppTypography.regular,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),

      // ===== Text field (email, password, search) =====
      inputDecorationTheme: InputDecorationTheme(
        isDense: true, // tanpa ini M3 memaksa tinggi field minimal 48
        filled: true,
        fillColor: AppColors.inputFill,
        hintStyle: AppTypography.style(
          size: AppTypography.small,
          weight: AppTypography.regular,
          color: AppColors.textSecondary,
        ),
        suffixIconColor: AppColors.textSecondary, // icon mata di password
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(
          const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: _inputBorder(const BorderSide(color: AppColors.error)),
        focusedErrorBorder: _inputBorder(
          const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),

      // Default warna icon lepas (misal Icon() tanpa SvgPicture)
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    );
  }

  // Radius 24 bikin field setinggi 40 jadi pill, sama seperti tombol.
  static OutlineInputBorder _inputBorder([BorderSide side = BorderSide.none]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: side,
    );
  }
}
