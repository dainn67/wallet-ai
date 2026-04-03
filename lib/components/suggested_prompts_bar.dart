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
        height: 52,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: List.generate(actions.length, (i) {
              return _PromptChip(
                label: actions[i],
                onTap: () => onActionTap(i),
                isAction: true,
                colorScheme: colorScheme,
              );
            }),
          ),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: List.generate(prompts.length, (i) {
            return _PromptChip(
              label: prompts[i].prompt,
              onTap: () => onPromptTap(i),
              isAction: false,
              colorScheme: colorScheme,
            );
          }),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAction;
  final ColorScheme colorScheme;

  const _PromptChip({
    required this.label,
    required this.onTap,
    required this.isAction,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, bottom: 4.0), // Add bottom padding for shadow
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isAction ? FontWeight.w600 : FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
