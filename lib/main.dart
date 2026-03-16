import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/controllers/theme_controller.dart';
import 'firebase_options.dart';
import 'presentation/controllers/app_router.dart';

/// Simplified main.dart - Reset for clean slate
/// Only Firebase initialization is kept
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase only
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Register top-level background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    runApp(const ProviderScope(child: Kaam25App()));
  } catch (e) {
    runApp(_InitErrorApp(error: e.toString()));
  }
}

class Kaam25App extends ConsumerWidget {
  const Kaam25App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'Firebase init failed:\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
