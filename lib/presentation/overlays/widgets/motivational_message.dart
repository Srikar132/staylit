import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// A short encouraging line on a soft card.
class MotivationalMessage extends StatelessWidget {
  final String message;

  const MotivationalMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.4),
        textAlign: TextAlign.center,
      ),
    );
  }
}
