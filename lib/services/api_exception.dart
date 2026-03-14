import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory ApiException.fromDioException(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(message: 'Connection timed out.');
      case DioExceptionType.badResponse:
        final response = dioException.response;
        return ApiException(
          message: response?.statusMessage ?? 'API returned an error.',
          statusCode: response?.statusCode,
          data: response?.data,
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'Request was cancelled.');
      case DioExceptionType.connectionError:
        return ApiException(message: 'No internet connection.');
      case DioExceptionType.unknown:
      default:
        return ApiException(message: 'An unexpected error occurred.');
    }
  }

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
