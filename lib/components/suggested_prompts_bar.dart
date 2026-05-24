import 'package:flutter/material.dart';

import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/models/suggested_prompt.dart';

class SuggestedPromptsBar extends StatelessWidget {
  final List<SuggestedPrompt> prompts;
  final int? activePromptIndex;
  final bool showingActions;
  final ValueChanged<int> onPromptTap;
  final ValueChanged<int> onActionTap;

  const SuggestedPromptsBar({
    super.key,
    required this.prompts,
    required this.activePromptIndex,
    required this.showingActions,
    required this.onPromptTap,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (showingActions && activePromptIndex != null && activePromptIndex! < prompts.length) {
      final actions = prompts[activePromptIndex!].actions;
      if (actions.isEmpty) return const SizedBox.shrink();

      return _buildChipsRow(
        labels: actions,
        onTap: onActionTap,
        isAction: true,
      );
    }

    return _buildChipsRow(
      labels: prompts.map((p) => p.prompt).toList(),
      onTap: onPromptTap,
      isAction: false,
    );
  }

  Widget _buildChipsRow({
    required List<String> labels,
    required ValueChanged<int> onTap,
    required bool isAction,
  }) {
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ActionChip(
                label: Text(labels[i]),
                onPressed: () => onTap(i),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.outline),
                labelStyle: TextStyle(
                  fontWeight: isAction ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.onSurface,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
