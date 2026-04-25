import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AppColors — Liqra brand renkleri (tema bağımsız, her zaman aynı)
//
// Arka plan / metin / çizgi renkleri buraya GELMEZ.
// Bunlar AppColorScheme'de tanımlıdır → context.colors.bgCard vb.
// ══════════════════════════════════════════════════════════════════════════════

abstract class AppColors {
  // ── Brand ───────────────────────────────────────────────────────────────────
  static const teal        = Color(0xFF0AFFE0);
  static const tealDark    = Color(0xFF00BFA5);
  static const gold        = Color(0xFFE4B84A);
  static const accentRed   = Color(0xFFFF4D6D);
  static const accentGreen = Color(0xFF2ECC71);

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

  // ── Grafik / kategori renk paleti ────────────────────────────────────────────
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
