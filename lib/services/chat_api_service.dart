import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/services/api_exception.dart';

class ChatApiService {
  static final ChatApiService _instance = ChatApiService._internal();

  factory ChatApiService({http.Client? client, AppConfig? config}) {
    if (client != null) _instance._client = client;
    if (config != null) _instance._config = config;
    return _instance;
  }

  ChatApiService._internal() : _client = http.Client(), _config = AppConfig();

  http.Client _client;
  AppConfig _config;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'text/event-stream',
  };

  Stream<String> streamChat(String message) async* {
    final uri = Uri.parse('${_config.baseUrl}/chat/stream');

    try {
      final request = http.Request('POST', uri);
      request.headers.addAll(_headers);
      request.body = jsonEncode({'message': message});

      final response = await _client.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        String errorMessage;
        dynamic data;
        try {
          data = jsonDecode(body);
          errorMessage = data['message'] ?? 'API returned an error.';
        } catch (_) {
          errorMessage = 'An unexpected error occurred.';
        }
        throw ApiException(
          message: errorMessage,
          statusCode: response.statusCode,
          data: data,
        );
      }

      yield* response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) => line.startsWith('data: '))
          .map((line) => line.substring(6))
          .where((data) => data != '[DONE]')
          .map((data) {
            try {
              final decoded = jsonDecode(data);
              return decoded['content'] as String? ?? '';
            } catch (_) {
              // If it's not JSON, it might be raw text content depending on implementation.
              // Based on typical SSE for LLMs, it's often JSON with a 'content' or 'choices' field.
              // Adjust based on project requirements or fallback.
              return data;
            }
          });
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }
}
