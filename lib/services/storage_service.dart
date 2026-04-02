import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  static SharedPreferences? _prefsInstance;
  SharedPreferences? get _prefs => _prefsInstance;

  // Keys
  static const String keyCurrency = 'user_currency';
  static const String keyLastPatternUpdateTime = 'last_pattern_update_time';
  static const String keyUserPattern = 'user_pattern';

  factory StorageService() => _instance;

  StorageService._internal();

  /// Must be initialized in main before runApp
  static Future<void> init() async {
    _prefsInstance ??= await SharedPreferences.getInstance();
  }

  // Generic Getters
  String? getString(String key) => _prefs?.getString(key);
  bool? getBool(String key) => _prefs?.getBool(key);
  int? getInt(String key) => _prefs?.getInt(key);
  double? getDouble(String key) => _prefs?.getDouble(key);
  List<String>? getStringList(String key) => _prefs?.getStringList(key);

  // Generic Setters
  Future<bool> setString(String key, String value) =>
      _prefs?.setString(key, value) ?? Future.value(false);
  Future<bool> setBool(String key, bool value) => _prefs?.setBool(key, value) ?? Future.value(false);
  Future<bool> setInt(String key, int value) => _prefs?.setInt(key, value) ?? Future.value(false);
  Future<bool> setDouble(String key, double value) =>
      _prefs?.setDouble(key, value) ?? Future.value(false);
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs?.setStringList(key, value) ?? Future.value(false);

  // Helper Methods
  bool containsKey(String key) => _prefs?.containsKey(key) ?? false;
  Future<bool> remove(String key) => _prefs?.remove(key) ?? Future.value(false);
  Future<bool> clear() => _prefs?.clear() ?? Future.value(false);
}
