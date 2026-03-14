import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_ai/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'test_key': 'test_value'});
      await StorageService.init();
    });

    test('getString returns value for existing key', () {
      final service = StorageService();
      expect(service.getString('test_key'), 'test_value');
    });

    test('setString updates value', () async {
      final service = StorageService();
      await service.setString('new_key', 'new_value');
      expect(service.getString('new_key'), 'new_value');
    });

    test('containsKey works correctly', () {
      final service = StorageService();
      expect(service.containsKey('test_key'), isTrue);
      expect(service.containsKey('non_existent'), isFalse);
    });

    test('remove deletes value', () async {
      final service = StorageService();
      await service.remove('test_key');
      expect(service.getString('test_key'), isNull);
    });
  });
}
