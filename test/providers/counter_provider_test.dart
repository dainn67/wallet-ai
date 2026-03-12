import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/providers/counter_provider.dart';

void main() {
  group('CounterProvider', () {
    test('Initial count is 0', () {
      final counterProvider = CounterProvider();
      expect(counterProvider.count, 0);
    });

    test('increment() increases count by 1 and notifies listeners', () {
      final counterProvider = CounterProvider();
      var wasNotified = false;

      counterProvider.addListener(() {
        wasNotified = true;
      });

      counterProvider.increment();

      expect(counterProvider.count, 1);
      expect(wasNotified, true);
    });
  });
}
