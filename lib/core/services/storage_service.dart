import 'package:shared_preferences/shared_preferences.dart';

/// Storage Service for managing local data (JWT tokens, user data, etc.)
class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyDeviceId = 'device_id';
  static const String _keyPhone = 'user_phone';
  static const String _keyName = 'user_name';

  /// Save authentication token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    // Debug log to help verify token saving during development
    try {
      // ignore: avoid_print
      print(
        '✅ Saved auth token (first 16 chars): ${token.substring(0, token.length > 16 ? 16 : token.length)}',
      );
    } catch (_) {}
  }

  /// Get authentication token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    try {
      if (token != null && token.isNotEmpty) {
        // ignore: avoid_print
        print(
          '🔍 Retrieved auth token (first 16 chars): ${token.substring(0, token.length > 16 ? 16 : token.length)}',
        );
      } else {
        // ignore: avoid_print
        print('🔍 No auth token in storage');
      }
    } catch (_) {}
    return token;
  }

  /// Save user data
  static Future<void> saveUserData({
    required String userId,
    required String deviceId,
    required String phone,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyDeviceId, deviceId);
    await prefs.setString(_keyPhone, phone);
    if (name != null) {
      await prefs.setString(_keyName, name);
    }
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Get device ID
  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId);
  }

  /// Get user phone
  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  /// Get user name
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  /// Clear all stored data (logout)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyName);
    // ignore: avoid_print
    print('🔒 Cleared local storage (logout)');
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Save boolean value
  static Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Get boolean value
  static Future<bool?> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  /// Save emergency contacts to local cache
  static Future<void> cacheContacts(String contactsJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_contacts', contactsJson);
    await prefs.setString(
      'contacts_cached_at',
      DateTime.now().toIso8601String(),
    );
    print('✅ Cached emergency contacts locally');
  }

  /// Get cached emergency contacts
  static Future<String?> getCachedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cached_contacts');
  }

  /// Clear cached contacts
  static Future<void> clearCachedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_contacts');
    await prefs.remove('contacts_cached_at');
  }
}
