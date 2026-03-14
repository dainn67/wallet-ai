import 'package:http/http.dart' as http;
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/helpers/api_helper.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  static AppConfig _config = AppConfig();

  factory ApiService({http.Client? client, AppConfig? config}) {
    if (config != null) _config = config;
    return _instance;
  }

  ApiService._internal();

  String _getFullUrl(String path) {
    final baseUrl = _config.baseUrl;
    return baseUrl.endsWith('/') ? '$baseUrl${path.startsWith('/') ? path.substring(1) : path}' : '$baseUrl${path.startsWith('/') ? path : '/$path'}';
  }

  Future<String?> get(String path, {Map<String, String>? queryParameters, Map<String, String>? headers}) async {
    return APIHelper.get(_getFullUrl(path), query: queryParameters, headers: headers);
  }

  Future<String?> post(String path, {Object? data, Map<String, String>? headers}) async {
    return APIHelper.post(_getFullUrl(path), body: data, headers: headers);
  }

  Future<Stream<String>?> postStream(String path, {Object? data, String? token, Map<String, String>? headers}) async {
    return APIHelper.postStream(_getFullUrl(path), body: data, token: token, headers: headers);
  }
}
