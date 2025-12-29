import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/kaam_badge.dart';
import '../controllers/announcements_controller.dart';
import '../controllers/main_nav_controller.dart';
import '../controllers/uploads_controller.dart';
import '../widgets/upload_progress_panel.dart';
import 'announcements_page.dart';
import 'chat_page.dart';
import 'home_page.dart';
import 'profile_page.dart';

class AppShellPage extends ConsumerWidget {
  const AppShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(mainTabProvider);
    final uploads = ref.watch(uploadsControllerProvider).uploads;

    // Real unread count from Firestore
    final unreadAnnouncements = ref.watch(unreadAnnouncementsCountProvider);
    const unreadChat = 0; // TODO: Implement chat unread count

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Stories removed
                const Divider(height: 1),
                Expanded(
                  child: switch (tab) {
                    MainTab.home => const HomePage(),
                    MainTab.chat => const ChatPage(),
                    MainTab.announcements => const AnnouncementsPage(),
                    MainTab.profile => const ProfilePage(),
                  },
                ),
                const Divider(height: 1),
                NavigationBar(
                  selectedIndex: tab.index,
                  onDestinationSelected: (i) {
                    ref.read(mainTabProvider.notifier).state =
                        MainTab.values[i];
                  },
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: _BadgeIcon(
                        icon: Icons.chat_bubble_outline,
                        badgeCount: unreadChat,
                      ),
                      selectedIcon: _BadgeIcon(
                        icon: Icons.chat_bubble,
                        badgeCount: unreadChat,
                      ),
                      label: 'Chat',
                    ),
                    NavigationDestination(
                      icon: _BadgeIcon(
                        icon: Icons.notifications_none,
                        badgeCount: unreadAnnouncements,
                      ),
                      selectedIcon: _BadgeIcon(
                        icon: Icons.notifications,
                        badgeCount: unreadAnnouncements,
                      ),
                      label: 'Announcements',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        UploadProgressPanel(
          uploads: uploads,
          onCancel: (id) =>
              ref.read(uploadsControllerProvider.notifier).cancelUpload(id),
          onDismiss: (id) =>
              ref.read(uploadsControllerProvider.notifier).dismissUpload(id),
        ),
      ],
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.badgeCount});

  final IconData icon;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (badgeCount > 0)
          Positioned(
            right: -8,
            top: -8,
            child: SizedBox(
              width: 22,
              height: 22,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: KaamBadge(
                  label: '$badgeCount',
                  variant: KaamBadgeVariant.destructive,
                  compact: true,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
