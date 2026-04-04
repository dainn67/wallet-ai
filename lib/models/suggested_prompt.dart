class SuggestedPrompt {
  final String prompt;
  final List<String> actions;

  SuggestedPrompt({
    required this.prompt,
    required this.actions,
  });

  factory SuggestedPrompt.fromJson(Map<String, dynamic> json) {
    return SuggestedPrompt(
      prompt: json['prompt'] as String,
      actions: List<String>.from(json['actions'] ?? []),
    );
  }

  @override
  String toString() {
    return 'SuggestedPrompt(prompt: $prompt, actions: $actions)';
  }
}
