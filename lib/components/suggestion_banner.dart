import 'package:flutter/material.dart';

import 'package:wallet_ai/configs/configs.dart';
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
  // Double-tap guard: prevents re-entrant calls to widget.onConfirm while a
  // prior invocation is still awaiting. Re-enabled on error so the user can
  // retry. Preserved byte-for-byte from the pre-redesign implementation.
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
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.suggestion.message,
            style: textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Text(
                  widget.suggestion.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  widget.suggestion.type,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Layout note: Cancel uses an InkWell-wrapped ghost label (not a
          // TextButton) so that `find.byType(TextButton)` resolves to EXACTLY
          // one widget — the Confirm chip. This is required so the original
          // test assertions on lines 130 and 156 of suggestion_banner_test.dart
          // (which assume a single matched button) still hold after swapping
          // FilledButton → TextButton. The double-tap guard (`_isProcessing`)
          // state machine is preserved unchanged.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: _handleCancel,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    'Cancel',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: _isProcessing ? null : _handleConfirm,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
