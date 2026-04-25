import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../database/database_service.dart';

/// Offline-First Synchronization Service
///
/// Periodically syncs queued operations from local database to backend.
/// - Runs every 5 minutes or on connectivity change
/// - Retries failed operations
/// - Updates sync status when successful
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  // Configuration
  static const int _syncIntervalSeconds = 300; // 5 minutes
  static const int _maxRetries = 3;
  static const int _retryDelaySeconds = 10;

  // State
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _hasInternetConnection = true;
  int _syncAttempts = 0;

  // Dependencies
  late Dio _dio;
  late DatabaseService _database;

  // Callbacks
  final List<Function(int)> _onSyncCompleteCallbacks = [];
  final List<Function(String)> _onSyncErrorCallbacks = [];

  // ──────────────────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────────────────

  /// Initialize SyncService with backend URL and optional custom Dio instance
  void initialize({
    required String backendBaseUrl,
    Dio? customDio,
  }) {
    _database = DatabaseService.instance;

    // Setup Dio client
    _dio = customDio ??
        Dio(BaseOptions(
          baseUrl: backendBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
          },
        ));

    _log('✅ SyncService initialized with backend: $backendBaseUrl');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Start/Stop Sync
  // ──────────────────────────────────────────────────────────────────────────

  /// Start the periodic sync timer
  void startSync() {
    if (_syncTimer != null) {
      _log('⚠️ Sync timer already running');
      return;
    }

    _log('▶️ Starting periodic sync (every $_syncIntervalSeconds seconds)');

    // Run sync immediately on startup
    _performSync();

    // Setup periodic timer
    _syncTimer = Timer.periodic(
      Duration(seconds: _syncIntervalSeconds),
      (_) => _performSync(),
    );
  }

  /// Stop the periodic sync timer
  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _log('⏹️ Sync timer stopped');
  }

  /// Trigger sync manually (useful for testing or explicit sync requests)
  Future<void> syncNow() async {
    _log('⚡ Manual sync triggered');
    await _performSync();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sync Logic
  // ──────────────────────────────────────────────────────────────────────────

  /// Main sync operation: fetch pending records and push to backend
  Future<void> _performSync() async {
    if (_isSyncing) {
      _log('⏳ Sync already in progress, skipping...');
      return;
    }

    _isSyncing = true;
    _syncAttempts++;

    try {
      // Check if we have pending operations
      final pendingCount = await _database.bekleyenSyncSayisi();
      if (pendingCount == 0) {
        _log('✓ No pending operations to sync');
        _isSyncing = false;
        return;
      }

      _log('📤 Starting sync... (pending: $pendingCount)');

      // Fetch pending operations
      final pendingOps = await _database.bekleyenSyncOperations();
      if (pendingOps.isEmpty) {
        _log('✓ No pending operations found');
        _isSyncing = false;
        return;
      }

      // Push to backend
      final result = await _pushToBackend(pendingOps);

      if (result['success']) {
        final syncedCount = result['synced_count'] as int;
        _log('✅ Sync completed! Synced $syncedCount operations');

        // Mark operations as synchronized
        for (final op in result['synced_ops'] as List) {
          await _database.syncKaydiTamamla(op as String);
        }

        _notifySyncComplete(syncedCount);
      } else {
        final error = result['error'] as String;
        _log('❌ Sync failed: $error');
        _notifySyncError(error);

        // Retry logic
        if (_syncAttempts < _maxRetries) {
          _log('🔄 Retrying in $_retryDelaySeconds seconds... (attempt $_syncAttempts/$_maxRetries)');
          await Future.delayed(Duration(seconds: _retryDelaySeconds));
          await _performSync();
          return;
        } else {
          _log('⚠️ Max retries reached. Will retry at next scheduled sync.');
          _syncAttempts = 0;
        }
      }
    } catch (e) {
      _log('❌ Unexpected error during sync: $e');
      _notifySyncError('Unexpected error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Push pending operations to backend API
  Future<Map<String, dynamic>> _pushToBackend(
      List<Map<String, dynamic>> operations) async {
    try {
      // Prepare request payload
      final payload = {
        'operations': operations
            .map((op) => {
                  'id': op['id'],
                  'tablo_adi': op['tablo_adi'],
                  'islem_tipi': op['islem_tipi'],
                  'veri_json': op['veri_json'],
                  'tarih': op['tarih'],
                })
            .toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      _log('📨 Sending ${operations.length} operations to /api/sync/push');

      // POST to backend
      final response = await _dio.post(
        '/api/sync/push',
        data: jsonEncode(payload),
        options: Options(
          method: 'POST',
          contentType: Headers.jsonContentType,
        ),
      );

      // Handle response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final syncedIds =
            List<String>.from(response.data['synced_ids'] as List? ?? []);

        return {
          'success': true,
          'synced_count': syncedIds.length,
          'synced_ops': operations
              .where((op) => syncedIds.contains(op['id']))
              .map((op) => op['id'])
              .toList(),
        };
      } else {
        return {
          'success': false,
          'error':
              'Server returned status ${response.statusCode}: ${response.statusMessage}',
        };
      }
    } on DioException catch (e) {
      String errorMsg = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout) {
        errorMsg = 'Connection timeout';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMsg = 'Receive timeout';
      } else if (e.type == DioExceptionType.unknown) {
        errorMsg = 'No internet connection';
        _hasInternetConnection = false;
      } else if (e.response?.statusCode == 400) {
        errorMsg = 'Bad request: ${e.response?.data['error'] ?? 'unknown'}';
      } else if (e.response?.statusCode == 401) {
        errorMsg = 'Unauthorized - token may have expired';
      } else if (e.response?.statusCode == 500) {
        errorMsg = 'Server error (500)';
      }

      return {
        'success': false,
        'error': errorMsg,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Connectivity Detection
  // ──────────────────────────────────────────────────────────────────────────

  /// Set internet connectivity status (useful with connectivity_plus package)
  /// Call this when connectivity changes to trigger immediate sync
  void setConnectivityStatus(bool isConnected) {
    final wasOffline = !_hasInternetConnection;
    _hasInternetConnection = isConnected;

    if (wasOffline && isConnected) {
      _log('🌐 Internet connection restored - syncing now!');
      _syncNow();
    } else if (!isConnected) {
      _log('📴 Internet connection lost');
    }
  }

  /// Trigger sync immediately (with cooldown to prevent spam)
  Future<void> _syncNow() async {
    if (_isSyncing) {
      _log('⏳ Sync already in progress');
      return;
    }
    await _performSync();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Callbacks
  // ──────────────────────────────────────────────────────────────────────────

  /// Register callback to be notified when sync completes
  void onSyncComplete(Function(int) callback) {
    _onSyncCompleteCallbacks.add(callback);
  }

  /// Register callback to be notified when sync fails
  void onSyncError(Function(String) callback) {
    _onSyncErrorCallbacks.add(callback);
  }

  void _notifySyncComplete(int syncedCount) {
    for (final callback in _onSyncCompleteCallbacks) {
      try {
        callback(syncedCount);
      } catch (e) {
        _log('❌ Error in sync complete callback: $e');
      }
    }
  }

  void _notifySyncError(String error) {
    for (final callback in _onSyncErrorCallbacks) {
      try {
        callback(error);
      } catch (e) {
        _log('❌ Error in sync error callback: $e');
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Status & Info
  // ──────────────────────────────────────────────────────────────────────────

  /// Get current sync status
  bool get isSyncing => _isSyncing;
  bool get hasInternetConnection => _hasInternetConnection;
  int get syncAttempts => _syncAttempts;

  /// Get pending operation count
  Future<int> getPendingOperationCount() async {
    return await _database.bekleyenSyncSayisi();
  }

  /// Get detailed sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    final pendingCount = await _database.bekleyenSyncSayisi();
    return {
      'is_syncing': _isSyncing,
      'has_internet': _hasInternetConnection,
      'pending_count': pendingCount,
      'sync_attempts': _syncAttempts,
      'timer_active': _syncTimer != null,
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Cleanup
  // ──────────────────────────────────────────────────────────────────────────

  /// Dispose of resources
  void dispose() {
    stopSync();
    _onSyncCompleteCallbacks.clear();
    _onSyncErrorCallbacks.clear();
    _log('🗑️ SyncService disposed');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Logging
  // ──────────────────────────────────────────────────────────────────────────

  void _log(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('[$timestamp] [SYNC] $message');
  }
}
