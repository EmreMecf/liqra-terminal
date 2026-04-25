# SyncService Implementation Guide

## Overview
The `SyncService` provides automatic offline-first synchronization between your Flutter POS app and the Node.js backend. It:

- Periodically syncs queued operations (every 5 minutes)
- Detects internet connectivity and syncs immediately when connection restored
- Handles retries on failure
- Manages sync status and provides callbacks

## Setup

### 1. Add Dependencies
```yaml
# pubspec.yaml
dependencies:
  dio: ^5.3.0
  connectivity_plus: ^5.0.0
```

### 2. Initialize in App Startup
```dart
// lib/main.dart or your main app initialization

import 'package:dio/dio.dart';
import 'core/services/sync_service.dart';

void main() {
  // Initialize SyncService
  SyncService.instance.initialize(
    backendBaseUrl: 'http://your-backend.com',  // e.g., http://localhost:3000
    // Optional: provide custom Dio instance with auth headers, etc.
  );

  // Setup callbacks
  SyncService.instance.onSyncComplete((syncedCount) {
    print('✅ Synced $syncedCount operations');
    // Update UI, show notification, etc.
  });

  SyncService.instance.onSyncError((error) {
    print('❌ Sync error: $error');
    // Handle error, show user-friendly message
  });

  // Start periodic sync
  SyncService.instance.startSync();

  runApp(const MyApp());
}
```

### 3. Integrate Connectivity Detection (Recommended)
```dart
// lib/core/services/connectivity_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_service.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  void initialize() {
    final connectivity = Connectivity();

    // Check initial connection status
    connectivity.checkConnectivity().then((result) {
      final isConnected = !result.contains(ConnectivityResult.none);
      SyncService.instance.setConnectivityStatus(isConnected);
    });

    // Listen for connectivity changes
    connectivity.onConnectivityChanged.listen((result) {
      final isConnected = !result.contains(ConnectivityResult.none);
      SyncService.instance.setConnectivityStatus(isConnected);
    });
  }
}

// In main():
void main() {
  SyncService.instance.initialize(backendBaseUrl: 'http://localhost:3000');
  ConnectivityService.instance.initialize();
  SyncService.instance.startSync();
  
  runApp(const MyApp());
}
```

## Usage Examples

### Manual Sync
```dart
// Trigger sync immediately (useful for manual "Sync Now" buttons)
await SyncService.instance.syncNow();
```

### Check Sync Status
```dart
// Get pending operation count
final pending = await SyncService.instance.getPendingOperationCount();
print('Pending operations: $pending');

// Get detailed status
final status = await SyncService.instance.getSyncStatus();
print('Syncing: ${status['is_syncing']}');
print('Pending: ${status['pending_count']}');
print('Has internet: ${status['has_internet']}');
```

### UI Integration (Provider/Consumer)
```dart
// Create a provider for sync status
class SyncStatusProvider extends ChangeNotifier {
  int _pendingCount = 0;
  bool _isSyncing = false;

  int get pendingCount => _pendingCount;
  bool get isSyncing => _isSyncing;

  void initialize() {
    SyncService.instance.onSyncComplete((count) {
      _pendingCount = 0;
      _isSyncing = false;
      notifyListeners();
    });

    SyncService.instance.onSyncError((error) {
      _isSyncing = false;
      notifyListeners();
    });

    // Poll sync status periodically
    Timer.periodic(Duration(seconds: 1), (_) async {
      final status = await SyncService.instance.getSyncStatus();
      _pendingCount = status['pending_count'] as int;
      _isSyncing = status['is_syncing'] as bool;
      notifyListeners();
    });
  }
}

// Use in UI:
class SyncStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SyncStatusProvider>(
      builder: (context, syncStatus, _) {
        if (syncStatus.pendingCount == 0) {
          return const Text('✓ All synced', style: TextStyle(color: Colors.green));
        }
        return Text(
          '⏳ Pending: ${syncStatus.pendingCount}',
          style: TextStyle(color: Colors.orange),
        );
      },
    );
  }
}
```

### Sync Button in UI
```dart
FloatingActionButton(
  onPressed: () async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing...')),
    );
    await SyncService.instance.syncNow();
  },
  tooltip: 'Sync now',
  child: const Icon(Icons.cloud_upload),
)
```

## Backend API Expected Format

### Request to `/api/sync/push`
```json
{
  "operations": [
    {
      "id": "uuid-1",
      "tablo_adi": "satislar",
      "islem_tipi": "insert",
      "veri_json": "{...sale data...}",
      "tarih": "2024-04-25T10:30:45.123456"
    },
    {
      "id": "uuid-2",
      "tablo_adi": "satislar",
      "islem_tipi": "insert",
      "veri_json": "{...sale data...}",
      "tarih": "2024-04-25T10:35:22.456789"
    }
  ],
  "timestamp": "2024-04-25T10:36:00.000000"
}
```

### Expected Response (Success - 200/201)
```json
{
  "success": true,
  "synced_ids": ["uuid-1", "uuid-2"],
  "message": "2 operations synced successfully"
}
```

### Expected Response (Error - 400/500)
```json
{
  "success": false,
  "error": "Failed to process operations",
  "details": "..."
}
```

## Example Node.js Backend Handler

```javascript
// backend/routes/sync.routes.js

router.post('/api/sync/push', async (req, res) => {
  const { operations } = req.body;
  
  if (!operations || !Array.isArray(operations)) {
    return res.status(400).json({ 
      success: false, 
      error: 'Invalid operations format' 
    });
  }

  const syncedIds = [];
  
  try {
    for (const op of operations) {
      // Parse JSON data
      const data = JSON.parse(op.veri_json);
      
      switch (op.tablo_adi) {
        case 'satislar':
          // Merge sale into PostgreSQL or Firestore
          await saveSaleToBackend(data);
          syncedIds.push(op.id);
          break;
        // Handle other table types...
      }
    }

    res.json({
      success: true,
      synced_ids: syncedIds,
      message: `${syncedIds.length} operations synced`
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err.message
    });
  }
});
```

## Lifecycle

```
App Start
  ↓
SyncService.initialize() ✓
  ↓
SyncService.startSync() → Timer starts (every 5 min)
  ↓
[Periodic] _performSync()
  ├─ Check pending operations
  ├─ POST to /api/sync/push
  ├─ Update sync_queue status (if success)
  └─ Call callbacks
  ↓
[On Connectivity Change] setConnectivityStatus()
  ├─ If internet restored → Immediate sync
  └─ If disconnected → Log and wait for next timer
  ↓
App Close
  ↓
SyncService.dispose() → Stop timer, clear callbacks
```

## Configuration

Edit constants at the top of `sync_service.dart`:

```dart
static const int _syncIntervalSeconds = 300;  // 5 minutes (change to 60 for 1 min, etc.)
static const int _maxRetries = 3;             // Retry up to 3 times on failure
static const int _retryDelaySeconds = 10;     // Wait 10 seconds between retries
```

## Troubleshooting

### Sync Not Running
- ✓ Check if `SyncService.startSync()` is called
- ✓ Verify backend URL is correct
- ✓ Check Dio timeout settings
- ✓ Look at console logs for [SYNC] messages

### Operations Not Syncing
- ✓ Verify `/api/sync/push` endpoint exists on backend
- ✓ Check sync_queue table has pending operations: `SELECT * FROM sync_queue WHERE senkronize_edildi_mi = 0`
- ✓ Verify response from backend matches expected format
- ✓ Check for 401/403 auth errors in logs

### Memory Leaks
- ✓ Always call `SyncService.instance.dispose()` on app exit
- ✓ Remove callbacks when no longer needed
- ✓ Use `onSyncComplete()` callbacks to update UI, not continuous polling

## Best Practices

1. **Initialize Early** — Call during app startup, before main screen
2. **Handle Callbacks** — Register `onSyncComplete` and `onSyncError` for better UX
3. **Show Status** — Display sync status in UI (pending count, last sync time)
4. **Test Offline** — Use Chrome DevTools to simulate offline mode
5. **Monitor Logs** — Watch [SYNC] logs to debug issues
6. **Graceful Shutdown** — Call `dispose()` on app exit
7. **Retry Logic** — Automatic retries with exponential backoff are built-in

---

**Last Updated:** April 25, 2024  
**Version:** 1.0.0
