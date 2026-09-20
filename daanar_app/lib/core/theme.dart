import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const Color primary    = Color(0xFF1B4332); // deep green
  static const Color secondary  = Color(0xFFD4A853); // gold
  static const Color background = Color(0xFFF5F0E8); // warm sand
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color charcoal   = Color(0xFF2D2D2D);
  static const Color textMuted  = Color(0xFF6B6B6B);
  static const Color cardBg     = Color(0xFFFAF7F2);
  static const Color divider    = Color(0xFFE0D9CE);
  static const Color error      = Color(0xFFC62828);

  // Category badge colors
  static const Map<String, Color> categoryColors = {
    'church'    : Color(0xFF7B3F00),
    'park'      : Color(0xFF2D6A4F),
    'historical': Color(0xFF4A4A4A),
    'natural'   : Color(0xFF40916C),
    'cultural'  : Color(0xFF6A3D9A),
  };
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBg,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.cardBg,
          selectedColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.divider),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.charcoal,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.charcoal),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.charcoal),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.charcoal),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.charcoal),
          bodyLarge: TextStyle(fontSize: 15, color: AppColors.charcoal, height: 1.6),
          bodyMedium: TextStyle(fontSize: 13, color: AppColors.textMuted),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
        ),
      );
}


