import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for NLC 2026 check-in — pixel-accurate, no magic numbers.
class AppColors {
  AppColors._();

  static const Color white = Colors.white;
  static const Color gold = Color(0xFFF2B233);
  static const Color goldDivider = Color(0xFFD6A52C);
  static const Color goldGradientStart = Color(0xFFF6C357);
  static const Color goldGradientEnd = Color(0xFFD89A1D);
  static const Color goldIconContainer = Color(0xFFCC8F1A);
  static const Color surfaceCard = Color(0xFFF8F6F2);
  static const Color sessionDropdownBg = Color(0xFFE4E1DC);
  static const Color statusNotCheckedIn = Color(0xFFF0D78C);
  static const Color statusCheckedIn = Color(0xFF2E7D32);
  static const Color textPrimary = Colors.black;
  static const Color textPrimary87 = Colors.black87;
  static const Color navy = Color(0xFF1C3D5A);
}

class AppSpacing {
  AppSpacing._();

  static const double horizontal = 24;
  static const double horizontalDivider = 40;
  static const double afterHeader = 32;
  static const double betweenSections = 24;
  static const double belowSubtitle = 24;
  static const double betweenTitleAddress = 16;
  static const double insideCards = 16;
  static const double primaryCardPadding = 20;
  static const double secondaryCardPadding = 18;
  static const double betweenSecondaryCards = 18;
  static const double iconSpacing = 8;
  static const double iconTextSpacing = 16;
  static const double footerTop = 32;
}

class AppTypography {
  AppTypography._();

  /// 10% smaller than original 34 for better fit on mobile.
  static const double headerTitleFontSize = 30.6;

  static TextStyle headerTitle(BuildContext context) =>
      GoogleFonts.playfairDisplay(
        fontSize: headerTitleFontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.white,
      );

  static TextStyle headerTitleGold(BuildContext context) =>
      GoogleFonts.playfairDisplay(
        fontSize: headerTitleFontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.gold,
      );

  static TextStyle subtitle(BuildContext context) =>
      GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.gold,
      );

  static TextStyle locationVenue(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.white,
      );

  static TextStyle locationAddress(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.white.withValues(alpha: 0.8),
      );

  static TextStyle primaryCardTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle primaryCardSubtitle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary87,
      );

  static TextStyle secondaryCardTitle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle secondaryCardSubtitle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary87,
      );

  static TextStyle footer(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.gold,
      );

  static TextStyle footerBold(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.gold,
      );

  static TextStyle sessionDropdown(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary87,
      );
}
