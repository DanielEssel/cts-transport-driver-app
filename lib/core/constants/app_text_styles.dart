// core/constants/app_text_styles.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // ============================================
  // HEADING STYLES (32px - 20px)
  // ============================================

  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryColor,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryColor,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.4,
  );

  static const TextStyle heading4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  // ============================================
  // BODY TEXT STYLES
  // ============================================

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  // ============================================
  // BUTTON TEXT STYLES
  // ============================================

  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.backgroundColor,
    height: 1.5,
    letterSpacing: 0.3,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.backgroundColor,
    height: 1.5,
    letterSpacing: 0.2,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.backgroundColor,
    height: 1.5,
  );

  // ============================================
  // CAPTION & LABEL STYLES
  // ============================================

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  static const TextStyle captionSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textDisabledColor,
    height: 1.6,
  );

  static const TextStyle captionLarge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  // ============================================
  // LABEL STYLES (Form Fields)
  // ============================================

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  // ============================================
  // HELPER TEXT STYLES
  // ============================================

  static const TextStyle helperText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  static const TextStyle errorText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.errorColor,
    height: 1.5,
  );

  static const TextStyle successText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.successColor,
    height: 1.5,
  );

  // ============================================
  // LINK & INTERACTIVE TEXT
  // ============================================

  static const TextStyle linkText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryColor,
    decoration: TextDecoration.underline,
    height: 1.5,
  );

  static const TextStyle linkMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryColor,
    decoration: TextDecoration.underline,
    height: 1.5,
  );

  // ============================================
  // SUBTITLE & DESCRIPTION TEXT
  // ============================================

  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.5,
  );

  static const TextStyle subtitleSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  static const TextStyle description = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  // ============================================
  // SCREEN-SPECIFIC STYLES
  // ============================================

  // Splash Screen
  static const TextStyle splashTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.backgroundColor,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle splashSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.backgroundColor,
    height: 1.5,
  );

  // Onboarding Screen
  static const TextStyle onboardingTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.4,
  );
  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.4,
  );

  static const TextStyle onboardingSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  static const TextStyle onboardingSkipButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryColor,
    height: 1.5,
  );

  // Auth Screens (Login, Signup, OTP)
  static const TextStyle authTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.4,
  );

  static const TextStyle authSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.5,
  );

  static const TextStyle authHint = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.5,
  );

  // Form Input Labels
  static const TextStyle inputLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle inputHint = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textDisabledColor,
    height: 1.5,
  );

  // OTP Screen
  static const TextStyle otpTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.4,
  );

  static const TextStyle otpSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  static const TextStyle otpDigitField = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle otpResendText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  // Role Selection Screen
  static const TextStyle roleTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.4,
  );

  static const TextStyle roleSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  static const TextStyle roleCardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle roleCardDescription = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  // ============================================
  // RIDER HOME SCREEN STYLES
  // ============================================

  static const TextStyle riderGreeting = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle riderStatus = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  static const TextStyle quickActionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  // ============================================
  // DRIVER HOME SCREEN STYLES
  // ============================================

  static const TextStyle driverGreeting = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle driverStats = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle driverStatsValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryColor,
    height: 1.4,
  );

  static const TextStyle requestCard = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  // ============================================
  // RIDE/DELIVERY CARDS & LISTS
  // ============================================

  static const TextStyle cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  static const TextStyle cardPrice = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryColor,
    height: 1.5,
  );

  static const TextStyle statusBadge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.backgroundColor,
    height: 1.4,
  );

  // ============================================
  // WALLET & TRANSACTION STYLES
  // ============================================

  static const TextStyle walletBalance = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryColor,
    height: 1.2,
  );

  static const TextStyle transactionAmount = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle transactionType = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  static const TextStyle transactionDate = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textDisabledColor,
    height: 1.6,
  );

  // ============================================
  // MODAL & DIALOG STYLES
  // ============================================

  static const TextStyle dialogTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle dialogContent = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  // ============================================
  // BADGE & CHIP STYLES
  // ============================================

  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.backgroundColor,
    height: 1.4,
  );

  static const TextStyle chip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  // ============================================
  // EMPTY STATE STYLES
  // ============================================

  static const TextStyle emptyStateTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle emptyStateMessage = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  // ============================================
  // TIMESTAMP & METADATA STYLES
  // ============================================

  static const TextStyle timestamp = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textDisabledColor,
    height: 1.5,
  );

  static const TextStyle metadata = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.6,
  );

  // ============================================
  // TAB & NAVIGATION STYLES
  // ============================================

  static const TextStyle tabActive = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryColor,
    height: 1.5,
  );

  static const TextStyle tabInactive = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryColor,
    height: 1.5,
  );

  static const TextStyle bottomNavLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimaryColor,
    height: 1.4,
  );
}
