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

  // ── Theme roles (the Wallet card's greens) ────────────────────────────────
  // [primary] is the brand green: checkboxes, progress, the gradient's light
  // end and large marks. Filled buttons use [primaryDark] with white
  // [onPrimary] text (5.0:1; white on primary is only 3.3:1, too low for
  // button text). Green text and thin icons on light surfaces also use
  // [primaryDark]. Large green surfaces use [primaryGradient]; small text on
  // it sits on [onGradientScrim] (4.9:1 or better).
  static const Color onPrimary     = Colors.white;
  static const Color primaryDeep   = Color(0xFF166534); // pressed / on tint
  static const Color primarySubtle = Color(0xFFDCFCE7); // selected tint

  static const String fontFamily = 'Inter';

  // ── Service accents (passenger app values; text-safe on white) ───────────
  static const Color serviceDelivery     = Color(0xFF0369A1); // 5.9:1
  static const Color serviceDeliveryTint = Color(0xFFE0F2FE);
  static const Color serviceGas          = Color(0xFFC2410C); // 5.2:1
  static const Color serviceGasTint      = Color(0xFFFFF1E6);

  /// Amber for text on [warningLight] ([warning] there is only 2.9:1).
  static const Color warningText = Color(0xFF92400E);

  /// Red for text on [dangerLight] ([danger] there is only 3.9:1).
  static const Color dangerText = Color(0xFFB91C1C);

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
  /// The app theme (applied in main.dart). Material widgets that are not
  /// styled by hand pick up the CTSGo look from here. Sizes and layout follow
  /// Material defaults except where noted, so existing screens keep their
  /// shape; only colour, font and component styling change.
  static ThemeData get theme {
    // Explicit roles: fromSeed alone would shift primary away from #16A34A.
    final scheme = ColorScheme.fromSeed(
      seedColor:  primary,
      brightness: Brightness.light,
    ).copyWith(
      primary:                 primary,
      onPrimary:               onPrimary,
      primaryContainer:        primarySubtle,
      onPrimaryContainer:      primaryDeep,
      secondary:               primaryDark,
      onSecondary:             Colors.white,
      secondaryContainer:      primaryLight,
      onSecondaryContainer:    primaryDeep,
      surface:                 surface,
      onSurface:               textPrimary,
      onSurfaceVariant:        textSecondary,
      surfaceTint:             Colors.transparent,
      surfaceContainerLowest:  surface,
      surfaceContainerLow:     background,
      surfaceContainer:        background,
      surfaceContainerHigh:    primaryLight,
      surfaceContainerHighest: primarySubtle,
      outline:                 textSecondary,
      outlineVariant:          divider,
      error:                   danger,
      onError:                 Colors.white,
      errorContainer:          dangerLight,
      onErrorContainer:        const Color(0xFFB91C1C),
    );

    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: c, width: w),
        );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const buttonText = TextStyle(
      fontFamily:    fontFamily,
      fontSize:      16,
      fontWeight:    FontWeight.w600,
      letterSpacing: -0.2,
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    const buttonMin     = Size(64, 48);

    return ThemeData(
      useMaterial3:            true,
      brightness:              Brightness.light,
      colorScheme:             scheme,
      fontFamily:              fontFamily,
      primaryColor:            primary,
      scaffoldBackgroundColor: background,
      dividerColor:            divider,
      appBarTheme: const AppBarTheme(
        backgroundColor:        Colors.transparent,
        foregroundColor:        textPrimary,
        surfaceTintColor:       Colors.transparent,
        elevation:              0,
        scrolledUnderElevation: 0,
        titleTextStyle:         TextStyle(
          fontFamily:    fontFamily,
          color:         textPrimary,
          fontSize:      18,
          fontWeight:    FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      // Label sizes are left to the widget (14 / 12 by default).
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      surface,
        selectedItemColor:    primaryDark,
        unselectedItemColor:  textSecondary,
        type:                 BottomNavigationBarType.fixed,
        selectedLabelStyle:   TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color:            cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:         primaryDark,
          foregroundColor:         onPrimary,
          disabledBackgroundColor: primaryLight,
          disabledForegroundColor: textSecondary,
          elevation:               0,
          minimumSize:             buttonMin,
          padding:                 buttonPadding,
          textStyle:               buttonText,
          shape:                   buttonShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor:         primaryDark,
          foregroundColor:         onPrimary,
          disabledBackgroundColor: primaryLight,
          disabledForegroundColor: textSecondary,
          minimumSize:             buttonMin,
          padding:                 buttonPadding,
          textStyle:               buttonText,
          shape:                   buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side:            const BorderSide(color: primary),
          minimumSize:     buttonMin,
          padding:         buttonPadding,
          textStyle:       buttonText,
          shape:           buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          minimumSize:     const Size(48, 48),
          textStyle:       buttonText.copyWith(fontSize: 14.5),
          shape:           buttonShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:             true,
        fillColor:          surface,
        contentPadding:     const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border:             field(divider),
        enabledBorder:      field(divider),
        focusedBorder:      field(primary, 1.5),
        errorBorder:        field(danger),
        focusedErrorBorder: field(danger, 1.5),
        disabledBorder:     field(primaryLight),
        labelStyle:         const TextStyle(color: textSecondary),
        floatingLabelStyle: const TextStyle(color: primaryDark),
        hintStyle:          const TextStyle(color: textSecondary),
        errorStyle:         const TextStyle(color: danger),
        prefixIconColor:    textSecondary,
        suffixIconColor:    textSecondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor:          primary,
        selectionColor:       primary.withValues(alpha: 0.30),
        selectionHandleColor: primary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color:              primary,
        linearTrackColor:   primarySubtle,
        circularTrackColor: Colors.transparent,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) {
            return s.contains(WidgetState.selected)
                ? textHint
                : Colors.transparent;
          }
          return s.contains(WidgetState.selected)
              ? primary
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side:  const BorderSide(color: textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:  surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: heading4.copyWith(fontFamily: fontFamily),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize:   14,
          height:     1.45,
          color:      textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:      surface,
        surfaceTintColor:     Colors.transparent,
        modalBackgroundColor: surface,
      ),
      // Behaviour stays Material's default (fixed) so placement is unchanged.
      snackBarTheme: const SnackBarThemeData(
        backgroundColor:  textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize:   14,
          color:      Colors.white,
        ),
        actionTextColor: Color(0xFF4ADE80), // 8.6:1 on textPrimary
      ),
      chipTheme: const ChipThemeData(
        backgroundColor:    surface,
        selectedColor:      primarySubtle,
        disabledColor:      primaryLight,
        checkmarkColor:     primaryDeep,
        side:               BorderSide(color: divider),
        labelStyle:         TextStyle(
          fontFamily: fontFamily,
          fontSize:   13,
          fontWeight: FontWeight.w500,
          color:      textPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize:   13,
          fontWeight: FontWeight.w600,
          color:      primaryDeep,
        ),
      ),
    );
  }

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// The Wallet balance card's diagonal green, for prominent surfaces only.
  /// White text on it: large (18.7 px bold+) anywhere (3.3:1 at the light
  /// end); smaller text on [onGradientScrim].
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin:  Alignment.topLeft,
    end:    Alignment.bottomRight,
  );

  /// Darkens the gradient under small white text: 4.9:1 at its light end.
  static const Color onGradientScrim = Color(0x33000000); // black 20%

  /// The Wallet card's soft green glow under a [primaryGradient] surface.
  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color:      primary.withValues(alpha: 0.35),
      blurRadius: 24,
      offset:     const Offset(0, 8),
    ),
  ];

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