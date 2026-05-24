import 'package:flutter/material.dart';

import 'package:wallet_ai/configs/app_theme.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
