import '../../features/auth/domain/app_user.dart';

enum AuthGate {
  unauthenticated,
  loading,
  pendingApproval,
  blocked,
  devicePending,
  authorized,
}

class AuthState {
  const AuthState({
    required this.gate,
    this.user,
    this.deviceId,
    this.message,
    this.busy = false,
  });

  factory AuthState.unauthenticated() =>
      const AuthState(gate: AuthGate.unauthenticated);

  factory AuthState.loading() => const AuthState(gate: AuthGate.loading);

  AuthState copyWith({
    AuthGate? gate,
    AppUser? user,
    String? deviceId,
    String? message,
    bool? busy,
  }) {
    return AuthState(
      gate: gate ?? this.gate,
      user: user ?? this.user,
      deviceId: deviceId ?? this.deviceId,
      message: message,
      busy: busy ?? this.busy,
    );
  }

  final AuthGate gate;
  final AppUser? user;
  final String? deviceId;
  final String? message;
  final bool busy;
}
