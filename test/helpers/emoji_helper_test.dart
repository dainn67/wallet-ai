import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/helpers/emoji_helper.dart';

void main() {
  group('isEmojiCodepoint', () {
    test('returns true for modern emoji range (U+1F300–U+1FAFF)', () {
      expect(isEmojiCodepoint(0x1F600), isTrue); // 😀
      expect(isEmojiCodepoint(0x1F300), isTrue);
      expect(isEmojiCodepoint(0x1FAFF), isTrue);
    });

    test('returns true for misc symbols range (U+2600–U+27BF)', () {
      expect(isEmojiCodepoint(0x2614), isTrue); // ☔
      expect(isEmojiCodepoint(0x2600), isTrue);
      expect(isEmojiCodepoint(0x27BF), isTrue);
    });

    test('returns true for misc technical range (U+2300–U+23FF)', () {
      expect(isEmojiCodepoint(0x23F0), isTrue); // ⏰
      expect(isEmojiCodepoint(0x2300), isTrue);
      expect(isEmojiCodepoint(0x23FF), isTrue);
    });

    test('returns true for regional indicators (U+1F1E6–U+1F1FF)', () {
      expect(isEmojiCodepoint(0x1F1FB), isTrue); // 🇻
      expect(isEmojiCodepoint(0x1F1F3), isTrue); // 🇳
    });

    test('returns false for plain ASCII', () {
      expect(isEmojiCodepoint('A'.codeUnitAt(0)), isFalse);
      expect(isEmojiCodepoint('z'.codeUnitAt(0)), isFalse);
      expect(isEmojiCodepoint('0'.codeUnitAt(0)), isFalse);
    });

    test('returns false for ZWJ codepoint alone', () {
      expect(isEmojiCodepoint(0x200D), isFalse);
    });
  });

  group('coerceEmoji', () {
    test('empty string returns default tag', () {
      expect(coerceEmoji(''), equals('🏷️'));
    });

    test('whitespace-only string returns default tag', () {
      expect(coerceEmoji('   '), equals('🏷️'));
    });

    test('plain text returns default tag', () {
      expect(coerceEmoji('food'), equals('🏷️'));
      expect(coerceEmoji('hello world'), equals('🏷️'));
    });

    test('single emoji passes through', () {
      expect(coerceEmoji('🍕'), equals('🍕'));
      expect(coerceEmoji('🚗'), equals('🚗'));
      expect(coerceEmoji('🏠'), equals('🏠'));
    });

    test('ZWJ emoji sequence passes through', () {
      // 👨‍💻 = U+1F468 ZWJ U+1F4BB
      expect(coerceEmoji('👨‍💻'), equals('👨‍💻'));
    });

    test('flag emoji passes through (regional indicators)', () {
      // 🇻🇳 = U+1F1FB + U+1F1F3
      expect(coerceEmoji('🇻🇳'), equals('🇻🇳'));
    });

    test('emoji mixed with text passes through (lenient)', () {
      // At least one emoji codepoint found → accept trimmed value
      expect(coerceEmoji('🍕 pizza'), equals('🍕 pizza'));
    });

    test('leading/trailing whitespace is trimmed before check', () {
      expect(coerceEmoji('  🍔  '), equals('🍔'));
    });

    test('default tag emoji itself passes through', () {
      expect(coerceEmoji('🏷️'), equals('🏷️'));
    });
  });
}
