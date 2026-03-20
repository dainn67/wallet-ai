import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, prod }

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  final String appName = 'Wallet AI';

  bool _devMode = kDebugMode;
  bool get devMode => _devMode;

  final AppEnvironment environment = _getEnvironment();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _devMode = prefs.getBool('dev_mode') ?? kDebugMode;
  }

  Future<void> toggleDevMode() async {
    _devMode = !_devMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode', _devMode);
  }

  static AppEnvironment _getEnvironment() {
    const env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');
    switch (env) {
      case 'prod':
        return AppEnvironment.prod;
      case 'dev':
      default:
        return AppEnvironment.dev;
    }
  }

  String get baseUrl {
    if (!devMode) return 'https://4138-2405-4802-1d39-c3e0-a8b6-cb7d-92a5-977f.ngrok-free.app';
    return '${Platform.isIOS ? 'http://localhost' : 'http://[IP_ADDRESS]'}:8000';
  }

  Duration get connectTimeout => const Duration(seconds: 10);
  Duration get receiveTimeout => const Duration(seconds: 10);

  // API Tokens and Secrets
  String get mainChatApiKey => dotenv.env['MAIN_CHAT_API_KEY'] ?? '';
  String get otherSecretKey => dotenv.env['OTHER_SECRET_KEY'] ?? '';

  String getEnv(String key, {String defaultValue = ''}) => dotenv.env[key] ?? defaultValue;
}
