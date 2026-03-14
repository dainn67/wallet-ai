import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/services/api_exception.dart';

void main() {
  group('ApiException', () {
    test('initializes with correct values', () {
      final apiException = ApiException(
        message: 'Test message',
        statusCode: 404,
        data: {'error': 'not found'},
      );
      
      expect(apiException.message, 'Test message');
      expect(apiException.statusCode, 404);
      expect(apiException.data, {'error': 'not found'});
    });

    test('toString returns expected format', () {
      final apiException = ApiException(message: 'Test message', statusCode: 400);
      expect(apiException.toString(), 'ApiException: Test message (Status: 400)');
    });
  });
}
