import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    if (showingActions && activePromptIndex != null && activePromptIndex! < prompts.length) {
      final actions = prompts[activePromptIndex!].actions;
      if (actions.isEmpty) return const SizedBox.shrink();

      return SizedBox(
        height: 48,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: List.generate(actions.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  label: Text(actions[i], style: TextStyle(fontSize: 13, color: colorScheme.primary)),
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
                  onPressed: () => onActionTap(i),
                ),
              );
            }),
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: List.generate(prompts.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                label: Text(prompts[i].prompt, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                backgroundColor: const Color(0xFFF1F5F9),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                onPressed: () => onPromptTap(i),
              ),
            );
          }),
        ),
      ),
    );
  }
}
