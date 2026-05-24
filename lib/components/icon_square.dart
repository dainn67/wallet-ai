import 'package:flutter/material.dart';

import 'package:wallet_ai/configs/app_theme.dart';

class IconSquare extends StatelessWidget {
  const IconSquare({
    super.key,
    required this.icon,
    required this.tint,
    this.size = AppSpacing.iconSquare,
  });

  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Icon(icon, color: tint, size: size * 0.5),
    );
  }
}
