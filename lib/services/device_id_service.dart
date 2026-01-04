/// Device ID Service
/// 
/// Generates and persists a unique device identifier for guest users
/// Each device gets its own ID to isolate data between different phones
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  static const String _deviceIdKey = 'dino_device_id';
  String? _cachedDeviceId;

  /// Get the unique device ID
  /// Creates a new one if it doesn't exist
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate a new device ID
      deviceId = 'device_${const Uuid().v4()}';
      await prefs.setString(_deviceIdKey, deviceId);
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Get cached device ID synchronously (must call getDeviceId first)
  String get deviceId => _cachedDeviceId ?? 'anonymous';

  /// Initialize the service (call on app startup)
  Future<void> initialize() async {
    await getDeviceId();
  }
}
