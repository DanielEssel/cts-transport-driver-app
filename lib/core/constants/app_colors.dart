// lib/core/constants/app_colors.dart

import 'package:flutter/material.dart';

/// CTS Transport — Brand Color System
/// Primary: Forest Green  |  Base: Clean White  |  Accent: Emerald
class AppColors {
  // ── Brand Core ────────────────────────────────────────────────────────────

  /// Primary green — buttons, active states, key UI elements
  static const Color primary = Color(0xFF16A34A); // Forest Green
  static const Color primaryDark = Color(0xFF15803D); // Deep Forest
  static const Color primaryDarker = Color(0xFF166534); // Darkest Forest
  static const Color primaryLight = Color(0xFF22C55E); // Bright Emerald
  static const Color primaryLighter = Color(0xFF4ADE80); // Light Emerald

  /// Legacy aliases — kept for backward compatibility
  static const Color primaryColor = Color(0xFF16A34A);
  static const Color primaryLightColor = Color(0xFF22C55E);
  static const Color primaryDarkColor = Color(0xFF166534);
  static const Color primaryColors = Color(0xFF16A34A);

  // ── Brand Tints (backgrounds, cards, chips) ───────────────────────────────

  static const Color primaryDim = Color(0xFFF0FDF4); // Very light green bg
  static const Color primarySubtle = Color(0xFFDCFCE7); // Subtle green tint
  static const Color primaryMuted = Color(0xFFBBF7D0); // Muted green border

  // ── Surfaces ──────────────────────────────────────────────────────────────

  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAF9); // Off-white w/ green tint
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0FDF4); // Light green surface
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// Legacy
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color backgroundLightColor = Color(0xFFF8FAF9);
  static const Color backgroundDarkColor = Color(0xFFF0FDF4);

  // ── Dark Surfaces (map, overlays) ─────────────────────────────────────────

  static const Color darkNavy = Color(0xFF052E16); // Deep green-black
  static const Color darkBlue = Color(0xFF14532D); // Dark forest
  static const Color deepBlue = Color(0xFF15803D); // Rich green
  static const Color darkBackground = Color(0xFF052E16);

  // ── Borders ───────────────────────────────────────────────────────────────

  static const Color border = Color(0xFFE2F0E8); // Subtle green border
  static const Color borderLight = Color(0xFFF0FDF4); // Very light border
  static const Color borderColor = Color(0xFFD1FAE5); // Soft green border
  static const Color dividerColor = Color(0xFFBBF7D0); // Divider

  // ── Text ──────────────────────────────────────────────────────────────────

  static const Color textPrimary = Color(0xFF052E16); // Near black green
  static const Color textPrimaryColor = Color(0xFF052E16);
  static const Color textSecondary = Color(0xFF4B7A5C); // Muted green-grey
  static const Color textSecondaryColor = Color(0xFF4B7A5C);
  static const Color textTertiary = Color(0xFF86A994); // Light green-grey
  static const Color textDisabledColor = Color(0xFFB8D4C1); // Disabled
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkMuted = Color(0xFFBBF7D0);
  static const Color textHint = Color(0xFF86A994);

  // ── Status ────────────────────────────────────────────────────────────────

  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successColor = Color(0xFF16A34A);

  static const Color warning = Color(0xFFD97706); // Warm amber
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningColor = Color(0xFFD97706);

  static const Color error = Color(0xFFDC2626); // Clear red
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorColor = Color(0xFFDC2626);

  static const Color info = Color(0xFF0284C7); // Teal-blue (complements green)
  static const Color infoLight = Color(0xFFE0F2FE);

  static const Color pendingColor = Color(0xFFD97706);

  // ── Accents ───────────────────────────────────────────────────────────────

  static const Color accentGreen = Color(0xFF4ADE80); // Bright accent
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentGold = Color(0xFFF59E0B); // Premium gold accent

  // ── Map ───────────────────────────────────────────────────────────────────

  static const Color mapRoad = Color(0xFF1A2E1E); // Dark green road
  static const Color mapRoadLight = Color(0xFF2D4A32); // Lighter road

  // Add to AppColors class:
  static const Color goldAccent = Color(0xFFF59E0B); // Premium gold
  static const Color darkSurface = Color(0xFF14532D); // Dark green surface

  // ── Gradients ─────────────────────────────────────────────────────────────

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF15803D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF15803D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF0FDF4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF052E16), Color(0xFF166534)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
