import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AppColorScheme — ThemeExtension ile her ThemeData'ya gömülü semantik renkler
//
// Brand renkleri (teal, gold, accentRed…) AppColors'ta sabit kalır.
// Değişen renkler (bgPrimary, textSecondary, border…) buradan gelir.
// Kullanım: context.colors.bgCard   →   BuildContext extension (en alta bakın)
// ══════════════════════════════════════════════════════════════════════════════

@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgCard,
    required this.bgTertiary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderLight,
    required this.inputFill,
    required this.divider,
  });

  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgCard;
  final Color bgTertiary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderLight;
  final Color inputFill;
  final Color divider;

  // ── Dark palette (orijinal Liqra Terminal karanlık teması) ─────────────────
  static const dark = AppColorScheme(
    bgPrimary:     Color(0xFF05080F),
    bgSecondary:   Color(0xFF0C1018),
    bgCard:        Color(0xFF111520),
    bgTertiary:    Color(0xFF161B26),
    textPrimary:   Color(0xFFEEF2FF),
    textSecondary: Color(0xFF6B7280),
    textMuted:     Color(0xFF374151),
    border:        Color(0xFF1F2937),
    borderLight:   Color(0xFF374151),
    inputFill:     Color(0xFF111520),
    divider:       Color(0xFF1F2937),
  );

  // ── Light palette (esnaf dostu açık tema) ─────────────────────────────────
  // Arka plan: nötr beyaz/gri  |  Teal aksan: #00BFA5  |  Metin: koyu lacivert
  static const light = AppColorScheme(
    bgPrimary:     Color(0xFFF5F7FA),
    bgSecondary:   Color(0xFFFFFFFF),
    bgCard:        Color(0xFFFFFFFF),
    bgTertiary:    Color(0xFFECEFF4),
    textPrimary:   Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted:     Color(0xFFCBD5E1),
    border:        Color(0xFFE2E8F0),
    borderLight:   Color(0xFFF1F5F9),
    inputFill:     Color(0xFFFFFFFF),
    divider:       Color(0xFFE2E8F0),
  );

  // ── ThemeExtension API ─────────────────────────────────────────────────────

  @override
  AppColorScheme copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? bgCard,
    Color? bgTertiary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderLight,
    Color? inputFill,
    Color? divider,
  }) =>
      AppColorScheme(
        bgPrimary:     bgPrimary     ?? this.bgPrimary,
        bgSecondary:   bgSecondary   ?? this.bgSecondary,
        bgCard:        bgCard        ?? this.bgCard,
        bgTertiary:    bgTertiary    ?? this.bgTertiary,
        textPrimary:   textPrimary   ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted:     textMuted     ?? this.textMuted,
        border:        border        ?? this.border,
        borderLight:   borderLight   ?? this.borderLight,
        inputFill:     inputFill     ?? this.inputFill,
        divider:       divider       ?? this.divider,
      );

  @override
  AppColorScheme lerp(AppColorScheme? other, double t) {
    if (other == null) return this;
    return AppColorScheme(
      bgPrimary:     Color.lerp(bgPrimary,     other.bgPrimary,     t)!,
      bgSecondary:   Color.lerp(bgSecondary,   other.bgSecondary,   t)!,
      bgCard:        Color.lerp(bgCard,        other.bgCard,        t)!,
      bgTertiary:    Color.lerp(bgTertiary,    other.bgTertiary,    t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:     Color.lerp(textMuted,     other.textMuted,     t)!,
      border:        Color.lerp(border,        other.border,        t)!,
      borderLight:   Color.lerp(borderLight,   other.borderLight,   t)!,
      inputFill:     Color.lerp(inputFill,     other.inputFill,     t)!,
      divider:       Color.lerp(divider,       other.divider,       t)!,
    );
  }
}

// ── BuildContext extension — tüm widget'larda `context.colors.bgCard` gibi ──
extension AppColorSchemeX on BuildContext {
  AppColorScheme get colors =>
      Theme.of(this).extension<AppColorScheme>()!;
}
