import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Smoky Black / Olive Drab / Bone / Floral White, with a warm sienna
/// accent — a muted, "analog gear" palette. Same four neutrals double up
/// as light and dark themes; only the accent repeats across both.
class AppColors {
  // Base palette
  static const smokyBlack = Color(0xFF11120D);
  static const oliveDrab = Color(0xFF565449);
  static const bone = Color(0xFFD8CFBC);
  static const floralWhite = Color(0xFFFFFBF4);
  static const sienna = Color(
    0xFFA0522D,
  ); // record button / accent — swap to 0xFF8B5A2B for a more muted version

  // Light theme
  static const lightBackground = floralWhite;
  static const lightSurface = bone;
  static const lightText = smokyBlack;
  static const lightAccent = sienna;

  // Dark theme
  static const darkBackground = smokyBlack;
  static const darkSurface = oliveDrab;
  static const darkText = floralWhite;
  static const darkAccent = sienna;

  // Shared status colors (paired with icons, never color alone — see notes app plan)
  static const statusPending = oliveDrab;
  static const statusUploading = Color(0xFF4A90D9);
  static const statusSynced = Color(
    0xFF6B8E4E,
  ); // olive-adjacent green, stays in the muted family
  static const statusFailed = Color(
    0xFFB54A3A,
  ); // warm red-brown, close kin to the sienna accent
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      titleMedium: GoogleFonts.inter(color: AppColors.lightText),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.lightSurface,
        primary: AppColors.lightAccent,
        onSurface: AppColors.lightText,
        // These default to Material 3's baseline purple if left
        // untouched — FloatingActionButton, chips, and some other
        // widgets pull from these, not from `primary` directly.
        primaryContainer: AppColors.lightAccent,
        onPrimaryContainer: Colors.white,
        secondary: AppColors.lightAccent,
        secondaryContainer: AppColors.lightAccent,
        onSecondaryContainer: Colors.white,
      ),
      textTheme: textTheme,
      inputDecorationTheme: _inputTheme(
        fill: AppColors.lightSurface,
        text: AppColors.lightText,
        border: AppColors.lightText.withOpacity(0.15),
        focus: AppColors.lightAccent,
      ),
      elevatedButtonTheme: _buttonTheme(
        background: AppColors.lightAccent,
        foreground: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.lightAccent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      titleMedium: GoogleFonts.inter(color: AppColors.darkText),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.darkSurface,
        primary: AppColors.darkAccent,
        onSurface: AppColors.darkText,
        primaryContainer: AppColors.darkAccent,
        onPrimaryContainer: AppColors.darkBackground,
        secondary: AppColors.darkAccent,
        secondaryContainer: AppColors.darkAccent,
        onSecondaryContainer: AppColors.darkBackground,
      ),
      textTheme: textTheme,
      inputDecorationTheme: _inputTheme(
        fill: AppColors.darkSurface,
        text: AppColors.darkText,
        border: AppColors.darkText.withOpacity(0.15),
        focus: AppColors.darkAccent,
      ),
      elevatedButtonTheme: _buttonTheme(
        background: AppColors.darkAccent,
        foreground: AppColors.darkBackground,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.darkAccent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkAccent,
        foregroundColor: AppColors.darkBackground,
      ),
    );
  }

  static InputDecorationTheme _inputTheme({
    required Color fill,
    required Color text,
    required Color border,
    required Color focus,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1.5]) =>
        OutlineInputBorder(
          borderSide: BorderSide(color: color, width: width),
          borderRadius: BorderRadius.circular(12),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: TextStyle(color: text.withOpacity(0.5)),
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(focus, 2),
      errorBorder: outline(AppColors.statusFailed),
      focusedErrorBorder: outline(AppColors.statusFailed, 2),
    );
  }

  static ElevatedButtonThemeData _buttonTheme({
    required Color background,
    required Color foreground,
  }) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(double.infinity, 56),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
