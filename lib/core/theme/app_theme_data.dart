import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'app_color_scheme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AppThemeData — light() ve dark() ThemeData fabrikaları
//
// MaterialApp:
//   theme:      AppThemeData.light()
//   darkTheme:  AppThemeData.dark()
//   themeMode:  themeProvider.mode
// ══════════════════════════════════════════════════════════════════════════════

abstract class AppThemeData {
  AppThemeData._();

  // ── Açık tema ──────────────────────────────────────────────────────────────
  static ThemeData light() => _build(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary:   AppColors.tealDark,      // #00BFA5 — beyaz üstünde okunur
          secondary: AppColors.gold,
          surface:   Colors.white,
          error:     AppColors.accentRed,
          onPrimary: Colors.white,
          onSurface: const Color(0xFF0F172A),
        ),
        ext: AppColorScheme.light,
      );

  // ── Koyu tema (varsayılan) ─────────────────────────────────────────────────
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary:   AppColors.teal,
          secondary: AppColors.gold,
          surface:   Color(0xFF111520),
          error:     AppColors.accentRed,
        ),
        ext: AppColorScheme.dark,
      );

  // ── İç fabrika ─────────────────────────────────────────────────────────────
  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required AppColorScheme ext,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: ext.bgPrimary,
      colorScheme: colorScheme,

      // AppColorScheme ThemeExtension olarak gömülür
      extensions: [ext],

      // Typography
      textTheme: GoogleFonts.outfitTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).apply(
        bodyColor:       ext.textPrimary,
        displayColor:    ext.textPrimary,
      ),

      // Input alanları
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: ext.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ext.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ext.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.teal : AppColors.tealDark,
          ),
        ),
        hintStyle: GoogleFonts.outfit(color: ext.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: ext.bgCard,
        selectedColor:   AppColors.teal.withAlpha(40),
        side: BorderSide(color: ext.border),
        labelStyle: GoogleFonts.outfit(color: ext.textSecondary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color:     ext.divider,
        thickness: 0.5,
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        indicatorColor:       isDark ? AppColors.teal : AppColors.tealDark,
        labelColor:           isDark ? AppColors.teal : AppColors.tealDark,
        unselectedLabelColor: ext.textSecondary,
        labelStyle:           GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: ext.bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Card
      cardTheme: CardThemeData(
        color: ext.bgCard,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ext.border, width: 0.5),
        ),
      ),
    );
  }
}
