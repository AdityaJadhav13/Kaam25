import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../../features/auth/data/auth_data_source.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/user_data_source.dart';
import '../../core/services/secure_storage_service.dart';
import 'auth_state.dart';

/// AuthController - Handles authentication state with REAL-TIME Firestore listening
///
/// ARCHITECTURE:
/// - Firebase Auth is the SOURCE OF TRUTH for authentication (who are you?)
/// - Firestore is the SOURCE OF TRUTH for authorization (are you allowed?)
/// - This controller listens to BOTH and computes the correct AuthState
///
/// FLOW:
/// 1. Listen to Firebase Auth state changes
/// 2. When user signs in, bootstrap their Firestore doc if needed
/// 3. Start listening to Firestore user doc for real-time status updates
/// 4. When admin approves/blocks, the stream auto-updates → router auto-navigates
class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required this.authRepository,
    required this.userDataSource,
    required this.storageService,
  }) : super(AuthState.loading()) {
    _authSub = authRepository.authStateChanges().listen(_handleAuthChange);
  }

  final AuthRepository authRepository;
  final UserDataSource userDataSource;
  final SecureStorageService storageService;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<Map<String, dynamic>?>? _userDocSub;
  String? _currentUid;
  String? _deviceId;

  /// Sign in with email and password
  Future<void> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(busy: true, message: null);
    try {
      debugPrint('🔐 Attempting email/password sign-in for: $email');
      await authRepository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Email/password sign-in successful');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Auth error: ${e.code} - ${e.message}');
      state = state.copyWith(busy: false, message: e.message);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      state = state.copyWith(
        busy: false,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Sign in with Google
  Future<void> loginWithGoogle() async {
    state = state.copyWith(busy: true, message: null);
    try {
      debugPrint('🔐 Attempting Google sign-in...');
      await authRepository.signInWithGoogle();
      debugPrint('✅ Google sign-in successful');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Auth error: ${e.code} - ${e.message}');
      state = state.copyWith(busy: false, message: e.message);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      state = state.copyWith(
        busy: false,
        message: 'Google sign-in failed. Please try again.',
      );
    }
  }

  /// Sign out - ONLY way to clear auth state
  Future<void> logout() async {
    try {
      // Cancel Firestore listener first
      await _userDocSub?.cancel();
      _userDocSub = null;
      _currentUid = null;

      await authRepository.signOut();
      await storageService.clearAll();
      debugPrint('✅ Logged out successfully');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
    }
  }

  /// Handle Firebase Auth state changes
  /// This is triggered on:
  /// - App startup (if user was previously logged in)
  /// - User signs in
  /// - User signs out
  Future<void> _handleAuthChange(User? firebaseUser) async {
    // Cancel any existing Firestore listener
    await _userDocSub?.cancel();
    _userDocSub = null;

    if (firebaseUser == null) {
      debugPrint('🔓 User signed out or not logged in');
      _currentUid = null;
      _deviceId = null;
      state = AuthState.unauthenticated();
      return;
    }

    debugPrint('🔐 Firebase Auth: User signed in: ${firebaseUser.email}');
    _currentUid = firebaseUser.uid;
    state = AuthState.loading();

    try {
      // Get or create stable device ID (persists across app restarts)
      _deviceId = await storageService.getOrCreateDeviceId();
      debugPrint('📱 Device ID: $_deviceId');

      // Check if user document exists in Firestore
      final exists = await userDataSource.userExists(firebaseUser.uid);

      if (!exists) {
        // First time user - call Cloud Function to create user document
        // Server decides role/approval based on SUPER_ADMIN_UID
        debugPrint('📝 Calling bootstrapUser Cloud Function...');
        await userDataSource.bootstrapUser(firebaseUser, _deviceId!);
        debugPrint('✅ User bootstrapped by server');
      }

      // Start REAL-TIME Firestore listener for user document
      // This is the key fix - we now listen continuously for changes
      _startUserDocStream(firebaseUser.uid, _deviceId!);
    } catch (e) {
      debugPrint('❌ Error during auth setup: $e');
      state = state.copyWith(
        gate: AuthGate.unauthenticated,
        message: 'Failed to verify account status. Please try again.',
      );
    }
  }

  /// Start listening to Firestore user document for real-time status updates
  /// This enables automatic navigation when admin approves/blocks user
  void _startUserDocStream(String uid, String deviceId) {
    debugPrint('📡 Starting Firestore user stream for: $uid');

    _userDocSub = userDataSource
        .streamUser(uid)
        .listen(
          (userData) => _handleUserDataUpdate(userData, deviceId),
          onError: (e) {
            debugPrint('❌ Firestore stream error: $e');
            state = state.copyWith(
              gate: AuthGate.unauthenticated,
              message: 'Connection error. Please check your internet.',
            );
          },
        );
  }

  /// Handle real-time user document updates
  /// Called whenever the Firestore user doc changes (e.g., admin approves)
  ///
  /// INVARIANTS ENFORCED:
  /// 1. Blocked user → ALWAYS blocked gate
  /// 2. Unapproved user → ALWAYS pending gate
  /// 3. Unapproved device → ALWAYS device pending gate
  /// 4. Admin → ALWAYS authenticated (bypass all checks)
  Future<void> _handleUserDataUpdate(
    Map<String, dynamic>? userData,
    String deviceId,
  ) async {
    if (userData == null) {
      debugPrint('❌ [INVARIANT] User document not found - denying access');
      state = AuthState.unauthenticated();
      return;
    }

    final role = userData['role'] as String? ?? 'member';
    final isAdmin = role == 'admin';
    final isApproved = userData['approved'] == true;
    final isBlocked = userData['blocked'] == true;

    // Parse devices field robustly - handle both string list and object list
    final rawDevices = userData['devices'];
    List<String> devices = [];
    if (rawDevices is List) {
      for (final item in rawDevices) {
        if (item is String) {
          devices.add(item);
        } else if (item is Map) {
          // If devices are stored as objects, extract deviceId
          final id = item['deviceId'] ?? item['id'];
          if (id is String) devices.add(id);
        }
      }
    }
    final isDeviceApproved = devices.contains(deviceId);

    // ========== INVARIANT LOGGING (DEBUG) ==========
    debugPrint('╔════════════════════════════════════════╗');
    debugPrint('║       AUTHORIZATION CHECK              ║');
    debugPrint('╠════════════════════════════════════════╣');
    debugPrint('║ Role:           $role ${isAdmin ? '👑' : ''}');
    debugPrint('║ Approved:       $isApproved ${isApproved ? '✅' : '❌'}');
    debugPrint('║ Blocked:        $isBlocked ${isBlocked ? '🚫' : '✅'}');
    debugPrint('║ Device ID:      $deviceId');
    debugPrint(
      '║ Device Approved: $isDeviceApproved ${isDeviceApproved ? '✅' : '❌'}',
    );
    debugPrint('║ Devices:        ${devices.length} registered');
    debugPrint('╚════════════════════════════════════════╝');

    // ========== AUTHORIZATION ORDER (NON-NEGOTIABLE) ==========
    // 1. IF role == admin → allow (bypass all checks)
    // 2. ELSE IF blocked → blocked screen
    // 3. ELSE IF not approved → pending screen
    // 4. ELSE IF device not approved → device pending
    // 5. ELSE → app access
    // ==========================================================

    // CHECK 1: Admin bypass - admins get full access immediately
    if (isAdmin) {
      debugPrint(
        '👑 [INVARIANT-3] Admin user - full access granted (bypass all)',
      );
      _updateStateIfDifferent(AuthState.authenticated());
      return;
    }

    // CHECK 2: Is user blocked?
    // INVARIANT 1: Blocked user NEVER gets home access
    if (isBlocked) {
      debugPrint('🚫 [INVARIANT-1] User is blocked - MUST show blocked screen');
      assert(
        !isAdmin,
        'INVARIANT VIOLATION: Admin should never reach blocked check',
      );
      _updateStateIfDifferent(AuthState.blocked());
      return;
    }

    // CHECK 3: Is user approved?
    // INVARIANT 2: Unapproved user NEVER bypasses approval
    if (!isApproved) {
      debugPrint(
        '⏳ [INVARIANT-2] User not approved - MUST show pending screen',
      );
      _updateStateIfDifferent(AuthState.pendingApproval());
      return;
    }

    // CHECK 4: Is this device approved?
    // INVARIANT 5: Unapproved device NEVER gets content access
    if (!isDeviceApproved) {
      debugPrint(
        '📱 [INVARIANT-5] Device not approved - MUST show device pending',
      );
      // Create login_request for this device if it doesn't exist
      if (_currentUid != null) {
        await userDataSource.createLoginRequest(_currentUid!, deviceId);
      }
      _updateStateIfDifferent(AuthState.devicePending());
      return;
    }

    // CHECK 5: All checks passed → app access
    debugPrint(
      '✅ [INVARIANTS PASS] User authenticated, approved, and device approved',
    );
    _updateStateIfDifferent(AuthState.authenticated());
  }

  /// Only update state if the gate actually changed
  /// This prevents unnecessary rebuilds
  void _updateStateIfDifferent(AuthState newState) {
    if (state.gate != newState.gate) {
      debugPrint('🔄 Auth gate changed: ${state.gate} → ${newState.gate}');
      state = newState;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}

// Providers
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instance,
);

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  // iOS requires explicit clientId from Firebase options
  if (!kIsWeb && Platform.isIOS) {
    return GoogleSignIn(
      clientId: DefaultFirebaseOptions.ios.iosClientId,
      scopes: ['email', 'profile'],
    );
  }
  // Android uses google-services.json for configuration
  // serverClientId is the Web Client ID from Firebase Console
  return GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '388870218082-hn3afnnstb8sd3o3q9p2ku0docrcl268.apps.googleusercontent.com',
  );
});

final authDataSourceProvider = Provider<AuthDataSource>(
  (ref) => FirebaseAuthDataSource(
    firebaseAuth: ref.read(firebaseAuthProvider),
    googleSignIn: ref.read(googleSignInProvider),
  ),
);

final userDataSourceProvider = Provider<UserDataSource>(
  (ref) => FirestoreUserDataSource(
    firestore: ref.read(firestoreProvider),
    functions: ref.read(firebaseFunctionsProvider),
  ),
);

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(dataSource: ref.read(authDataSourceProvider)),
);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    authRepository: ref.read(authRepositoryProvider),
    userDataSource: ref.read(userDataSourceProvider),
    storageService: ref.read(secureStorageServiceProvider),
  ),
);

// Provides the current Firebase User (for pages that need user data)
final currentUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
