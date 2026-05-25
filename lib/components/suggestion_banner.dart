import 'package:flutter/material.dart';

import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/models/suggested_category.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20, color: Color(0xFFE2E8F0)),
        Text(
          widget.suggestion.message,
          style: const TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Color(0xFF475569),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PillButton(
              label: 'Confirm',
              primary: true,
              onPressed: _isProcessing ? null : _handleConfirm,
              isLoading: _isProcessing,
            ),
            const SizedBox(width: 8),
            _PillButton(
              label: 'Dismiss',
              onPressed: widget.onCancel,
            ),
          ],
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _PillButton({
    required this.label,
    this.primary = false,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = primary ? const Color(0xFF8B5CF6).withValues(alpha: 0.1) : const Color(0xFFF1F5F9);
    final textColor = primary ? const Color(0xFF8B5CF6) : const Color(0xFF374151);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
        ),
      ),
    );
  }
}
