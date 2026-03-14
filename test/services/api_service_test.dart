import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/services/api_exception.dart';
import 'package:wallet_ai/services/api_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockAppConfig extends Mock implements AppConfig {}

void main() {
  late ApiService apiService;
  late MockHttpClient mockClient;
  late MockAppConfig mockAppConfig;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    mockAppConfig = MockAppConfig();

    when(() => mockAppConfig.baseUrl).thenReturn('https://api.example.com');
    when(() => mockAppConfig.connectTimeout).thenReturn(const Duration(seconds: 5));

    apiService = ApiService(client: mockClient, config: mockAppConfig);
  });

  group('ApiService', () {
    test('get success returns response', () async {
      final responseBody = jsonEncode({'success': true});
      when(() => mockClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await apiService.get('/test');

      expect(jsonDecode(result.body), {'success': true});
      expect(result.statusCode, 200);
    });

    test('post success returns response', () async {
      final responseBody = jsonEncode({'id': 1});
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 201));

      final result = await apiService.post('/test', data: {'name': 'test'});

      expect(jsonDecode(result.body), {'id': 1});
      expect(result.statusCode, 201);
    });

    test('get throws ApiException on status 404', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async => http.Response('Not Found', 404));

      expect(() => apiService.get('/test'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)));
    });

    test('get throws ApiException on connection error', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers'))).thenThrow(Exception('Connection failed'));

      expect(() => apiService.get('/test'), throwsA(isA<ApiException>()));
    });
  });
}
