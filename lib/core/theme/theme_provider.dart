import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ThemeProvider — tema tercihini yönetir ve SharedPreferences'a kaydeder
//
// Kullanım:
//   context.read<ThemeProvider>().toggle();
//   context.watch<ThemeProvider>().mode   → ThemeMode
//   context.watch<ThemeProvider>().isDark → bool
// ══════════════════════════════════════════════════════════════════════════════

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.dark; // varsayılan: karanlık

  ThemeMode get mode   => _mode;
  bool get isDark      => _mode == ThemeMode.dark;

  // main()'de çağrılır — kaydedilmiş tercihi yükler
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'light') {
      _mode = ThemeMode.light;
    } else {
      _mode = ThemeMode.dark;
    }
    notifyListeners();
  }

  // Karanlık ↔ Açık geçişi
  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, isDark ? 'dark' : 'light');
  }

  // İstenirse doğrudan mod ayarla
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
