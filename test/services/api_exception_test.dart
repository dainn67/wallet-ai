import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/services/api_exception.dart';

void main() {
  group('ApiException', () {
    test('fromDioException maps connectionTimeout correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      );
      final apiException = ApiException.fromDioException(dioException);
      expect(apiException.message, 'Connection timed out.');
    });

    test('fromDioException maps badResponse 401 correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 401,
          statusMessage: 'Unauthorized',
        ),
      );
      final apiException = ApiException.fromDioException(dioException);
      expect(apiException.message, 'Unauthorized. Please login again.');
      expect(apiException.statusCode, 401);
    });

    test('fromDioException maps badResponse 404 correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 404,
          statusMessage: 'Not Found',
        ),
      );
      final apiException = ApiException.fromDioException(dioException);
      expect(apiException.message, 'Resource not found.');
      expect(apiException.statusCode, 404);
    });

    test('fromDioException maps badResponse 500 correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 500,
          statusMessage: 'Internal Server Error',
        ),
      );
      final apiException = ApiException.fromDioException(dioException);
      expect(apiException.message, 'Internal server error.');
      expect(apiException.statusCode, 500);
    });

    test('fromDioException maps connectionError correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
      final apiException = ApiException.fromDioException(dioException);
      expect(apiException.message, 'No internet connection.');
    });

    test('toString returns expected format', () {
      final apiException = ApiException(message: 'Test message', statusCode: 400);
      expect(apiException.toString(), 'ApiException: Test message (Status: 400)');
    });
  });
}
