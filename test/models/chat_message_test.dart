import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    final timestamp = DateTime(2026, 3, 14, 6, 50, 0);
    const id = 'test-id';
    const content = 'Hello, how can I help you?';
    const role = ChatRole.assistant;

    test('should create ChatMessage instance', () {
      final message = ChatMessage(
        id: id,
        role: role,
        content: content,
        timestamp: timestamp,
      );

      expect(message.id, id);
      expect(message.role, role);
      expect(message.content, content);
      expect(message.timestamp, timestamp);
    });

    test('toJson() should return correct Map', () {
      final message = ChatMessage(
        id: id,
        role: role,
        content: content,
        timestamp: timestamp,
      );

      final json = message.toJson();

      expect(json, {
        'id': id,
        'role': 'assistant',
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      });
    });

    test('fromJson() should return correct ChatMessage instance', () {
      final json = {
        'id': id,
        'role': 'assistant',
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

      final message = ChatMessage.fromJson(json);

      expect(message.id, id);
      expect(message.role, role);
      expect(message.content, content);
      expect(message.timestamp, timestamp);
    });

    test('copyWith() should return new instance with updated content', () {
      final message = ChatMessage(
        id: id,
        role: role,
        content: content,
        timestamp: timestamp,
      );

      const newContent = 'Updated content';
      final updatedMessage = message.copyWith(content: newContent);

      expect(updatedMessage.id, message.id);
      expect(updatedMessage.role, message.role);
      expect(updatedMessage.content, newContent);
      expect(updatedMessage.timestamp, message.timestamp);
      expect(updatedMessage, isNot(same(message)));
    });

    test('copyWith() should return new instance with other fields updated', () {
      final message = ChatMessage(
        id: id,
        role: role,
        content: content,
        timestamp: timestamp,
      );

      final newTimestamp = DateTime(2026, 3, 15);
      final updatedMessage = message.copyWith(
        id: 'new-id',
        role: ChatRole.user,
        timestamp: newTimestamp,
      );

      expect(updatedMessage.id, 'new-id');
      expect(updatedMessage.role, ChatRole.user);
      expect(updatedMessage.content, message.content);
      expect(updatedMessage.timestamp, newTimestamp);
    });

    test('operator == should return true for identical instances', () {
      final message1 = ChatMessage(
        id: id,
        role: role,
        content: content,
        timestamp: timestamp,
      );
      final message2 = ChatMessage(
        id: id,
        role: role,
        content: content,
        timestamp: timestamp,
      );

      expect(message1 == message2, isTrue);
      expect(message1.hashCode == message2.hashCode, isTrue);
    });
  });

  group('ChatRole', () {
    test('toJson() should return name', () {
      expect(ChatRole.user.toJson(), 'user');
      expect(ChatRole.assistant.toJson(), 'assistant');
    });

    test('fromJson() should return correct ChatRole', () {
      expect(ChatRole.fromJson('user'), ChatRole.user);
      expect(ChatRole.fromJson('assistant'), ChatRole.assistant);
    });

    test('fromJson() should throw ArgumentError for invalid role', () {
      expect(() => ChatRole.fromJson('invalid'), throwsArgumentError);
    });
  });
}
