import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/services/api_exception.dart';
import 'package:wallet_ai/services/api_service.dart';

class MockDio extends Mock implements Dio {
  @override
  final BaseOptions options = BaseOptions();
  
  @override
  final Interceptors interceptors = Interceptors();
}

class MockAppConfig extends Mock implements AppConfig {}

void main() {
  late ApiService apiService;
  late MockDio mockDio;
  late MockAppConfig mockAppConfig;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    mockAppConfig = MockAppConfig();
    
    when(() => mockAppConfig.baseUrl).thenReturn('https://api.example.com');
    when(() => mockAppConfig.connectTimeout).thenReturn(const Duration(seconds: 5));
    when(() => mockAppConfig.receiveTimeout).thenReturn(const Duration(seconds: 5));

    apiService = ApiService(dio: mockDio, config: mockAppConfig);
  });

  group('ApiService', () {
    test('initializes with correct options', () {
      final realDio = Dio();
      final service = ApiService(dio: realDio, config: mockAppConfig);
      expect(realDio.options.baseUrl, 'https://api.example.com');
      expect(realDio.options.connectTimeout, const Duration(seconds: 5));
      expect(realDio.options.receiveTimeout, const Duration(seconds: 5));
      expect(realDio.options.headers['Content-Type'], 'application/json');
    });

    test('adds PrettyDioLogger interceptor', () {
      final realDio = Dio();
      final service = ApiService(dio: realDio, config: mockAppConfig);
      expect(realDio.interceptors.any((i) => i is PrettyDioLogger), true);
    });

    test('get success returns response', () async {
      final response = Response(
        requestOptions: RequestOptions(path: '/test'),
        data: {'success': true},
        statusCode: 200,
      );

      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => response);

      final result = await apiService.get<Map<String, dynamic>>('/test');

      expect(result.data, {'success': true});
      expect(result.statusCode, 200);
    });

    test('post success returns response', () async {
      final response = Response(
        requestOptions: RequestOptions(path: '/test'),
        data: {'id': 1},
        statusCode: 201,
      );

      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => response);

      final result = await apiService.post<Map<String, dynamic>>('/test', data: {'name': 'test'});

      expect(result.data, {'id': 1});
      expect(result.statusCode, 201);
    });

    test('get throws ApiException on DioException', () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => apiService.get<Map<String, dynamic>>('/test'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
