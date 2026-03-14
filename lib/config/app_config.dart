enum AppEnvironment { dev, prod }

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  AppEnvironment environment = AppEnvironment.dev;

  String get baseUrl {
    switch (environment) {
      case AppEnvironment.dev:
        return 'https://api.dev.wallet-ai.com';
      case AppEnvironment.prod:
        return 'https://api.wallet-ai.com';
    }
  }

  Duration get connectTimeout => const Duration(seconds: 10);
  Duration get receiveTimeout => const Duration(seconds: 10);
}
