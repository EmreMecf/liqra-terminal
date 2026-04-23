import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../features/cari/presentation/cari_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/gider/presentation/gider_screen.dart';
import '../features/terminal/presentation/terminal_main_screen.dart';

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
  ];

  // Ekranları cache'leyerek gereksiz rebuild önlenir
  static const _screens = [
    TerminalMainScreen(),
    CariScreen(),
    GiderScreen(),
    DashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Row(
        children: [
          // ── Sol Sidebar ──────────────────────────────────────────────────
          _Sidebar(
            selectedIndex: _selectedIndex,
            destinations:  _destinations,
            onSelect:      (i) => setState(() => _selectedIndex = i),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
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
  final int              selectedIndex;
  final List<_NavDest>   destinations;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: AppColors.bgSecondary,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Logo
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.point_of_sale_rounded, size: 22, color: Colors.black),
          ),

          const SizedBox(height: 24),

          // Nav öğeleri
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
                        color: sel ? AppColors.teal.withAlpha(60) : Colors.transparent),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          dest.icon,
                          size: 22,
                          color: sel ? AppColors.teal : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dest.label,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: sel ? AppColors.teal : AppColors.textSecondary,
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

          // Versiyon
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('v1.0',
              style: GoogleFonts.dmMono(
                color: AppColors.textMuted, fontSize: 9)),
          ),
        ],
      ),
    );
  }
}
