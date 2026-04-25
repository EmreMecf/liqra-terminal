import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import 'sync_service.dart';

/// Initializes all core services for the application
/// Call this in main() before runApp()
class AppInitializer {
  static Future<void> initialize({
    required String backendBaseUrl,
    String? jwtToken,
  }) async {
    _initializeSyncService(
      backendBaseUrl: backendBaseUrl,
      jwtToken: jwtToken,
    );

    _initializeConnectivityListener();
  }

  /// Initialize SyncService with custom Dio configuration
  static void _initializeSyncService({
    required String backendBaseUrl,
    String? jwtToken,
  }) {
    // Create custom Dio instance with auth headers if token available
    final dio = Dio(
      BaseOptions(
        baseUrl: backendBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          if (jwtToken != null) 'Authorization': 'Bearer $jwtToken',
        },
      ),
    );

    // Add logging interceptor (optional, useful for debugging)
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (log) {
          // Print only sync-related logs
          if (log.toString().contains('api/sync')) {
            print('[DIO] ${log.toString().split('\n').take(2).join(' ')}');
          }
        },
      ),
    );

    // Initialize SyncService
    SyncService.instance.initialize(
      backendBaseUrl: backendBaseUrl,
      customDio: dio,
    );

    // Setup callbacks for sync events
    _setupSyncCallbacks();

    // Start periodic sync
    SyncService.instance.startSync();

    print('✅ SyncService initialized and started');
  }

  /// Setup callbacks for sync complete and error events
  static void _setupSyncCallbacks() {
    SyncService.instance.onSyncComplete((syncedCount) {
      print('✅ Sync completed: $syncedCount operations synced');
      // TODO: Update UI, show notification, persist last sync time, etc.
      // Example:
      // AppState.lastSyncTime = DateTime.now();
      // notifyListeners(); // if using Provider
    });

    SyncService.instance.onSyncError((error) {
      print('❌ Sync error: $error');
      // TODO: Log to analytics, show user-friendly error message
      // Example:
      // _showErrorSnackbar('Sync failed: $error');
      // Analytics.logEvent('sync_error', {'error': error});
    });
  }

  /// Initialize connectivity listener to sync when internet restored
  static void _initializeConnectivityListener() {
    final connectivity = Connectivity();

    // Check initial connectivity
    connectivity.checkConnectivity().then((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      SyncService.instance.setConnectivityStatus(isConnected);

      String statusMsg = isConnected ? '🌐 Online' : '📴 Offline';
      print('$statusMsg - Connectivity initialized');
    });

    // Listen for connectivity changes
    connectivity.onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      SyncService.instance.setConnectivityStatus(isConnected);

      String statusMsg = isConnected ? '🌐 Back online' : '📴 Offline';
      print('$statusMsg');

      // Optionally show toast notification
      // Fluttertoast.showToast(msg: statusMsg);
    });
  }

  /// Cleanup on app exit
  static void dispose() {
    SyncService.instance.dispose();
    print('🛑 AppInitializer disposed');
  }
}

/// Usage in main.dart:
///
/// ```dart
/// import 'core/services/app_initializer.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Initialize all core services
///   await AppInitializer.initialize(
///     backendBaseUrl: 'http://localhost:3000',
///     jwtToken: null, // Get from SharedPreferences or secure storage
///   );
///
///   runApp(const MyApp());
/// }
///
/// // In your main widget's dispose:
/// @override
/// void dispose() {
///   AppInitializer.dispose();
///   super.dispose();
/// }
/// ```
