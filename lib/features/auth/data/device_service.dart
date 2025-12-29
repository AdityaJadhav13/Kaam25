import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceService {
  DeviceService({FlutterSecureStorage? storage, DeviceInfoPlugin? deviceInfo})
    : _storage = storage ?? const FlutterSecureStorage(),
      _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _deviceInfo;

  static const _deviceKey = 'kaam25_device_id';

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final randomId = _generateSecureId();
    await _storage.write(key: _deviceKey, value: randomId);
    return randomId;
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'model': info.model,
          'manufacturer': info.manufacturer,
          'version': info.version.release,
        };
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        return {
          'platform': 'ios',
          'model': info.utsname.machine,
          'systemName': info.systemName,
          'systemVersion': info.systemVersion,
        };
      }

      return {'platform': defaultTargetPlatform.name, 'model': 'unknown'};
    } on PlatformException {
      return {'platform': defaultTargetPlatform.name, 'model': 'unavailable'};
    }
  }

  String _generateSecureId() {
    const chars = 'abcdef0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
