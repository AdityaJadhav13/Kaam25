/// AuthState with approval workflow
enum AuthGate {
  unauthenticated,
  loading,
  blocked, // User is blocked by admin
  pendingApproval, // User authenticated but not approved
  devicePending, // User approved but device not approved
  authenticated, // User authenticated AND approved AND device approved
}

class AuthState {
  const AuthState({required this.gate, this.message, this.busy = false});

  factory AuthState.unauthenticated() =>
      const AuthState(gate: AuthGate.unauthenticated);

  factory AuthState.loading() => const AuthState(gate: AuthGate.loading);

  factory AuthState.blocked() => const AuthState(gate: AuthGate.blocked);

  factory AuthState.pendingApproval() =>
      const AuthState(gate: AuthGate.pendingApproval);

  factory AuthState.devicePending() =>
      const AuthState(gate: AuthGate.devicePending);

  factory AuthState.authenticated() =>
      const AuthState(gate: AuthGate.authenticated);

  AuthState copyWith({AuthGate? gate, String? message, bool? busy}) {
    return AuthState(
      gate: gate ?? this.gate,
      message: message,
      busy: busy ?? this.busy,
    );
  }

  final AuthGate gate;
  final String? message;
  final bool busy;
}
