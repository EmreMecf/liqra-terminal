import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_colors.dart';
import 'features/cari/viewmodel/cari_viewmodel.dart';
import 'features/dashboard/viewmodel/dashboard_viewmodel.dart';
import 'features/gider/viewmodel/gider_viewmodel.dart';
import 'features/terminal/viewmodel/terminal_viewmodel.dart';
import 'presentation/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows / Linux / macOS masaüstü: sqflite_common_ffi gerekli
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // tr_TR locale için DateFormat başlatma
  await initializeDateFormatting('tr_TR');

  runApp(const LiqraTerminalApp());
}

class LiqraTerminalApp extends StatelessWidget {
  const LiqraTerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TerminalViewModel()),
        ChangeNotifierProvider(create: (_) => CariViewModel()),
        ChangeNotifierProvider(create: (_) => GiderViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
      ],
      child: MaterialApp(
        title: 'Liqra Terminal Pro',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const AppShell(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.teal,
        secondary: AppColors.gold,
        surface:   AppColors.bgCard,
        error:     AppColors.accentRed,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.teal),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgCard,
        selectedColor:   AppColors.teal.withAlpha(40),
        side: const BorderSide(color: AppColors.border),
        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color:     AppColors.border,
        thickness: 0.5,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor:       AppColors.teal,
        labelColor:           AppColors.teal,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle:           GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
      ),
    );
  }
}
