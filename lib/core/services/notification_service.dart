import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────
// Top-level background message handler (required by firebase_messaging)
// MUST be a top-level function, NOT a class method.
// ─────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: OS handles tray notification automatically.
  // We only need this to be registered so background messages are delivered.
  debugPrint('🔔 Background message: ${message.messageId}');
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    FirebaseMessaging.instance,
  );
});

// ─────────────────────────────────────────────
// NotificationService — handles the entire FCM lifecycle
// ─────────────────────────────────────────────
class NotificationService {
  NotificationService(this._firestore, this._auth, this._messaging);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;

  /// Global navigator key set from MaterialApp — needed for deep linking
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Stream controller for in-app notification events (used by banner overlay)
  static final StreamController<RemoteMessage> onForegroundMessage =
      StreamController<RemoteMessage>.broadcast();

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  // ───── PUBLIC API ─────

  /// Call once after user is authenticated (e.g. in AppShellPage).
  Future<void> initialize() async {
    if (_initialized) return;
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Request OS permission
      final granted = await _requestPermission();
      if (!granted) {
        debugPrint('⚠️ Notification permission denied');
        return;
      }

      // 2. On iOS, wait for the APNS token before requesting FCM token
      if (Platform.isIOS) {
        String? apns = await _messaging.getAPNSToken();
        if (apns == null) {
          // APNS token not ready yet — wait and retry a few times
          for (int i = 0; i < 5 && apns == null; i++) {
            await Future.delayed(const Duration(seconds: 1));
            apns = await _messaging.getAPNSToken();
          }
          if (apns == null) {
            debugPrint('⚠️ APNS token still unavailable after retries');
          }
        }
      }

      // 3. Get + save FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(user.uid, token);
      }

      // 3. Subscribe to FCM topics based on role
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final enabled = doc.data()?['notificationsEnabled'] as bool? ?? true;
      if (enabled) {
        await _subscribeToTopics(user.uid);
      }

      // 4. Listen for token refresh
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
        _saveToken(user.uid, newToken);
      });

      // 5. Foreground message listener → push into stream for banner
      _foregroundSub = FirebaseMessaging.onMessage.listen((
        RemoteMessage message,
      ) {
        debugPrint('🔔 Foreground message: ${message.notification?.title}');

        // Don't show if sender is current user
        final senderId = message.data['senderId'] as String?;
        if (senderId == user.uid) return;

        onForegroundMessage.add(message);
      });

      // 6. Handle notification tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 7. Check if app was opened from a terminated-state notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        // Slight delay to let router settle
        Future.delayed(
          const Duration(milliseconds: 500),
          () => _handleNotificationTap(initialMessage),
        );
      }

      _initialized = true;
      debugPrint('✅ NotificationService initialized');
    } catch (e) {
      debugPrint('❌ NotificationService init error: $e');
    }
  }

  /// Toggle notifications on/off — called from profile page.
  Future<void> setNotificationsEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (enabled) {
        final token = await _messaging.getToken();
        if (token != null) await _saveToken(user.uid, token);
        await _subscribeToTopics(user.uid);
      } else {
        await _unsubscribeFromAllTopics();
      }

      await _firestore.collection('users').doc(user.uid).update({
        'notificationsEnabled': enabled,
      });
      debugPrint('✅ Notifications ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      debugPrint('❌ Error toggling notifications: $e');
      rethrow;
    }
  }

  /// Clean up when user logs out.
  Future<void> disposeService() async {
    _initialized = false;
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;

    try {
      await _unsubscribeFromAllTopics();
      // Clear stored token on logout so stale tokens don't get notifications
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.delete(),
        });
      }
    } catch (_) {}
  }

  // ───── PERMISSION ─────

  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Public getter so UI can check current permission state.
  Future<bool> get hasPermission async {
    final s = await _messaging.getNotificationSettings();
    return s.authorizationStatus == AuthorizationStatus.authorized;
  }

  // ───── TOKEN ─────

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FCM token saved: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
    }
  }

  // ───── TOPICS ─────

  Future<void> _subscribeToTopics(String uid) async {
    try {
      // Wait for APNS token on iOS
      if (Platform.isIOS) {
        final apns = await _messaging.getAPNSToken();
        if (apns == null) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      await _messaging.subscribeToTopic('all_users');
      await _messaging.subscribeToTopic('announcements');

      // Role-based topics
      final doc = await _firestore.collection('users').doc(uid).get();
      final role = doc.data()?['role'] as String? ?? 'member';
      if (role == 'admin') {
        await _messaging.subscribeToTopic('admin_notifications');
        await _messaging.subscribeToTopic('device_approvals');
      }
      debugPrint('✅ Subscribed to FCM topics');
    } catch (e) {
      debugPrint('❌ Topic subscribe error: $e');
    }
  }

  Future<void> _unsubscribeFromAllTopics() async {
    try {
      await _messaging.unsubscribeFromTopic('all_users');
      await _messaging.unsubscribeFromTopic('announcements');
      await _messaging.unsubscribeFromTopic('admin_notifications');
      await _messaging.unsubscribeFromTopic('device_approvals');
      debugPrint('✅ Unsubscribed from all FCM topics');
    } catch (_) {}
  }

  // ───── DEEP LINKING ON TAP ─────

  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    final context = navigatorKey.currentContext;
    if (context == null || type == null) return;

    debugPrint('🔔 Notification tap → type=$type, data=$data');

    switch (type) {
      case 'announcement':
        context.go('/app?tab=announcements');
        break;
      case 'chat':
        context.go('/app?tab=chat');
        break;
      case 'file_uploaded':
      case 'file_renamed':
        final folderId = data['folderId'] as String?;
        if (folderId != null) {
          context.go('/app?folderId=$folderId');
        } else {
          context.go('/app');
        }
        break;
      case 'folder_created':
      case 'folder_renamed':
        final parentId = data['parentId'] as String?;
        if (parentId != null) {
          context.go('/app?folderId=$parentId');
        } else {
          context.go('/app');
        }
        break;
      case 'user_approved':
      case 'user_blocked':
      case 'device_approved':
      case 'device_rejected':
      case 'role_changed':
        // Navigate to profile
        context.go('/app?tab=profile');
        break;
      case 'security_violation':
      case 'pending_approval':
        context.go('/admin');
        break;
      default:
        context.go('/app');
    }
  }
}

// ─────────────────────────────────────────────
// In-App Notification Banner Overlay
// Displays a Material 3 banner at top when a notification arrives in foreground.
// ─────────────────────────────────────────────
class NotificationBannerOverlay extends ConsumerStatefulWidget {
  const NotificationBannerOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationBannerOverlay> createState() =>
      _NotificationBannerOverlayState();
}

class _NotificationBannerOverlayState
    extends ConsumerState<NotificationBannerOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<RemoteMessage>? _sub;
  RemoteMessage? _currentMessage;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _sub = NotificationService.onForegroundMessage.stream.listen(_show);
  }

  void _show(RemoteMessage msg) {
    _autoDismiss?.cancel();
    setState(() => _currentMessage = msg);
    _animController.forward(from: 0);
    _autoDismiss = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _currentMessage = null);
    });
  }

  void _onTap() {
    _autoDismiss?.cancel();
    final msg = _currentMessage;
    if (msg != null) {
      NotificationService._handleNotificationTap(msg);
    }
    _dismiss();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _autoDismiss?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentMessage != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildBanner(context),
            ),
          ),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    final msg = _currentMessage!;
    final notification = msg.notification;
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    // Pick icon based on notification type
    final type = msg.data['type'] as String? ?? '';
    IconData icon;
    Color iconColor;
    switch (type) {
      case 'announcement':
        icon = Icons.campaign;
        iconColor = Colors.orange;
        break;
      case 'chat':
        icon = Icons.chat_bubble;
        iconColor = Colors.blue;
        break;
      case 'file_uploaded':
        icon = Icons.upload_file;
        iconColor = Colors.green;
        break;
      case 'folder_created':
        icon = Icons.create_new_folder;
        iconColor = Colors.amber;
        break;
      case 'security_violation':
        icon = Icons.security;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.notifications;
        iconColor = theme.colorScheme.primary;
    }

    return GestureDetector(
      onTap: _onTap,
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy < -100) _dismiss();
      },
      child: Container(
        padding: EdgeInsets.only(
          top: topPadding + 8,
          left: 16,
          right: 16,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification?.title ?? 'Notification',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification?.body != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification!.body!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: _dismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
