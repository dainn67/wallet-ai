import 'package:flutter/material.dart';

/// A component that displays a month/year label to divide records in a list.
class MonthDivider extends StatelessWidget {
  /// The text to display as the divider label (e.g., "March 2026").
  final String label;

  const MonthDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Divider(
              color: Color(0xFFE2E8F0),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}
