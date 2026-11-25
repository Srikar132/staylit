import 'package:flutter/material.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// Placeholder screen for managing blocked apps
/// This screen will be fully implemented later with app selection functionality
class ManageBlockedAppsScreen extends StatelessWidget {
  const ManageBlockedAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.palette.onCanvas),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Manage Blocked Apps',
          style: TextStyle(color: context.palette.onCanvas),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.palette.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.apps,
                  size: 64,
                  color: context.palette.accentText,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.palette.onCanvas,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'App blocking feature is under development.\nYou\'ll be able to select and block specific apps here.',
                style: TextStyle(
                  fontSize: 14,
                  color: context.palette.onCanvasSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.palette.accent,
                  foregroundColor: context.palette.onAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
