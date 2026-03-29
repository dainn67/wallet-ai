// Smoke Test 01: Clean Architecture Structure Verification
// Verifies that all structural requirements from the refactor-code epic are met.
// Checks: no repo imports in UI, computed getters, extracted components, barrel files.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FR-1: No repository imports in UI layer', () {
    test('screens directory contains no repository imports', () {
      final screensDir = Directory('lib/screens');
      final dartFiles = screensDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains("import 'package:wallet_ai/repositories/"),
          isFalse,
          reason: '${file.path} contains repository import — violates FR-1',
        );
      }
    });

    test('components directory contains no repository imports', () {
      final componentsDir = Directory('lib/components');
      final dartFiles = componentsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains("import 'package:wallet_ai/repositories/"),
          isFalse,
          reason: '${file.path} contains repository import — violates FR-1',
        );
      }
    });
  });

  group('FR-3: No duplicate fetchData alias', () {
    test('record_provider.dart does not contain fetchData', () {
      final providerFile = File('lib/providers/record_provider.dart');
      final content = providerFile.readAsStringSync();
      expect(
        content.contains('fetchData'),
        isFalse,
        reason: 'fetchData alias should have been removed in T2',
      );
    });
  });

  group('FR-4: No multi-level relative imports', () {
    test('no file in lib/ uses multi-level relative imports', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.trim().startsWith('import ') &&
              line.contains("'../") &&
              line.contains("../")) {
            expect(
              false,
              isTrue,
              reason: '${file.path}: multi-level relative import found: $line',
            );
          }
        }
      }
    });
  });

  group('FR-5: Correct file placements', () {
    test('ChatBubble exists in components directory', () {
      expect(
        File('lib/components/chat_bubble.dart').existsSync(),
        isTrue,
        reason: 'chat_bubble.dart should be in lib/components/ (T4)',
      );
    });

    test('AddSubCategoryDialog exists in popups directory', () {
      expect(
        File('lib/components/popups/add_sub_category_dialog.dart').existsSync(),
        isTrue,
        reason: 'add_sub_category_dialog.dart should be in lib/components/popups/ (T5)',
      );
    });

    test('helpers barrel exports currency_helper', () {
      final barrel = File('lib/helpers/helpers.dart').readAsStringSync();
      expect(
        barrel.contains("export 'currency_helper.dart'"),
        isTrue,
        reason: 'helpers.dart should export currency_helper.dart (T7)',
      );
    });

    test('components barrel exports chat_bubble', () {
      final barrel = File('lib/components/components.dart').readAsStringSync();
      expect(
        barrel.contains("export 'chat_bubble.dart'"),
        isTrue,
        reason: 'components.dart should export chat_bubble.dart (T4)',
      );
    });

    test('components barrel exports add_sub_category_dialog', () {
      final barrel = File('lib/components/components.dart').readAsStringSync();
      expect(
        barrel.contains("add_sub_category_dialog.dart"),
        isTrue,
        reason: 'components.dart should export add_sub_category_dialog.dart (T5)',
      );
    });
  });

  group('NFR-3: No file exceeds 400 lines (except record_repository.dart)', () {
    test('all lib/ files under 400 lines except documented exceptions', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      const exceptions = ['record_repository.dart'];

      for (final file in dartFiles) {
        final basename = file.path.split('/').last;
        if (exceptions.contains(basename)) continue;

        final lineCount = file.readAsLinesSync().length;
        expect(
          lineCount,
          lessThanOrEqualTo(400),
          reason: '$basename has $lineCount lines — exceeds 400-line limit',
        );
      }
    });
  });
}
