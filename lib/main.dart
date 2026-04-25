import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/services/auth_service.dart';
import 'core/theme/app_theme_data.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/cari/viewmodel/cari_viewmodel.dart';
import 'features/dashboard/viewmodel/dashboard_viewmodel.dart';
import 'features/gider/viewmodel/gider_viewmodel.dart';
import 'features/rapor/viewmodel/rapor_viewmodel.dart';
import 'features/terminal/viewmodel/terminal_viewmodel.dart';
import 'features/urun/viewmodel/urun_viewmodel.dart';
import 'presentation/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows / Linux / macOS masaüstü: sqflite_common_ffi gerekli
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // tr_TR locale için DateFormat başlatma
  await initializeDateFormatting('tr_TR');

  // Tema tercihini SharedPreferences'tan yükle
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  // Kaydedilmiş token varsa otomatik giriş
  await AuthService.instance.init();

  runApp(LiqraTerminalApp(themeProvider: themeProvider));
}

class LiqraTerminalApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const LiqraTerminalApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AuthService>.value(value: AuthService.instance),
        ChangeNotifierProvider(create: (_) => TerminalViewModel()),
        ChangeNotifierProvider(create: (_) => CariViewModel()),
        ChangeNotifierProvider(create: (_) => GiderViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => RaporViewModel()),
        ChangeNotifierProvider(create: (_) => UrunViewModel()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, tp, __) => MaterialApp(
          title: 'Liqra Terminal Pro',
          debugShowCheckedModeBanner: false,
          theme:     AppThemeData.light(),
          darkTheme: AppThemeData.dark(),
          themeMode: tp.mode,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

/// Auth durumuna göre LoginScreen veya AppShell gösterir.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select<AuthService, bool>((a) => a.isLoggedIn);
    return isLoggedIn ? const AppShell() : const LoginScreen();
  }
}
