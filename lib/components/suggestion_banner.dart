import 'package:flutter/material.dart';

import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/models/suggested_category.dart';

/// A banner widget that surfaces an AI-suggested category to the user.
///
/// Displayed inline beneath an unclassified [RecordWidget] in the chat.
/// All side-effects are delegated to [onConfirm] and [onCancel] callbacks —
/// this widget does NOT access providers directly.
class SuggestionBanner extends StatefulWidget {
  final Record record;
  final String messageId;
  final SuggestedCategory suggestion;
  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;

  const SuggestionBanner({
    super.key,
    required this.record,
    required this.messageId,
    required this.suggestion,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<SuggestionBanner> createState() => _SuggestionBannerState();
}

class _SuggestionBannerState extends State<SuggestionBanner> {
  bool _isProcessing = false;

  Future<void> _handleConfirm() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await widget.onConfirm();
    } catch (_) {
      setState(() => _isProcessing = false);
    }
  }

  void _handleCancel() => widget.onCancel();

  @override
  Widget build(BuildContext context) {
    final isExpense = widget.suggestion.type == 'expense';
    final Color typeColor = isExpense ? Colors.red.shade500 : Colors.green.shade500;
    final Color typeColorDark = isExpense ? Colors.red.shade700 : Colors.green.shade700;
    final Color typeBgColor = isExpense ? Colors.red.shade100 : Colors.green.shade100;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 3, color: typeColor),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI message
                      Text(
                        widget.suggestion.message,
                        softWrap: true,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 8),

                      // Category name chip + type badge
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                widget.suggestion.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: typeBgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.suggestion.type,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: typeColorDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Action buttons (right-aligned)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _handleCancel,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _isProcessing ? null : _handleConfirm,
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Confirm'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
