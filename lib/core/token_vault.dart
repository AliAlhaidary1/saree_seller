import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenVault {
  TokenVault(this._prefs, {FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  static const _key = 'auth_token_v1';
  static const _legacyKey = 'token';
  static const _invalidatedKey = 'auth_token_invalidated';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<String?> read() async {
    if (_prefs.getBool(_invalidatedKey) == true) {
      try {
        await _secure.delete(key: _key);
      } catch (_) {}
      return null;
    }
    final secureValue = await _secure.read(key: _key);
    if (secureValue != null && secureValue.isNotEmpty) return secureValue;
    final legacy = _prefs.getString(_legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      await write(legacy);
      return legacy;
    }
    return null;
  }

  Future<void> write(String token) async {
    await _secure.write(key: _key, value: token);
    await _prefs.remove(_legacyKey);
    await _prefs.setBool(_invalidatedKey, false);
  }

  Future<void> clear() async {
    await _prefs.setBool(_invalidatedKey, true);
    await _prefs.remove(_legacyKey);
    try {
      await _secure.delete(key: _key);
    } catch (_) {}
  }
}
