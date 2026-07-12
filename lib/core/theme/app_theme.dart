import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  static TextTheme _buildTextTheme(
    TextTheme base,
    Color primaryColor,
    Color secondaryColor, {
    Color? headlineColor,
  }) {
    final hColor = headlineColor ?? primaryColor;
    return base.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        textStyle: base.displayLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: hColor,
        ),
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        textStyle: base.displayMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: hColor,
        ),
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        textStyle: base.displaySmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: hColor,
        ),
      ),
      headlineLarge: GoogleFonts.playfairDisplay(
        textStyle: base.headlineLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: hColor,
        ),
      ),
      headlineMedium: GoogleFonts.inter(
        textStyle: base.headlineMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: hColor,
        ),
      ),
      headlineSmall: GoogleFonts.inter(
        textStyle: base.headlineSmall?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: hColor,
        ),
      ),
      titleLarge: GoogleFonts.inter(
        textStyle: base.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ),
      titleMedium: GoogleFonts.inter(
        textStyle: base.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ),
      titleSmall: GoogleFonts.inter(
        textStyle: base.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ),
      bodyLarge: GoogleFonts.inter(
        textStyle: base.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: primaryColor,
        ),
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: base.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: primaryColor,
        ),
      ),
      bodySmall: GoogleFonts.inter(
        textStyle: base.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: secondaryColor,
        ),
      ),
      labelLarge: GoogleFonts.inter(
        textStyle: base.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
      labelMedium: GoogleFonts.inter(
        textStyle: base.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: secondaryColor,
        ),
      ),
      labelSmall: GoogleFonts.inter(
        textStyle: base.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: secondaryColor,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTheme = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: Color(0xFFFFFFFF), // pure white
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnAccent,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textOnPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFFFFFF), // pure white
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFFFFFFFF),
        elevation: AppConstants.elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: AppConstants.elevationLow,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(
            AppConstants.minTouchTarget,
            AppConstants.minTouchTarget,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.buttonBorderRadius,
            ),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(
            AppConstants.minTouchTarget,
            AppConstants.minTouchTarget,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.buttonBorderRadius,
            ),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
      ),
      textTheme: _buildTextTheme(
        baseTheme.textTheme,
        AppColors.textPrimary,
        AppColors.textSecondary,
      ),
      iconTheme: const IconThemeData(color: AppColors.primary, size: 24),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: AppConstants.elevationMedium,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(color: AppColors.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark();
    // Warm dark surfaces — pure black would clash with the heritage brand;
    // pure #121212 makes cards disappear. surface sits one tonal step above
    // the scaffold, surfaceContainer two steps, surfaceContainerHigh three.
    const darkScaffold = AppColors.darkScaffold; //   #121212
    const darkSurface = AppColors.darkSurface; //       #1E1E1E
    const darkSurfaceContainer = AppColors.darkSurfaceContainer; // #262220
    const darkSurfaceContainerHigh = AppColors.darkSurfaceContainerHigh; // #2E2924
    const textPrimaryDark = AppColors.darkBody; //  #F0EAE0 — AAA on darkSurface
    const textSecondaryDark = AppColors.darkMuted; // #D7C7B6 — AA on darkSurface
    const headlineDark = Color(0xFFF5F0E8); // brighter still for hero/headline copy
    const borderDark = AppColors.darkBorder; // #3A312A — warm, visible on dark

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryLight,
      scaffoldBackgroundColor: darkScaffold,
      // surfaceTint drives M3's tonal-elevation lifts for cards, dialogs,
      // sheets. Without it, every card paints flat on the scaffold and the
      // hierarchy collapses. Tied to the brand's primaryDark so the lift
      // feels warm, not grey.
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: AppColors.darkOnPrimary,
        primaryContainer: AppColors.primaryDark,
        onPrimaryContainer: AppColors.darkBody,
        secondary: AppColors.accent,
        onSecondary: AppColors.darkOnAccent,
        secondaryContainer: AppColors.primaryDark,
        onSecondaryContainer: AppColors.darkBody,
        tertiary: AppColors.accentLight,
        onTertiary: AppColors.darkOnAccent,
        error: AppColors.darkError,
        onError: AppColors.textOnPrimary,
        surface: darkSurface,
        onSurface: textPrimaryDark,
        // onSurfaceVariant covers body-secondary / hint text in M3.
        onSurfaceVariant: textSecondaryDark,
        // outline / outlineVariant drive borders & dividers in M3 component
        // themes (input, card, divider) when we wire them below.
        outline: borderDark,
        outlineVariant: Color(0xFF2E2924),
        // Tonal elevation slots — surfaces layered above [surface].
        surfaceContainerLowest: darkScaffold,
        surfaceContainerLow: Color(0xFF1A1A1A),
        surfaceContainer: darkSurfaceContainer,
        surfaceContainerHigh: darkSurfaceContainerHigh,
        surfaceContainerHighest: Color(0xFF36312C),
        surfaceTint: AppColors.darkSurfaceTint,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      // Cards lift one tonal step above the scaffold via surfaceContainer —
      // shadows are barely visible on a warm dark surface, so tonal elevation
      // is the M3-correct way to express hierarchy here.
      cardTheme: CardTheme(
        color: darkSurfaceContainer,
        surfaceTintColor: AppColors.darkSurfaceTint,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.darkOnPrimary,
          elevation: AppConstants.elevationLow,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(
            AppConstants.minTouchTarget,
            AppConstants.minTouchTarget,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.buttonBorderRadius,
            ),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(
            AppConstants.minTouchTarget,
            AppConstants.minTouchTarget,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.buttonBorderRadius,
            ),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.darkError),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondaryDark, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: AppColors.darkHint, fontSize: 14),
      ),
      textTheme: _buildTextTheme(
        baseTheme.textTheme,
        textPrimaryDark,
        textSecondaryDark,
        headlineColor: headlineDark,
      ),
      iconTheme: const IconThemeData(color: AppColors.primaryLight, size: 24),
      // FAB stays warm-brown in dark mode (matches the brand); the on-color
      // is darkBody so the glyph is readable on the warm button face.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.darkOnPrimary,
        elevation: AppConstants.elevationMedium,
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
        space: 1,
      ),
      // Snackbars on dark mode use inverseSurface so they pop off the warm
      // scaffold. Default behavior (darkSurface fill, darkBody text) had the
      // snackbar blending into the background.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceContainerHigh,
        contentTextStyle: GoogleFonts.inter(color: textPrimaryDark),
        actionTextColor: AppColors.primaryLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: darkSurfaceContainerHigh,
        surfaceTintColor: AppColors.darkSurfaceTint,
        titleTextStyle: GoogleFonts.inter(
          color: headlineDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: textPrimaryDark,
          fontSize: 14,
        ),
      ),
    );
  }
}
