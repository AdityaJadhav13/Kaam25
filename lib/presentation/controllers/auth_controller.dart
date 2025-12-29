import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/device_service.dart';
import '../../features/auth/data/user_repository.dart';
import '../../features/auth/domain/app_user.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required this.authRepository,
    required this.userRepository,
    required this.deviceService,
  }) : super(AuthState.loading()) {
    _sub = authRepository.authStateChanges().listen(_handleAuthChange);
  }

  final AuthRepository authRepository;
  final UserRepository userRepository;
  final DeviceService deviceService;

  StreamSubscription<User?>? _sub;
  StreamSubscription<AppUser?>? _userSub;

  Future<void> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(busy: true, message: null);
    try {
      await authRepository.signInWithEmailPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        busy: false,
        message: e.message ?? 'Sign-in failed',
      );
    } catch (_) {
      state = state.copyWith(busy: false, message: 'Sign-in failed');
    }
  }

  Future<void> loginWithGoogle() async {
    state = state.copyWith(busy: true, message: null);
    try {
      await authRepository.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        busy: false,
        message: e.message ?? 'Google sign-in failed',
      );
    } catch (_) {
      state = state.copyWith(busy: false, message: 'Google sign-in failed');
    }
  }

  Future<void> logout() async {
    await authRepository.signOut();
    state = AuthState.unauthenticated();
  }

  Future<void> _handleAuthChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      state = AuthState.unauthenticated();
      return;
    }

    state = state.copyWith(gate: AuthGate.loading, busy: false, message: null);

    try {
      debugPrint('🔄 Auth handler: Getting device ID...');
      final deviceId = await deviceService.getOrCreateDeviceId();
      final deviceInfo = await deviceService.getDeviceInfo();
      debugPrint('✅ Device ID: $deviceId');

      debugPrint('🔄 Auth handler: Fetching user...');
      AppUser? user = await userRepository.fetchUser(firebaseUser.uid);

      if (user == null) {
        debugPrint('🔄 Auth handler: User not found, bootstrapping...');
        await userRepository.bootstrapUser(
          authUser: firebaseUser,
          deviceId: deviceId,
          deviceInfo: deviceInfo,
        );
        debugPrint('✅ Bootstrap complete, fetching user again...');
        user = await userRepository.fetchUser(firebaseUser.uid);
      } else {
        debugPrint('✅ User found, updating last login...');
        await userRepository.updateLastLogin(firebaseUser.uid);
      }

      if (user == null) {
        debugPrint('❌ User still null after bootstrap');
        state = state.copyWith(
          gate: AuthGate.unauthenticated,
          busy: false,
          message: 'Account record missing. Contact admin.',
        );
        return;
      }

      debugPrint('✅ User loaded: ${user.email}, role: ${user.role}');
      final gate = _resolveGate(user: user, deviceId: deviceId);
      debugPrint('✅ Gate resolved: $gate');

      if (gate == AuthGate.devicePending) {
        await userRepository.enqueueDeviceApproval(
          uid: user.id,
          deviceId: deviceId,
          deviceInfo: deviceInfo,
        );
      }

      state = state.copyWith(
        gate: gate,
        user: user,
        deviceId: deviceId,
        busy: false,
        message: null,
      );

      _listenToUserDoc(user.id, deviceId);
    } catch (e, stackTrace) {
      debugPrint('❌ Auth error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        gate: AuthGate.unauthenticated,
        busy: false,
        message: 'Authentication error: $e',
      );
    }
  }

  AuthGate _resolveGate({required AppUser user, required String deviceId}) {
    if (user.isAdmin) return AuthGate.authorized;
    if (user.blocked) return AuthGate.blocked;
    if (!user.approved) return AuthGate.pendingApproval;
    if (!user.devices.contains(deviceId)) return AuthGate.devicePending;
    return AuthGate.authorized;
  }

  void _listenToUserDoc(String uid, String deviceId) {
    _userSub?.cancel();
    _userSub = userRepository.streamUser(uid).listen((appUser) {
      if (appUser == null) {
        state = AuthState.unauthenticated();
        return;
      }

      final gate = _resolveGate(
        user: appUser,
        deviceId: state.deviceId ?? deviceId,
      );
      state = state.copyWith(
        gate: gate,
        user: appUser,
        deviceId: state.deviceId ?? deviceId,
        busy: false,
        message: null,
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn(
    // iOS clientId - for iOS authentication
    clientId:
        '388870218082-ute4pugo7ebkt81b0q6fmmhjikdgksu6.apps.googleusercontent.com',
    // Web/Server clientId - required for Android authentication
    serverClientId:
        '388870218082-hn3afnnstb8sd3o3q9p2ku0docrcl268.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  ),
);
final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instance,
);

final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService());
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.read(firebaseAuthProvider),
    ref.read(googleSignInProvider),
  ),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(
    ref.read(firebaseFirestoreProvider),
    ref.read(firebaseFunctionsProvider),
  ),
);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    authRepository: ref.read(authRepositoryProvider),
    userRepository: ref.read(userRepositoryProvider),
    deviceService: ref.read(deviceServiceProvider),
  ),
);
