import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/providers/record_provider.dart';

import 'image_viewer.dart';
import 'popups/edit_record_popup.dart';
import 'record_widget.dart';
import 'suggestion_banner.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  Future<void> _handleConfirm(BuildContext context, Record record, String messageId) async {
    final recordProvider = context.read<RecordProvider>();
    final suggestion = record.suggestedCategory!;

    final newId = await recordProvider.resolveCategoryByNameOrCreate(
      suggestion.name,
      suggestion.type,
      suggestion.parentId,
    );

    if (newId == null) return;

    if (!context.mounted) return;
    final chatProvider = context.read<ChatProvider>();
    final updatedRecord = record.copyWith(categoryId: newId, clearSuggestedCategory: true);
    await recordProvider.updateRecord(updatedRecord);
    chatProvider.updateMessageRecord(messageId, updatedRecord);
  }

  Future<void> _handleEdit(BuildContext context, Record record, String messageId) async {
    final recordProvider = context.read<RecordProvider>();
    final chatProvider = context.read<ChatProvider>();

    final updatedRecord = await showDialog<Record>(
      context: context,
      builder: (context) => EditRecordPopup(
        record: record,
        onDeleted: () => chatProvider.removeMessageRecord(messageId, record.recordId),
      ),
    );

    if (updatedRecord != null && context.mounted) {
      await recordProvider.updateRecord(updatedRecord);
      chatProvider.updateMessageRecord(messageId, updatedRecord);
    }
  }

  void _handleCancel(BuildContext context, Record record, String messageId) {
    final chatProvider = context.read<ChatProvider>();
    final updatedRecord = record.copyWith(clearSuggestedCategory: true);
    chatProvider.updateMessageRecord(messageId, updatedRecord);
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isUser && message.imageBytes != null && message.imageBytes!.isNotEmpty) ...[
                  _buildThumbnailRow(context, message.imageBytes!),
                  if (message.content.trim().isNotEmpty) const SizedBox(height: 8),
                ],
                if (!isUser || message.content.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: isUser ? Theme.of(context).colorScheme.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
                  ),
                  child: message.isAnalyzing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.content.trim(),
                              style: TextStyle(
                                color: isUser ? Colors.white : const Color(0xFF1E293B),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          message.content.trim(),
                          style: TextStyle(
                            color: isUser ? Colors.white : const Color(0xFF1E293B),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                ),
                if (message.records != null && message.records!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...message.records!.asMap().entries.expand((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    final isLast = index == message.records!.length - 1;

                    final List<Widget> groupWidgets = [
                      RecordWidget(
                        record: record,
                        isEditable: true,
                        onEdit: () => _handleEdit(context, record, message.id),
                      ),
                    ];

                    if (record.suggestedCategory != null && record.categoryId == -1) {
                      groupWidgets.add(const SizedBox(height: 8));
                      groupWidgets.add(
                        SuggestionBanner(
                          record: record,
                          messageId: message.id,
                          suggestion: record.suggestedCategory!,
                          onConfirm: () => _handleConfirm(context, record, message.id),
                          onCancel: () => _handleCancel(context, record, message.id),
                        ),
                      );
                    }

                    if (!isLast) {
                      groupWidgets.add(const SizedBox(height: 16));
                    }

                    return groupWidgets;
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailRow(BuildContext context, List<Uint8List> images) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: images.map((bytes) {
        return GestureDetector(
          onTap: () => Navigator.of(context).push(ImageViewer.route(bytes)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, width: 72, height: 72, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        );
      }).toList(),
    );
  }
}
