import 'package:flutter/material.dart';

import 'package:wallet_ai/components/section_label.dart';
import 'package:wallet_ai/configs/app_theme.dart';

/// A component that displays a date label to divide records in a list.
class DateDivider extends StatelessWidget {
  /// The text to display as the divider label (e.g., "6 April 2026").
  final String label;

  const DateDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.xs,
      ),
      child: Row(
        children: [
          SectionLabel(label),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Divider(
              color: AppColors.outline,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}
