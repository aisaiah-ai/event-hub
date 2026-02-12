import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Event Hub design system — premium conference platform aesthetic.
/// Deep slate with warm amber accents, editorial typography.
class AppTheme {
  AppTheme._();

  // Brand palette
  static const Color _slate900 = Color(0xFF0f172a);
  static const Color _slate800 = Color(0xFF1e293b);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate400 = Color(0xFF94a3b8);
  static const Color _slate200 = Color(0xFFe2e8f0);
  static const Color _slate100 = Color(0xFFf1f5f9);
  static const Color _white = Color(0xFFfafbfc);

  static const Color _amber500 = Color(0xFFf59e0b);
  static const Color _rose500 = Color(0xFFf43f5e);

  /// Hero gradient colors (night-sky / desert-dusk)
  static const Color heroDark = Color(0xFF0f172a);
  static const Color heroMid = Color(0xFF1e1b4b);
  static const Color heroWarm = Color(0xFF422006);
  static const Color contentDark = Color(0xFF1e293b); // charcoal block
  static const Color contentLight = Color(0xFFfafbfc); // light panels

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _slate800,
        onPrimary: _white,
        secondary: _amber500,
        onSecondary: _slate900,
        surface: _white,
        onSurface: _slate800,
        surfaceContainerHighest: _slate100,
        error: _rose500,
        outline: _slate200,
      ),
      scaffoldBackgroundColor: _slate100,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: _white,
        foregroundColor: _slate800,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _slate800,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: _slate600, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _slate800,
          foregroundColor: _white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _slate800,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: _slate200),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: _amber500,
          foregroundColor: _slate900,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _slate600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.outfit(color: _slate400, fontSize: 15),
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: _slate800,
          letterSpacing: -1,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _slate800,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _slate800,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          color: _slate700,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          color: _slate600,
          height: 1.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _slate200,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _slate100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
