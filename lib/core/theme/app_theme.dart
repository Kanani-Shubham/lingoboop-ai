import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData getTheme({Color accentColor = AppColors.foxMaru}) {
    final baseTextTheme = GoogleFonts.fredokaTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.phoneBackground,
      colorScheme: ColorScheme.light(
        primary: accentColor,
        secondary: accentColor,
        surface: AppColors.cardSurface,
        onPrimary: AppColors.textLight,
        onSurface: AppColors.textDark,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.fredoka(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        displayMedium: GoogleFonts.fredoka(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        headlineLarge: GoogleFonts.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        headlineMedium: GoogleFonts.fredoka(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        titleLarge: GoogleFonts.fredoka(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        titleMedium: GoogleFonts.fredoka(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
        bodyLarge: GoogleFonts.fredoka(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
        bodyMedium: GoogleFonts.fredoka(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        bodySmall: GoogleFonts.fredoka(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.fredoka(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

