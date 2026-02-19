import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/nlc_palette.dart';

/// Design tokens for NLC 2026 check-in. Colors delegate to [NlcPalette].
class AppColors {
  AppColors._();

  static const Color white = NlcPalette.white;
  static const Color surfaceCard = NlcPalette.cream2;
  static const Color sessionDropdownBg = Color(0xFFE4E1DC);
  static const Color statusNotCheckedIn = NlcPalette.brandBlueSoft;
  static const Color statusCheckedIn = NlcPalette.success;
  static const Color textPrimary = NlcPalette.ink;
  static const Color textPrimary87 = NlcPalette.ink;
  static const Color navy = NlcPalette.brandBlueDark;
  static const Color chevronNavy = NlcPalette.brandBlueDark;
  static const Color liveBadgeGreen = NlcPalette.success;

  // Accent (blue palette — replaces gold)
  static const Color accent = NlcPalette.brandBlue;
  static const Color accentSoft = NlcPalette.brandBlueSoft;
  static const Color accentDark = NlcPalette.brandBlueDark;
}

class AppSpacing {
  AppSpacing._();

  static const double horizontal = 24;
  static const double horizontalDivider = 40;
  static const double afterHeader = 32;
  static const double betweenSections = 32;
  static const double belowSubtitle = 24;
  static const double betweenTitleAddress = 16;
  static const double insideCards = 16;
  static const double primaryCardPadding = 20;
  static const double secondaryCardPadding = 18;
  static const double betweenSecondaryCards = 20;
  static const double betweenSectionTitleAndCards = 16;
  static const double aboveSectionTitle = 24;
  static const double headerLogoTextGap = 20;
  static const double headerTitleYearGap = 12;
  static const double iconSpacing = 8;
  static const double iconTextSpacing = 16;
  static const double footerTop = 32;
}

class AppTypography {
  AppTypography._();

  static const double headerTitleFontSize = 30.6;
  static const double headerMainTitleFontSize = 28;
  static const double headerYearFontSize = 22;

  static TextStyle headerTitle(BuildContext context) =>
      GoogleFonts.playfairDisplay(
        fontSize: headerTitleFontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: NlcPalette.white,
      );

  static TextStyle headerTitleAccent(BuildContext context) =>
      GoogleFonts.playfairDisplay(
        fontSize: headerTitleFontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: NlcPalette.cream,
      );

  static TextStyle headerMainTitle(BuildContext context) =>
      GoogleFonts.playfairDisplay(
        fontSize: headerMainTitleFontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.4,
        color: NlcPalette.cream,
      );

  static TextStyle headerYear(BuildContext context) =>
      GoogleFonts.playfairDisplay(
        fontSize: headerYearFontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: NlcPalette.cream,
      );

  static TextStyle subtitle(BuildContext context) =>
      GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: NlcPalette.cream,
      );

  static TextStyle locationVenue(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: NlcPalette.cream,
      );

  static TextStyle locationAddress(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: NlcPalette.cream.withValues(alpha: 0.9),
      );

  static TextStyle primaryCardTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: NlcPalette.ink,
      );

  static TextStyle primaryCardSubtitle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: NlcPalette.muted,
      );

  static TextStyle secondaryCardTitle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: NlcPalette.ink,
      );

  static TextStyle secondaryCardSubtitle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: NlcPalette.muted,
      );

  static TextStyle footer(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: NlcPalette.cream.withValues(alpha: 0.85),
      );

  static TextStyle footerBold(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: NlcPalette.cream.withValues(alpha: 0.85),
      );

  static TextStyle sessionDropdown(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: NlcPalette.muted,
      );
}
