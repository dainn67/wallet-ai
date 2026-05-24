import 'package:flutter/material.dart';
import 'package:wallet_ai/configs/app_theme.dart';

/// A reusable confirmation dialog for destructive or important actions.
///
/// Displays a title, content message, and two buttons (Cancel/Confirm).
/// Supports [isDestructive] styling for the confirmation button.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(
        title,
        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      content: Text(
        content,
        style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              // NFR-2: confirmation_dialog_test.dart line 126 finds ElevatedButton and
              // checks button.style?.backgroundColor == Colors.red.shade600 for
              // isDestructive variant — must keep ElevatedButton + Colors.red.shade600.
              child: ElevatedButton(
                key: const Key('confirm_elevated_button'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDestructive
                      ? Colors.red.shade600 // NFR-2: locked by confirmation_dialog_test.dart line 128
                      : AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg - AppSpacing.xs),
                  elevation: AppElevation.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
