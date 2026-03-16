import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaam_button.dart';
import '../widgets/content_max_width.dart';

class AdminPanelPage extends ConsumerStatefulWidget {
  const AdminPanelPage({super.key});

  @override
  ConsumerState<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends ConsumerState<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final Set<String> _loadingUsers = {};
  final Set<String> _loadingDevices = {};
  final Set<String> _loadingRoles = {};
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeCollections() async {
    if (_isInitializing) return;

    setState(() => _isInitializing = true);
    try {
      final callable = _functions.httpsCallable('initializeCollections');
      final result = await callable.call({});
      final data = result.data as Map<String, dynamic>;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Collections initialized: ${data['created']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _approveUser(String uid) async {
    setState(() => _loadingUsers.add(uid));
    try {
      final callable = _functions.httpsCallable('approveUser');
      await callable.call({'uid': uid});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ User approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingUsers.remove(uid));
      }
    }
  }

  Future<void> _blockUser(String uid) async {
    // Prevent self-blocking
    if (uid == FirebaseAuth.instance.currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ You cannot block yourself'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
          'Are you sure you want to block this user? They will lose access to the app immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loadingUsers.add(uid));
    try {
      final callable = _functions.httpsCallable('blockUser');
      await callable.call({'uid': uid, 'reason': 'Blocked by administrator'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚫 User blocked successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingUsers.remove(uid));
      }
    }
  }

  Future<void> _unblockUser(String uid) async {
    setState(() => _loadingUsers.add(uid));
    try {
      final callable = _functions.httpsCallable('unblockUser');
      await callable.call({'uid': uid});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ User unblocked successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingUsers.remove(uid));
      }
    }
  }

  Future<void> _approveDevice(String uid, String deviceId) async {
    final key = '${uid}_$deviceId';
    setState(() => _loadingDevices.add(key));
    try {
      final callable = _functions.httpsCallable('approveDevice');
      await callable.call({'uid': uid, 'deviceId': deviceId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Device approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDevices.remove(key));
      }
    }
  }

  /// Cleans up a stale login request that was already approved
  Future<void> _cleanupStaleRequest(String requestDocId) async {
    try {
      await _firestore.collection('login_requests').doc(requestDocId).update({
        'status': 'approved',
        'handledAt': FieldValue.serverTimestamp(),
        'cleanedUp': true,
      });
    } catch (e) {
      // Silently fail - this is just cleanup
      debugPrint('Failed to cleanup stale request $requestDocId: $e');
    }
  }

  Future<void> _removeDevice(String uid, String deviceId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: const Text(
          'Are you sure you want to remove this device? The user will be forced to re-authenticate from that device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final key = '${uid}_$deviceId';
    setState(() => _loadingDevices.add(key));
    try {
      final callable = _functions.httpsCallable('removeDevice');
      await callable.call({'uid': uid, 'deviceId': deviceId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Device removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDevices.remove(key));
      }
    }
  }

  Future<void> _rejectDevice(String uid, String deviceId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Device'),
        content: const Text(
          'Are you sure you want to reject this device request? The user will need to try again from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final key = '${uid}_$deviceId';
    setState(() => _loadingDevices.add(key));
    try {
      final callable = _functions.httpsCallable('rejectDevice');
      await callable.call({'uid': uid, 'deviceId': deviceId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚫 Device request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDevices.remove(key));
      }
    }
  }

  Future<void> _changeUserRole(
    String uid,
    String currentRole,
    String userName,
  ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // Prevent self-demotion
    if (uid == currentUid && currentRole == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ You cannot demote yourself'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newRole = currentRole == 'admin' ? 'member' : 'admin';
    final actionText = currentRole == 'admin'
        ? 'demote to Member'
        : 'promote to Admin';

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role'),
        content: Text('Are you sure you want to $actionText for $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: newRole == 'admin' ? Colors.purple : Colors.blue,
            ),
            child: Text(newRole == 'admin' ? 'Promote' : 'Demote'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loadingRoles.add(uid));
    try {
      final callable = _functions.httpsCallable('changeUserRole');
      await callable.call({'uid': uid, 'newRole': newRole});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newRole == 'admin'
                  ? '👑 $userName promoted to Admin'
                  : '👤 $userName demoted to Member',
            ),
            backgroundColor: newRole == 'admin' ? Colors.purple : Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingRoles.remove(uid));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          _isInitializing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.cloud_sync),
                  tooltip: 'Initialize Collections',
                  onPressed: _initializeCollections,
                ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'Devices'),
          ],
        ),
      ),
      body: ContentMaxWidth(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildUsersTab(),
            _buildDeviceRequestsTab(),
          ],
        ),
      ),
    );
  }

  // ========== SECTION C: SYSTEM OVERVIEW ==========
  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('login_requests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, requestsSnapshot) {
            if (usersSnapshot.hasError || requestsSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${usersSnapshot.error ?? requestsSnapshot.error}',
                ),
              );
            }

            if (!usersSnapshot.hasData || !requestsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final users = usersSnapshot.data!.docs;
            final pendingRequests = requestsSnapshot.data!.docs.length;

            // Calculate stats
            int totalUsers = users.length;
            int approvedUsers = 0;
            int pendingUsers = 0;
            int blockedUsers = 0;
            int adminCount = 0;
            int totalDevices = 0;

            for (final doc in users) {
              final data = doc.data() as Map<String, dynamic>;
              final approved = data['approved'] as bool? ?? false;
              final blocked = data['blocked'] as bool? ?? false;
              final role = data['role'] as String? ?? 'member';
              final devices = data['devices'] as List? ?? [];

              if (role == 'admin') adminCount++;
              if (blocked) {
                blockedUsers++;
              } else if (approved) {
                approvedUsers++;
              } else {
                pendingUsers++;
              }
              totalDevices += devices.length;
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Text(
                  'System Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time system statistics',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _StatCard(
                      title: 'Total Users',
                      value: totalUsers.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                    _StatCard(
                      title: 'Admins',
                      value: adminCount.toString(),
                      icon: Icons.shield,
                      color: Colors.purple,
                    ),
                    _StatCard(
                      title: 'Approved',
                      value: approvedUsers.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    _StatCard(
                      title: 'Pending',
                      value: pendingUsers.toString(),
                      icon: Icons.hourglass_empty,
                      color: Colors.orange,
                    ),
                    _StatCard(
                      title: 'Blocked',
                      value: blockedUsers.toString(),
                      icon: Icons.block,
                      color: Colors.red,
                    ),
                    _StatCard(
                      title: 'Active Devices',
                      value: totalDevices.toString(),
                      icon: Icons.smartphone,
                      color: Colors.teal,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Pending Requests Alert
                if (pendingRequests > 0 || pendingUsers > 0)
                  Card(
                    color: Colors.orange.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Action Required',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (pendingUsers > 0)
                            Text(
                              '• $pendingUsers user(s) awaiting approval',
                              style: TextStyle(color: Colors.orange[700]),
                            ),
                          if (pendingRequests > 0)
                            Text(
                              '• $pendingRequests device request(s) pending',
                              style: TextStyle(color: Colors.orange[700]),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ========== SECTION A: USER MANAGEMENT ==========
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final uid = users[index].id;
            final email = userData['email'] as String? ?? '';
            final name = userData['name'] as String? ?? '';
            final role = userData['role'] as String? ?? 'member';
            final approved = userData['approved'] as bool? ?? false;
            final blocked = userData['blocked'] as bool? ?? false;
            // Parse devices robustly - handle both string list and object list
            final rawDevices = userData['devices'];
            List<String> devices = [];
            if (rawDevices is List) {
              for (final item in rawDevices) {
                if (item is String) {
                  devices.add(item);
                } else if (item is Map) {
                  final id = item['deviceId'] ?? item['id'];
                  if (id is String) devices.add(id);
                }
              }
            }
            final isSelf = uid == currentUid;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (isSelf) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'YOU',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: AppColors.mutedForeground,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: role == 'admin'
                                ? Colors.purple.withValues(alpha: 0.1)
                                : Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: role == 'admin'
                                  ? Colors.purple
                                  : Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatusChip(
                          label: blocked
                              ? 'Blocked'
                              : approved
                              ? 'Approved'
                              : 'Pending',
                          color: blocked
                              ? Colors.red
                              : approved
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Devices: ${devices.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        // Role change button (not for self, and only if approved and not blocked)
                        if (!isSelf && approved && !blocked) ...[
                          const Spacer(),
                          _loadingRoles.contains(uid)
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: () =>
                                      _changeUserRole(uid, role, name),
                                  icon: Icon(
                                    role == 'admin'
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    size: 16,
                                    color: role == 'admin'
                                        ? Colors.blue
                                        : Colors.purple,
                                  ),
                                  label: Text(
                                    role == 'admin' ? 'Demote' : 'Promote',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: role == 'admin'
                                          ? Colors.blue
                                          : Colors.purple,
                                    ),
                                  ),
                                ),
                        ],
                      ],
                    ),

                    // Action buttons (not for self)
                    if (!isSelf) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Approve button (if not approved and not blocked)
                          if (!approved && !blocked)
                            Expanded(
                              child: KaamButton(
                                onPressed: _loadingUsers.contains(uid)
                                    ? null
                                    : () => _approveUser(uid),
                                size: KaamButtonSize.normal,
                                child: _loadingUsers.contains(uid)
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Approve'),
                              ),
                            ),

                          // Block button (if not blocked)
                          if (!blocked) ...[
                            if (!approved) const SizedBox(width: 8),
                            Expanded(
                              child: KaamButton(
                                onPressed: _loadingUsers.contains(uid)
                                    ? null
                                    : () => _blockUser(uid),
                                variant: KaamButtonVariant.ghost,
                                size: KaamButtonSize.normal,
                                child: _loadingUsers.contains(uid)
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Block'),
                              ),
                            ),
                          ],

                          // Unblock button (if blocked)
                          if (blocked)
                            Expanded(
                              child: KaamButton(
                                onPressed: _loadingUsers.contains(uid)
                                    ? null
                                    : () => _unblockUser(uid),
                                size: KaamButtonSize.normal,
                                child: _loadingUsers.contains(uid)
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Unblock'),
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Device management (expandable)
                    if (devices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'Manage Devices (${devices.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        children: devices.map<Widget>((deviceId) {
                          final key = '${uid}_$deviceId';
                          final shortId = deviceId.length > 16
                              ? '${deviceId.substring(0, 8)}...${deviceId.substring(deviceId.length - 8)}'
                              : deviceId;

                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.smartphone, size: 20),
                            title: Text(
                              shortId,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            trailing: _loadingDevices.contains(key)
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _removeDevice(uid, deviceId),
                                  ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ========== SECTION B: DEVICE MANAGEMENT ==========
  Widget _buildDeviceRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('login_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, requestsSnapshot) {
        if (requestsSnapshot.hasError) {
          return Center(child: Text('Error: ${requestsSnapshot.error}'));
        }

        if (!requestsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = requestsSnapshot.data!.docs;

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No pending device requests',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'All device requests have been processed',
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
              ],
            ),
          );
        }

        // Also stream users to check for already approved devices
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, usersSnapshot) {
            if (!usersSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Build a map of userId -> approved devices
            final usersData = <String, Map<String, dynamic>>{};
            for (final doc in usersSnapshot.data!.docs) {
              usersData[doc.id] = doc.data() as Map<String, dynamic>;
            }

            // Filter out requests where device is already approved
            final pendingRequests = requests.where((request) {
              final data = request.data() as Map<String, dynamic>;
              final userId = data['userId'] as String? ?? '';
              final deviceId = data['deviceId'] as String? ?? '';

              final userData = usersData[userId];
              if (userData == null) return true; // User not found, show request

              final devices = userData['devices'];
              final devicesList = devices is List
                  ? devices.map((d) => d.toString()).toList()
                  : <String>[];

              // If device is already in user's approved devices, skip it
              if (devicesList.contains(deviceId)) {
                // Cleanup stale request in background
                _cleanupStaleRequest(request.id);
                return false;
              }
              return true;
            }).toList();

            if (pendingRequests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No pending device requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'All device requests have been processed',
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pendingRequests.length,
              itemBuilder: (context, index) {
                final requestData =
                    pendingRequests[index].data() as Map<String, dynamic>;
                final userId = requestData['userId'] as String? ?? '';
                final deviceId = requestData['deviceId'] as String? ?? '';
                final deviceInfo = requestData['deviceInfo'] as Map? ?? {};
                final platform = deviceInfo['platform'] as String? ?? 'Unknown';
                final model = deviceInfo['model'] as String? ?? 'Unknown';

                final userData = usersData[userId];
                final userName = userData?['name'] as String? ?? 'Unknown';
                final userEmail = userData?['email'] as String? ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (userEmail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            userEmail,
                            style: const TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _InfoRow(label: 'Platform', value: platform),
                        const SizedBox(height: 4),
                        _InfoRow(label: 'Model', value: model),
                        const SizedBox(height: 4),
                        _InfoRow(
                          label: 'Device ID',
                          value: deviceId.length > 16
                              ? '${deviceId.substring(0, 16)}...'
                              : deviceId,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: KaamButton(
                                onPressed:
                                    _loadingDevices.contains(
                                      '${userId}_$deviceId',
                                    )
                                    ? null
                                    : () => _approveDevice(userId, deviceId),
                                size: KaamButtonSize.normal,
                                child:
                                    _loadingDevices.contains(
                                      '${userId}_$deviceId',
                                    )
                                    ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('...'),
                                        ],
                                      )
                                    : const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: KaamButton(
                                onPressed:
                                    _loadingDevices.contains(
                                      '${userId}_$deviceId',
                                    )
                                    ? null
                                    : () => _rejectDevice(userId, deviceId),
                                variant: KaamButtonVariant.ghost,
                                size: KaamButtonSize.normal,
                                child:
                                    _loadingDevices.contains(
                                      '${userId}_$deviceId',
                                    )
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
