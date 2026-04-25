import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_color_scheme.dart';
import '../core/theme/theme_provider.dart';
import '../features/cari/presentation/cari_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/gider/presentation/gider_screen.dart';
import '../features/rapor/presentation/rapor_screen.dart';
import '../features/terminal/presentation/terminal_main_screen.dart';
import '../features/urun/presentation/urun_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// APP SHELL — Sol sidebar + içerik alanı
// ══════════════════════════════════════════════════════════════════════════════

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    _NavDest(
      icon:  Icons.point_of_sale_rounded,
      label: 'Satış',
      hint:  'Kasa terminali',
    ),
    _NavDest(
      icon:  Icons.people_alt_rounded,
      label: 'Cariler',
      hint:  'Müşteri & tedarikçi',
    ),
    _NavDest(
      icon:  Icons.money_off_rounded,
      label: 'Giderler',
      hint:  'Masraf yönetimi',
    ),
    _NavDest(
      icon:  Icons.bar_chart_rounded,
      label: 'Dashboard',
      hint:  'Raporlar & özet',
    ),
    _NavDest(
      icon:  Icons.receipt_long_rounded,
      label: 'Raporlar',
      hint:  'Satış geçmişi & analiz',
    ),
    _NavDest(
      icon:  Icons.inventory_2_rounded,
      label: 'Stok',
      hint:  'Ürün yönetimi & CSV aktarım',
    ),
  ];

  // Ekranları cache'leyerek gereksiz rebuild önlenir
  static const _screens = [
    TerminalMainScreen(),
    CariScreen(),
    GiderScreen(),
    DashboardScreen(),
    RaporScreen(),
    UrunScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: Row(
        children: [
          // ── Sol Sidebar ──────────────────────────────────────────────────
          _Sidebar(
            selectedIndex: _selectedIndex,
            destinations:  _destinations,
            onSelect:      (i) => setState(() => _selectedIndex = i),
          ),
          VerticalDivider(width: 1, color: c.border),
          // ── İçerik ───────────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _NavDest {
  final IconData icon;
  final String   label;
  final String   hint;
  const _NavDest({required this.icon, required this.label, required this.hint});
}

class _Sidebar extends StatelessWidget {
  final int               selectedIndex;
  final List<_NavDest>    destinations;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c  = context.colors;
    final tp = context.watch<ThemeProvider>();

    return Container(
      width: 72,
      color: c.bgSecondary,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── Logo ─────────────────────────────────────────────────────────
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.point_of_sale_rounded, size: 22, color: Colors.black),
          ),

          const SizedBox(height: 24),

          // ── Nav öğeleri ───────────────────────────────────────────────────
          ...destinations.asMap().entries.map((entry) {
            final i    = entry.key;
            final dest = entry.value;
            final sel  = i == selectedIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Tooltip(
                message: dest.hint,
                preferBelow: false,
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.teal.withAlpha(22) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? AppColors.teal.withAlpha(60) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          dest.icon,
                          size: 22,
                          color: sel ? AppColors.teal : c.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dest.label,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color:      sel ? AppColors.teal : c.textSecondary,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // ── Tema toggle butonu ────────────────────────────────────────────
          Tooltip(
            message: tp.isDark ? 'Açık Temaya Geç' : 'Koyu Temaya Geç',
            preferBelow: false,
            child: InkWell(
              onTap: () => tp.toggle(),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      RotationTransition(
                        turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                  child: Icon(
                    tp.isDark
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    key: ValueKey(tp.isDark),
                    size: 20,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ),
          ),

          // ── Versiyon ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Text(
              'v2.0',
              style: GoogleFonts.dmMono(color: c.textMuted, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}
