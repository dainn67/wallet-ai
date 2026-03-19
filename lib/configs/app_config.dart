import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppEnvironment { dev, prod }

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  final AppEnvironment environment = _getEnvironment();

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
    switch (environment) {
      case AppEnvironment.dev:
        return 'http://localhost:8000';
      case AppEnvironment.prod:
        return 'https://4138-2405-4802-1d39-c3e0-a8b6-cb7d-92a5-977f.ngrok-free.app';
    }
  }

  Duration get connectTimeout => const Duration(seconds: 10);
  Duration get receiveTimeout => const Duration(seconds: 10);

  // API Tokens and Secrets
  String get mainChatApiKey => dotenv.env['MAIN_CHAT_API_KEY'] ?? '';
  String get otherSecretKey => dotenv.env['OTHER_SECRET_KEY'] ?? '';

  String getEnv(String key, {String defaultValue = ''}) => dotenv.env[key] ?? defaultValue;
}
