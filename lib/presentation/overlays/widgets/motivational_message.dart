import 'package:flutter/material.dart';
import 'package:pace/core/theme/theme_context.dart';

class MotivationalMessage extends StatelessWidget {
  final String message;

  const MotivationalMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.onCanvas.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.palette.onCanvas.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: context.palette.warning,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: context.palette.onCanvas.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
