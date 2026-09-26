import 'package:shared_preferences/shared_preferences.dart';

class UtilsStorage {
  static SharedPreferences? _prefs2;

  static Future<void> init() async {
    _prefs2 = await SharedPreferences.getInstance();
  }

  static Future<void> saveString(String key, String value) async {
    if (_prefs2 == null) await init();
    await _prefs2!.setString(key, value);
  }

  static Future<void> saveDouble(String key, double value) async {
    if (_prefs2 == null) await init();
    await _prefs2!.setDouble(key, value);
  }

  static String? readString(String key) {
    if (_prefs2 == null) {
      throw Exception("SharedPreferences not initialized. Call init() first.");
    }
    return _prefs2!.getString(key);
  }

  static Future<void> saveInt(String key, int value) async {
    if (_prefs2 == null) await init();
    await _prefs2!.setInt(key, value);
  }

  static double? readDouble(String key) {
    if (_prefs2 == null) {
      throw Exception("SharedPreferences not initialized. Call init() first.");
    }
    return _prefs2!.getDouble(key);
  }

  static int? readInt(String key) {
    if (_prefs2 == null) {
      throw Exception("SharedPreferences not initialized. Call init() first.");
    }
    return _prefs2!.getInt(key);
  }

  static int? readInit(String key) {
    if (_prefs2 == null) {
      throw Exception("SharedPreferences not initialized. Call init() first.");
    }
    return _prefs2!.getInt(key);
  }

  static Future<void> saveBool(String key, bool value) async {
    if (_prefs2 == null) await init();
    await _prefs2!.setBool(key, value);
  }

  static bool? readBool(String key) {
    if (_prefs2 == null) {
      throw Exception("SharedPreferences not initialized. Call init() first.");
    }
    return _prefs2!.getBool(key);
  }

  static Future<void> saveStringList(String key, List<String> value) async {
    if (_prefs2 == null) await init();
    await _prefs2!.setStringList(key, value);
  }

  static List<String>? readStringList(String key) {
    if (_prefs2 == null) {
      throw Exception("SharedPreferences not initialized. Call init() first.");
    }
    return _prefs2!.getStringList(key);
  }

  static Future<void> deleteValue(String key) async {
    if (_prefs2 == null) await init();
    await _prefs2!.remove(key);
  }

  static Future<void> clearAll() async {
    if (_prefs2 == null) await init();
    await _prefs2!.clear();
  }
}
