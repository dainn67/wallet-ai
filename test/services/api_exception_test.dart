import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/services/api_exception.dart';

void main() {
  group('ApiException Tests', () {
    test('fromDioException maps connectionTimeout to correct message', () {
      final dioError = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: ''),
      );
      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, 'Connection timed out.');
    });

    test('fromDioException maps badResponse to status message and code', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusMessage: 'Not Found',
          statusCode: 404,
          data: {'error': 'Resource not found'},
        ),
      );
      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, 'Not Found');
      expect(exception.statusCode, 404);
      expect(exception.data, {'error': 'Resource not found'});
    });

    test('fromDioException maps connectionError to correct message', () {
      final dioError = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: ''),
      );
      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, 'No internet connection.');
    });
  });
}
