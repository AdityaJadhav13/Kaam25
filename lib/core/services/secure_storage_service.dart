import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Secure storage service using platform-specific secure storage
/// - Android: Uses Android Keystore
/// - iOS: Uses iOS Keychain
/// - Never stores sensitive data in plain text
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Keys
  static const String _keyAuthToken = 'auth_token';
  static const String _keyDeviceId = 'device_id';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';

  /// Store authentication token securely
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _keyAuthToken, value: token);
  }

  /// Retrieve authentication token
  Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyAuthToken);
  }

  /// Store device ID securely
  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: _keyDeviceId, value: deviceId);
  }

  /// Retrieve device ID
  Future<String?> getDeviceId() async {
    return await _storage.read(key: _keyDeviceId);
  }

  /// Store user ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Retrieve user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Store user email
  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: _keyUserEmail, value: email);
  }

  /// Retrieve user email
  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  /// Get or create a stable device ID (persists across app restarts)
  /// Uses UUID v4 for uniqueness, stored securely
  Future<String> getOrCreateDeviceId() async {
    String? deviceId = await _storage.read(key: _keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      // Generate new stable UUID for this device
      deviceId = const Uuid().v4();
      await _storage.write(key: _keyDeviceId, value: deviceId);
    }
    return deviceId;
  }

  /// Clear all stored data (on logout)
  /// NOTE: Does NOT clear device ID - device ID persists across logouts
  Future<void> clearAll() async {
    // Preserve device ID across logouts
    final deviceId = await _storage.read(key: _keyDeviceId);
    await _storage.deleteAll();
    // Restore device ID
    if (deviceId != null) {
      await _storage.write(key: _keyDeviceId, value: deviceId);
    }
  }

  /// Clear specific key
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
