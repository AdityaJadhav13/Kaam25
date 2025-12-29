import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/controllers/app_router.dart';
import 'core/services/screen_security_service.dart';
import 'core/services/presence_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize screen security service
    final screenSecurity = ScreenSecurityService(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
    await screenSecurity.initialize();

    // Initialize presence service
    final presenceService = PresenceService(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
    presenceService.setupLifecycleTracking();

    // Set user online when app starts
    if (FirebaseAuth.instance.currentUser != null) {
      await presenceService.goOnline();
    }

    runApp(
      ProviderScope(
        overrides: [
          screenSecurityServiceProvider.overrideWithValue(screenSecurity),
          presenceServiceProvider.overrideWithValue(presenceService),
        ],
        child: const Kaam25App(),
      ),
    );
  } catch (e) {
    runApp(_InitErrorApp(error: e.toString()));
  }
}

// Provider for screen security service
final screenSecurityServiceProvider = Provider<ScreenSecurityService>((ref) {
  throw UnimplementedError('ScreenSecurityService must be overridden in main');
});

// Provider for presence service
final presenceServiceProvider = Provider<PresenceService>((ref) {
  throw UnimplementedError('PresenceService must be overridden in main');
});

class Kaam25App extends ConsumerStatefulWidget {
  const Kaam25App({super.key});

  @override
  ConsumerState<Kaam25App> createState() => _Kaam25AppState();
}

class _Kaam25AppState extends ConsumerState<Kaam25App> {
  @override
  void initState() {
    super.initState();

    // Set up iOS screenshot detection listener
    if (Platform.isIOS) {
      // Note: screen_protector package will detect screenshots automatically
      // when protectDataLeakageOn() is called
      // The detection happens through the ScreenProtector.preventScreenshotOn() method
      // which is already called in ScreenSecurityService.initialize()
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }

  @override
  void dispose() {
    ref.read(screenSecurityServiceProvider).dispose();
    super.dispose();
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
