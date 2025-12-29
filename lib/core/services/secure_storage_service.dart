import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service using platform-specific secure storage
/// - Android: Uses Android Keystore
/// - iOS: Uses iOS Keychain
/// - Never stores sensitive data in plain text
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
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

  /// Clear all stored data (on logout)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Clear specific key
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
