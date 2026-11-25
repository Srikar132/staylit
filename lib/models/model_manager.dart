import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';

class BottomSheetManager {
  /// Show a custom bottom sheet with any content.
  ///
  /// Background, surface tint and elevation come from the theme's
  /// `bottomSheetTheme`; pass [backgroundColor] only for a deliberate override.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    double? height,
    Color? backgroundColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) =>
          height != null ? SizedBox(height: height, child: child) : child,
    );
  }
}
