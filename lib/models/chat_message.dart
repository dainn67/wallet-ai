import 'dart:typed_data';

import 'record.dart';

enum ChatRole {
  user,
  assistant;

  String toJson() => name;

  static ChatRole fromJson(String json) {
    return ChatRole.values.byName(json);
  }
}

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final List<Record>? records;
  final bool isAnalyzing;

  /// Transient: already-compressed JPEG bytes for outgoing user messages with
  /// attached images. Rendered in the bubble via `Image.memory`. Deliberately
  /// excluded from `toJson`/`fromJson` — mirrors the `Record.suggestedCategory`
  /// pattern (AD-4 in the image-input epic). The chat history is ephemeral in
  /// practice and images are preview-only, so persistence isn't needed.
  final List<Uint8List>? imageBytes;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.records,
    this.isAnalyzing = false,
    this.imageBytes,
  });

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    List<Record>? records,
    bool? isAnalyzing,
    List<Uint8List>? imageBytes,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      records: records ?? this.records,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  Map<String, dynamic> toJson() {
    // Note: `imageBytes` is transient and intentionally excluded from JSON.
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'records': records?.map((r) => r.toMap()).toList(),
      'is_analyzing': isAnalyzing,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: ChatRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      records: (json['records'] as List?)
          ?.map((r) => Record.fromMap(r as Map<String, dynamic>))
          .toList(),
      isAnalyzing: json['is_analyzing'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatMessage &&
        other.id == id &&
        other.role == role &&
        other.content == content &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^ role.hashCode ^ content.hashCode ^ timestamp.hashCode;
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, role: $role, content: $content, timestamp: $timestamp)';
  }
}
