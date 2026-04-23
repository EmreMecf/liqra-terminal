import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Backgrounds ─────────────────────────────────────────────────────────────
  static const bgPrimary   = Color(0xFF05080F);
  static const bgSecondary = Color(0xFF0C1018);
  static const bgCard      = Color(0xFF111520);
  static const bgTertiary  = Color(0xFF161B26);

  // ── Brand ───────────────────────────────────────────────────────────────────
  static const teal        = Color(0xFF0AFFE0);
  static const tealDark    = Color(0xFF00BFA5);
  static const gold        = Color(0xFFE4B84A);
  static const accentRed   = Color(0xFFFF4D6D);
  static const accentGreen = Color(0xFF2ECC71);

  // ── Text ────────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFFEEF2FF);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF374151);

  // ── Border ──────────────────────────────────────────────────────────────────
  static const border      = Color(0xFF1F2937);
  static const borderLight = Color(0xFF374151);

  // ── Gradients ───────────────────────────────────────────────────────────────
  static const tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, tealDark],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, Color(0xFFB8860B)],
  );

  // ── Category Colors ──────────────────────────────────────────────────────────
  static const categoryColors = [
    Color(0xFF0AFFE0),
    Color(0xFFE4B84A),
    Color(0xFFFF4D6D),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFEA580C),
    Color(0xFFDB2777),
  ];
}
