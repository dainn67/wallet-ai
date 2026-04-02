import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  final String appName = 'Wally AI';
  String _version = '1.0.0';
  String _buildNumber = '1';

  String get fullVersion => 'v$_version($_buildNumber)';

  bool _devMode = kDebugMode;
  bool get devMode => _devMode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _devMode = prefs.getBool('dev_mode') ?? kDebugMode;
    
    final packageInfo = await PackageInfo.fromPlatform();
    _version = packageInfo.version;
    _buildNumber = packageInfo.buildNumber;
  }

  Future<void> toggleDevMode() async {
    _devMode = !_devMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode', _devMode);
  }
}
