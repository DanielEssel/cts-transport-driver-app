// lib/app/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF16A34A); // Forest Green
  static const Color primaryDark  = Color(0xFF15803D); // Deep Forest
  static const Color primaryLight = Color(0xFFF0FDF4); // Soft green bg

  static const Color accent       = Color(0xFFF59E0B); // Premium gold
  static const Color danger       = Color(0xFFDC2626);
  static const Color dangerLight  = Color(0xFFFEE2E2);
  static const Color warning      = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info         = Color(0xFF0284C7);
  static const Color infoLight    = Color(0xFFE0F2FE);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color background      = Color(0xFFF8FAF9);
  static const Color cardBackground  = Color(0xFFFFFFFF);
  static const Color divider         = Color(0xFFE2F0E8);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF052E16);
  static const Color textSecondary = Color(0xFF4B7A5C);
  static const Color textHint      = Color(0xFF86A994);
  static const Color successColor  = Color(0xFF16A34A);

  // ── Typography ────────────────────────────────────────────────────────────
  static const TextStyle heading4 = TextStyle(
    fontSize:   18,
    fontWeight: FontWeight.w600,
    color:      textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color:    textSecondary,
  );

  // ── Weight tier colors ────────────────────────────────────────────────────
  static const Map<String, Color> weightTierColors = {
    'Small':  Color(0xFF16A34A), // Green
    'Medium': Color(0xFF0284C7), // Teal-blue
    'Large':  Color(0xFFD97706), // Amber
    'Bulk':   Color(0xFFDC2626), // Red
  };

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get theme {
    return ThemeData(
      useMaterial3:            true,
      colorScheme:             ColorScheme.fromSeed(
        seedColor:  primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
      fontFamily:              'SF Pro Display',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation:       0,
        centerTitle:     true,
        titleTextStyle:  TextStyle(
          color:       textPrimary,
          fontSize:    17,
          fontWeight:  FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      surface,
        selectedItemColor:    primary,
        unselectedItemColor:  textHint,
        type:                 BottomNavigationBarType.fixed,
        elevation:            12,
        selectedLabelStyle:   TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color:     cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation:       0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize:      16,
            fontWeight:    FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side:  const BorderSide(color: primary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       const Color(0xFFF8FAF9),
        contentPadding:  const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2F0E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2F0E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF15803D)],
    begin:  Alignment.topLeft,
    end:    Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color:      Colors.black.withValues(alpha: 0.05),
      blurRadius: 16,
      offset:     const Offset(0, 4),
    ),
  ];
}

// ── Local design token class (used in screens) ────────────────────────────────

class C {
  static const bg          = Color(0xFFF8FAF9);
  static const card        = Color(0xFFFFFFFF);
  static const primary     = Color(0xFF16A34A);
  static const primaryDim  = Color(0xFFF0FDF4);
  static const success     = Color(0xFF16A34A);
  static const successDim  = Color(0xFFDCFCE7);
  static const warning     = Color(0xFFD97706);
  static const warningDim  = Color(0xFFFEF3C7);
  static const error       = Color(0xFFDC2626);
  static const errorDim    = Color(0xFFFEE2E2);
  static const textPrimary   = Color(0xFF052E16);
  static const textSecondary = Color(0xFF4B7A5C);
  static const textTertiary  = Color(0xFF86A994);
  static const border      = Color(0xFFE2F0E8);

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color:      Colors.black.withValues(alpha: 0.05),
      blurRadius: 16,
      offset:     const Offset(0, 4),
    ),
  ];
}

class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}