import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:wallet_ai/configs/configs.dart';

class ApiConfig {
  static final ApiConfig _instance = ApiConfig._internal();

  factory ApiConfig() => _instance;

  ApiConfig._internal();

  // Endpoints
  static const String updateUserPatternPath = '/api/single-question/walletai-analyze-pattern';
  static const String chatFlowPath = '/api/chat-flow/wallet-ai-chatbot';

  String get baseUrl {
    if (!AppConfig().devMode) return 'https://chatbot-flow-server.onrender.com';
    return '${Platform.isIOS ? 'http://localhost' : 'http://192.168.88.93'}:8000';
  }

  Duration get connectTimeout => const Duration(seconds: 10);
  Duration get receiveTimeout => const Duration(seconds: 10);

  // API Tokens and Secrets
  String get mainChatApiKey => dotenv.env['MAIN_CHAT_API_KEY'] ?? '';
  String get patternSyncApiKey => dotenv.env['PATTERN_SYNC_API_KEY'] ?? '';
  String get otherSecretKey => dotenv.env['OTHER_SECRET_KEY'] ?? '';

  String getEnv(String key, {String defaultValue = ''}) => dotenv.env[key] ?? defaultValue;
}
