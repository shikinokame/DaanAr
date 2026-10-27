import 'package:flutter/material.dart';

/// DaanAR "Philippine archival field guide" palette.
///
/// Contrast notes (measured against [AppColors.background] ivory):
/// - [ink] / [primary] forest green ............ 9.6 : 1
/// - [charcoal] ................................ 12.4 : 1
/// - [textMuted] ............................... 6.0 : 1
/// - [brassInk] (small brass text on ivory) .... 5.4 : 1
/// - [secondary] bright brass ON forest green .. 5.7 : 1
///   (bright brass is too light for text on ivory — use it for rules,
///   borders and text on green surfaces only).
class AppColors {
  AppColors._();

  // ── Ink ────────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1B4332); // deep forest-green ink
  static const Color ink = primary;
  static const Color inkDeep = Color(0xFF12301F); // masthead / dark plates
  static const Color charcoal = Color(0xFF2B2A26); // body copy
  static const Color textMuted = Color(0xFF5E5A50); // captions, meta

  // ── Brass ──────────────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFFD4A853); // antique brass (on green)
  static const Color brass = secondary;
  static const Color brassInk = Color(0xFF7A5C22); // brass text on ivory

  // ── Paper ──────────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF4EEE2); // archival ivory
  static const Color paperDeep = Color(0xFFEBE3D2); // recessed paper
  static const Color surface = Color(0xFFFBF8F1); // mount board / cards
  static const Color cardBg = surface;
  static const Color divider = Color(0xFFDCD2BF); // engraved hairline
  static const Color rule = Color(0xFFC9BB9F); // stronger frame line

  static const Color error = Color(0xFFA63A2B);

  // Category badge colors (muted, archival)
  static const Map<String, Color> categoryColors = {
    'church': Color(0xFF6E3B12),
    'park': Color(0xFF2D5A43),
    'historical': Color(0xFF3F3D38),
    'natural': Color(0xFF3B6B50),
    'cultural': Color(0xFF5A3A6B),
  };
}

/// Font families bundled in `assets/fonts/` (works fully offline).
class AppFonts {
  AppFonts._();
  static const String serif = 'Cormorant';
  static const String sans = 'Inter';
}

/// Reusable text styles for the archival look.
class AppText {
  AppText._();

  /// Small uppercase label above a section title ("CURATOR'S SELECTION").
  static const TextStyle eyebrow = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: AppColors.brassInk,
  );

  /// Editorial serif section title ("Featured Landmarks").
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: 27,
    fontWeight: FontWeight.w600,
    height: 1.1,
    color: AppColors.charcoal,
  );

  /// Serif title on cards.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: AppColors.charcoal,
  );

  /// Italic folio / caption line ("Folio No. 01").
  static const TextStyle folio = TextStyle(
    fontFamily: AppFonts.serif,
    fontStyle: FontStyle.italic,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.brassInk,
  );

  /// Small uppercase meta line ("MANAOAG, PANGASINAN").
  static const TextStyle meta = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.1,
    color: AppColors.textMuted,
  );

  /// Uppercase text-button label ("VIEW ALL").
  static const TextStyle action = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: AppColors.ink,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const serifTitle = TextStyle(
      fontFamily: AppFonts.serif,
      fontWeight: FontWeight.w600,
      color: AppColors.charcoal,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.sans,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.inkDeep,
        foregroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.surface,
          letterSpacing: 0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppText.action,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.inkDeep,
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.sans,
          color: AppColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppFonts.serif,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.textMuted,
          ),
        ),
      ),
      textTheme: TextTheme(
        displaySmall: serifTitle.copyWith(fontSize: 36, height: 1.05),
        headlineLarge: serifTitle.copyWith(fontSize: 32, height: 1.1),
        headlineMedium: serifTitle.copyWith(fontSize: 27, height: 1.1),
        headlineSmall: serifTitle.copyWith(fontSize: 23, height: 1.15),
        titleLarge: serifTitle.copyWith(fontSize: 21, height: 1.2),
        titleMedium: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.charcoal),
        titleSmall: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.charcoal),
        bodyLarge: const TextStyle(
            fontSize: 15, color: AppColors.charcoal, height: 1.6),
        bodyMedium: const TextStyle(
            fontSize: 13.5, color: AppColors.textMuted, height: 1.5),
        bodySmall: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        labelLarge: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.6),
        labelSmall: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      ),
    );
  }
}
