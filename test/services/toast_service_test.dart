import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ToastService', () {
    test('is a singleton', () {
      final instance1 = ToastService();
      final instance2 = ToastService();
      expect(instance1, same(instance2));
    });

    test('messengerKey is initialized', () {
      expect(ToastService.messengerKey, isA<GlobalKey<ScaffoldMessengerState>>());
    });

    test('showSuccess does not throw when messengerKey.currentState is null', () {
      expect(() => ToastService().showSuccess('Test'), returnsNormally);
    });

    test('showError does not throw when messengerKey.currentState is null', () {
      expect(() => ToastService().showError('Test'), returnsNormally);
    });

    test('showWarning does not throw when messengerKey.currentState is null', () {
      expect(() => ToastService().showWarning('Test'), returnsNormally);
    });
  });
}
