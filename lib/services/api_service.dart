import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/services/api_exception.dart';

class ApiService {
  final http.Client _client;
  final AppConfig _config;

  ApiService({http.Client? client, AppConfig? config})
      : _client = client ?? http.Client(),
        _config = config ?? AppConfig();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _getUri(String path, [Map<String, dynamic>? queryParameters]) {
    final baseUrl = _config.baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    final isHttps = _config.baseUrl.startsWith('https');
    
    // Extract host and base path if any
    final parts = baseUrl.split('/');
    final host = parts[0];
    final basePath = parts.skip(1).join('/');
    
    final fullPath = basePath.isEmpty ? path : '/$basePath$path';

    if (isHttps) {
      return Uri.https(host, fullPath, queryParameters?.map((k, v) => MapEntry(k, v.toString())));
    } else {
      return Uri.http(host, fullPath, queryParameters?.map((k, v) => MapEntry(k, v.toString())));
    }
  }

  Future<http.Response> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    String message;
    dynamic data;
    try {
      data = jsonDecode(response.body);
      message = data['message'] ?? 'API returned an error.';
    } catch (_) {
      message = switch (response.statusCode) {
        401 => 'Unauthorized. Please login again.',
        404 => 'Resource not found.',
        500 => 'Internal server error.',
        _ => 'An unexpected error occurred.',
      };
    }

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      data: data,
    );
  }

  Future<http.Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _client.get(
        _getUri(path, queryParameters),
        headers: _headers,
      ).timeout(_config.connectTimeout);
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  Future<http.Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _client.post(
        _getUri(path, queryParameters),
        headers: _headers,
        body: data != null ? jsonEncode(data) : null,
      ).timeout(_config.connectTimeout);
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  Future<http.Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _client.put(
        _getUri(path, queryParameters),
        headers: _headers,
        body: data != null ? jsonEncode(data) : null,
      ).timeout(_config.connectTimeout);
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  Future<http.Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _client.delete(
        _getUri(path, queryParameters),
        headers: _headers,
        body: data != null ? jsonEncode(data) : null,
      ).timeout(_config.connectTimeout);
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }
}
