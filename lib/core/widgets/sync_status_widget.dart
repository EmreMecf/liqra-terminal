import 'dart:async';
import 'package:flutter/material.dart';

import '../services/sync_service.dart';

/// Widget that displays the current sync status and pending operations count
/// Shows different UI based on sync state (idle, syncing, error, offline)
class SyncStatusWidget extends StatefulWidget {
  final bool showLabel;
  final double size;

  const SyncStatusWidget({
    this.showLabel = true,
    this.size = 24,
    Key? key,
  }) : super(key: key);

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  late Timer _statusTimer;
  int _pendingCount = 0;
  bool _isSyncing = false;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();

    // Poll sync status every second for smooth UI updates
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkSyncStatus();
    });
  }

  Future<void> _checkSyncStatus() async {
    if (!mounted) return;

    final status = await SyncService.instance.getSyncStatus();
    setState(() {
      _pendingCount = status['pending_count'] as int;
      _isSyncing = status['is_syncing'] as bool;
      _hasInternet = status['has_internet'] as bool;
    });
  }

  @override
  void dispose() {
    _statusTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Offline state
    if (!_hasInternet) {
      return _buildStatus(
        icon: Icons.cloud_off,
        label: 'Offline',
        color: Colors.red,
      );
    }

    // Syncing state
    if (_isSyncing) {
      return _buildStatus(
        icon: Icons.cloud_sync,
        label: 'Syncing...',
        color: Colors.blue,
        isAnimating: true,
      );
    }

    // Pending operations state
    if (_pendingCount > 0) {
      return _buildStatus(
        icon: Icons.cloud_upload,
        label: 'Pending: $_pendingCount',
        color: Colors.orange,
      );
    }

    // Synced state
    return _buildStatus(
      icon: Icons.cloud_done,
      label: 'Synced',
      color: Colors.green,
    );
  }

  Widget _buildStatus({
    required IconData icon,
    required String label,
    required Color color,
    bool isAnimating = false,
  }) {
    if (widget.showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAnimating)
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _createAnimationController(),
                  curve: Curves.linear,
                ),
              ),
              child: Icon(icon, size: widget.size, color: color),
            )
          else
            Icon(icon, size: widget.size, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      );
    }

    // Icon only
    if (isAnimating) {
      return RotationTransition(
        turns: Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _createAnimationController(),
            curve: Curves.linear,
          ),
        ),
        child: Icon(icon, size: widget.size, color: color),
      );
    }

    return Icon(icon, size: widget.size, color: color);
  }

  AnimationController _createAnimationController() {
    return AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }
}

/// Full-screen sync status indicator (for dashboard/main screen)
class SyncStatusCard extends StatefulWidget {
  final VoidCallback? onSyncPressed;

  const SyncStatusCard({
    this.onSyncPressed,
    Key? key,
  }) : super(key: key);

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  late Timer _statusTimer;
  int _pendingCount = 0;
  bool _isSyncing = false;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkSyncStatus();
    });
  }

  Future<void> _checkSyncStatus() async {
    if (!mounted) return;

    final status = await SyncService.instance.getSyncStatus();
    setState(() {
      _pendingCount = status['pending_count'] as int;
      _isSyncing = status['is_syncing'] as bool;
      _hasInternet = status['has_internet'] as bool;
    });
  }

  @override
  void dispose() {
    _statusTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color cardColor;
    IconData icon;
    String title;
    String subtitle;

    if (!_hasInternet) {
      cardColor = Colors.red.withOpacity(0.1);
      icon = Icons.cloud_off;
      title = 'Offline Mode';
      subtitle = 'Changes will sync when back online';
    } else if (_isSyncing) {
      cardColor = Colors.blue.withOpacity(0.1);
      icon = Icons.cloud_sync;
      title = 'Syncing...';
      subtitle = 'Uploading changes to server';
    } else if (_pendingCount > 0) {
      cardColor = Colors.orange.withOpacity(0.1);
      icon = Icons.cloud_upload;
      title = '$_pendingCount Pending Changes';
      subtitle = 'Waiting for connection or manual sync';
    } else {
      cardColor = Colors.green.withOpacity(0.1);
      icon = Icons.cloud_done;
      title = 'All Changes Synced';
      subtitle = 'Your data is up to date';
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[700], size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onSyncPressed != null && _pendingCount > 0)
              ElevatedButton.icon(
                onPressed: _isSyncing ? null : widget.onSyncPressed,
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Floating sync status indicator (typically in bottom-right corner)
class SyncStatusBadge extends StatefulWidget {
  final VoidCallback? onPressed;

  const SyncStatusBadge({
    this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  late Timer _statusTimer;
  int _pendingCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkSyncStatus();
    });
  }

  Future<void> _checkSyncStatus() async {
    if (!mounted) return;
    final status = await SyncService.instance.getSyncStatus();
    setState(() {
      _pendingCount = status['pending_count'] as int;
      _isSyncing = status['is_syncing'] as bool;
    });
  }

  @override
  void dispose() {
    _statusTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingCount == 0 && !_isSyncing) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton.small(
        onPressed: widget.onPressed,
        backgroundColor: _isSyncing ? Colors.blue : Colors.orange,
        tooltip: _isSyncing
            ? 'Syncing...'
            : 'Pending: $_pendingCount',
        child: _isSyncing
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.cloud_upload),
      ),
    );
  }
}
