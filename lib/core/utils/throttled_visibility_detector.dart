import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';

/// Throttled visibility detector for marking chat messages as read
///
/// Prevents excessive Firestore writes by:
/// - Debouncing visibility changes (500ms delay)
/// - Only triggering when widget is >50% visible
/// - Checking app lifecycle state (only when in foreground)
///
/// Usage:
/// ```dart
/// ThrottledVisibilityDetector(
///   key: ValueKey('message_$messageId'),
///   onVisible: () => markAsRead(messageId),
///   child: MessageBubble(...),
/// )
/// ```
class ThrottledVisibilityDetector extends StatefulWidget {
  const ThrottledVisibilityDetector({
    required super.key,
    required this.onVisible,
    required this.child,
    this.visibilityThreshold = 0.5,
    this.debounceMilliseconds = 500,
  });

  final VoidCallback onVisible;
  final Widget child;
  final double visibilityThreshold;
  final int debounceMilliseconds;

  @override
  State<ThrottledVisibilityDetector> createState() =>
      _ThrottledVisibilityDetectorState();
}

class _ThrottledVisibilityDetectorState
    extends State<ThrottledVisibilityDetector>
    with WidgetsBindingObserver {
  Timer? _debounceTimer;
  bool _hasBeenVisible = false;
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isAppInForeground = state == AppLifecycleState.resumed;
    });
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    // Only proceed if:
    // 1. Widget is sufficiently visible
    // 2. App is in foreground
    // 3. Hasn't been marked visible before
    if (info.visibleFraction >= widget.visibilityThreshold &&
        _isAppInForeground &&
        !_hasBeenVisible) {
      // Cancel any existing timer
      _debounceTimer?.cancel();

      // Start new debounce timer
      _debounceTimer = Timer(
        Duration(milliseconds: widget.debounceMilliseconds),
        () {
          if (mounted && _isAppInForeground && !_hasBeenVisible) {
            _hasBeenVisible = true;
            widget.onVisible();
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.key!,
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}

/// Batch visibility tracker for marking multiple messages as read
///
/// More efficient than individual ThrottledVisibilityDetectors when
/// scrolling through many messages quickly.
///
/// Collects visible message IDs and marks them as read in a single batch.
class BatchVisibilityTracker {
  final Set<String> _visibleIds = {};
  final Function(List<String>) onBatchRead;
  Timer? _batchTimer;

  static const Duration _batchDelay = Duration(milliseconds: 1000);

  BatchVisibilityTracker({required this.onBatchRead});

  void markVisible(String id) {
    if (!_visibleIds.contains(id)) {
      _visibleIds.add(id);
      _scheduleBatchUpdate();
    }
  }

  void _scheduleBatchUpdate() {
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchDelay, () {
      if (_visibleIds.isNotEmpty) {
        final idsToMark = _visibleIds.toList();
        _visibleIds.clear();
        onBatchRead(idsToMark);
      }
    });
  }

  void dispose() {
    _batchTimer?.cancel();
  }
}
