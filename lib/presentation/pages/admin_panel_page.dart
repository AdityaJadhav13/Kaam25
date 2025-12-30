import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
          'Are you sure you want to block this user? They will lose access to the app.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Device Requests'),
          ],
        ),
      ),
      body: ContentMaxWidth(
        child: TabBarView(
          controller: _tabController,
          children: [_buildUsersTab(), _buildDeviceRequestsTab()],
        ),
      ),
    );
  }

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
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
                          'Devices: ${(userData['devices'] as List?)?.length ?? 0}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    if (!approved || blocked) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!approved)
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
                          if (!approved && !blocked) const SizedBox(width: 8),
                          if (!blocked)
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

  Widget _buildDeviceRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('login_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return const Center(child: Text('No pending device requests'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final userId = requestData['userId'] as String? ?? '';
            final deviceId = requestData['deviceId'] as String? ?? '';
            final deviceInfo = requestData['deviceInfo'] as Map? ?? {};
            final platform = deviceInfo['platform'] as String? ?? 'Unknown';
            final model = deviceInfo['model'] as String? ?? 'Unknown';

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, userSnapshot) {
                final userName = userSnapshot.hasData
                    ? ((userSnapshot.data!.data()
                                  as Map<String, dynamic>?)?['name']
                              as String? ??
                          'Unknown')
                    : 'Loading...';
                final userEmail = userSnapshot.hasData
                    ? ((userSnapshot.data!.data()
                                  as Map<String, dynamic>?)?['email']
                              as String? ??
                          'Unknown')
                    : '';

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
                          value: '${deviceId.substring(0, 16)}...',
                        ),
                        const SizedBox(height: 12),
                        KaamButton(
                          onPressed:
                              _loadingDevices.contains('${userId}_$deviceId')
                              ? null
                              : () => _approveDevice(userId, deviceId),
                          fullWidth: true,
                          size: KaamButtonSize.normal,
                          child: _loadingDevices.contains('${userId}_$deviceId')
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Approving...'),
                                  ],
                                )
                              : const Text('Approve Device'),
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
