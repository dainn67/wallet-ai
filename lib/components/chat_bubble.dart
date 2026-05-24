import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/providers/record_provider.dart';

import 'icon_square.dart';
import 'image_viewer.dart';
import 'popups/edit_record_popup.dart';
import 'popups/transfer_info_popup.dart';
import 'record_widget.dart';
import 'section_label.dart';
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

    if (record.isTransfer) {
      await showDialog(
        context: context,
        builder: (_) => TransferInfoPopup(
          record: record,
          onDeleted: () => chatProvider.removeMessageRecord(messageId, record.recordId),
        ),
      );
      return;
    }

    final updatedRecord = await showDialog<Record>(
      context: context,
      builder: (_) => EditRecordPopup(
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
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const IconSquare(
              icon: Icons.auto_awesome,
              tint: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isUser && message.imageBytes != null && message.imageBytes!.isNotEmpty) ...[
                  _buildThumbnailRow(context, message.imageBytes!),
                  if (message.content.trim().isNotEmpty) const SizedBox(height: AppSpacing.sm),
                ],
                if (!isUser || message.content.trim().isNotEmpty)
                  _buildBubble(context, isUser),
                if (message.records != null && message.records!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  ..._buildRecordSections(context, message.records!),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: AppSpacing.sm),
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.neutral,
              child: Icon(Icons.person, size: 16, color: AppColors.onPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context, bool isUser) {
    final textTheme = Theme.of(context).textTheme;
    final Color bubbleColor = isUser ? AppColors.primaryContainer : AppColors.surface;
    final Color textColor = isUser ? AppColors.onSurface : AppColors.onSurface;

    final Widget content = message.isAnalyzing
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  message.content.trim(),
                  style: textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.onSurfaceVariant),
                ),
              ),
            ],
          )
        : Text(
            message.content.trim(),
            style: textTheme.bodyMedium?.copyWith(color: textColor),
          );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.card),
          topRight: const Radius.circular(AppRadius.card),
          bottomLeft: Radius.circular(isUser ? AppRadius.card : AppRadius.tile),
          bottomRight: Radius.circular(isUser ? AppRadius.tile : AppRadius.card),
        ),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: content,
    );
  }

  List<Widget> _buildRecordSections(BuildContext context, List<Record> records) {
    final widgets = <Widget>[];
    final hasExpense = records.any((r) => r.type == 'expense');

    if (hasExpense) {
      widgets.add(const SectionLabel('EXPENSE DETECTED'));
      widgets.add(const SizedBox(height: AppSpacing.xs));
    }

    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      final isLast = i == records.length - 1;

      widgets.add(
        RecordWidget(
          record: record,
          isEditable: true,
          onEdit: () => _handleEdit(context, record, message.id),
        ),
      );

      if (record.suggestedCategory != null && record.categoryId == -1) {
        widgets.add(const SizedBox(height: AppSpacing.sm));
        widgets.add(
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
        widgets.add(const SizedBox(height: AppSpacing.lg));
      }
    }

    return widgets;
  }

  Widget _buildThumbnailRow(BuildContext context, List<Uint8List> images) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.end,
      children: images.map((bytes) {
        return GestureDetector(
          onTap: () => Navigator.of(context).push(ImageViewer.route(bytes)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: Image.memory(bytes, width: 72, height: 72, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        );
      }).toList(),
    );
  }
}
