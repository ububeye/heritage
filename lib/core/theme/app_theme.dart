import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_radius.dart';
import 'app_semantic_colors.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  /// Seeds the M3 tonal palette from the brand coral. Caller can override
  /// the secondary brand colour with a tint of the navy accent.
  static ColorScheme _lightScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppPalette.coral500,
      brightness: Brightness.light,
      secondary: AppPalette.navy500,
      tertiary: AppPalette.sky500,
      error: AppPalette.red600,
      surface: AppPalette.warmSurface,
    );
  }

  static ColorScheme _darkScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppPalette.coral500,
      brightness: Brightness.dark,
      secondary: AppPalette.navy300,
      tertiary: AppPalette.sky300,
      error: AppPalette.red400,
      surface: AppPalette.charcoal900,
    );
  }

  /// App-specific roles for the light theme. Map colours and image-overlay
  /// foregrounds are deliberately fixed-content — they don't shift with
  /// the theme.
  static const AppSemanticColors _lightSemantic = AppSemanticColors(
    success: AppPalette.green700,
    onSuccess: AppPalette.fixedWhite,
    warning: AppPalette.orange700,
    onWarning: AppPalette.fixedWhite,
    info: AppPalette.sky700,
    onInfo: AppPalette.fixedWhite,
    rating: AppPalette.amber500,
    mapRoute: AppPalette.navy500,
    mapUser: AppPalette.sky700,
    mapMarker: AppPalette.coral500,
    onImage: AppPalette.fixedWhite,
    onImageMuted: Color(0xCCFFFFFF),
    imageScrim: Color(0x99000000),
    shadow: Color(0x0D000000),
  );

  static const AppSemanticColors _darkSemantic = AppSemanticColors(
    success: AppPalette.green700,
    onSuccess: AppPalette.fixedWhite,
    warning: AppPalette.orange700,
    onWarning: AppPalette.fixedWhite,
    info: AppPalette.sky300,
    onInfo: AppPalette.fixedWhite,
    rating: AppPalette.amber500,
    mapRoute: AppPalette.navy300,
    mapUser: AppPalette.sky300,
    mapMarker: AppPalette.coral300,
    onImage: AppPalette.fixedWhite,
    onImageMuted: Color(0xCCFFFFFF),
    imageScrim: Color(0x99000000),
    shadow: Color(0x14FFFFFF),
  );

  static ThemeData get lightTheme {
    final scheme = _lightScheme();
    final baseTheme = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scheme.surface,
      colorScheme: scheme,
      // App-specific semantic roles. Read via `context.semanticColors`.
      extensions: const <ThemeExtension<dynamic>>[_lightSemantic],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 2,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      cardTheme: CardTheme(
        color: scheme.surface,
        elevation: AppShadows.elevationLow,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: AppShadows.elevationLow,
          padding: AppInsets.buttonTall,
          minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          padding: AppInsets.buttonTall,
          minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.buttonBorder,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonBorder,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonBorder,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonBorder,
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: GoogleFonts.inter(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.inter(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      textTheme: AppTextStyles.buildTextTheme(
        baseTheme.textTheme,
        scheme.onSurface,
        scheme.onSurfaceVariant,
      ),
      iconTheme: IconThemeData(color: scheme.primary, size: AppSpacing.lg),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: AppShadows.elevationMedium,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.onSurface,
        contentTextStyle: GoogleFonts.inter(color: scheme.surface),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.buttonBorder,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final scheme = _darkScheme();
    final baseTheme = ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scheme.surface,
      colorScheme: scheme,
      extensions: const <ThemeExtension<dynamic>>[_darkSemantic],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        elevation: 2,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      cardTheme: CardTheme(
        color: scheme.surfaceContainer,
        surfaceTintColor: scheme.surfaceTint,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: AppShadows.elevationLow,
          padding: AppInsets.buttonTall,
          minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          padding: AppInsets.buttonTall,
          minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.buttonBorder,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonBorder,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonBorder,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonBorder,
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: GoogleFonts.inter(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.inter(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      textTheme: AppTextStyles.buildTextTheme(
        baseTheme.textTheme,
        scheme.onSurface,
        scheme.onSurfaceVariant,
      ),
      iconTheme: IconThemeData(color: scheme.primary, size: AppSpacing.lg),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: AppShadows.elevationMedium,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: GoogleFonts.inter(color: scheme.onSurface),
        actionTextColor: scheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.buttonBorder,
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: scheme.surfaceTint,
        titleTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 14,
        ),
      ),
    );
  }
}
