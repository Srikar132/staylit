// File: lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/app_palette.dart';
import 'package:staylit/core/theme/app_typography.dart';

/// Warm Focus themes.
///
/// [light] and [dark] are produced by one builder from an [AppPalette], so
/// component themes cannot drift between modes. The active mode is chosen by
/// `themeModeProvider` (System by default) and applied in `MaterialApp`.
abstract final class AppTheme {
  static final ThemeData light = _build(AppPalette.light, Brightness.light);
  static final ThemeData dark = _build(AppPalette.dark, Brightness.dark);

  /// System bar style for [brightness]: transparent status bar, icon
  /// brightness inverted against the background.
  ///
  /// [navigationBarColor] defaults to the palette canvas; pass
  /// [Colors.transparent] for windows that draw behind the navigation bar
  /// (the block overlay).
  static SystemUiOverlayStyle overlayStyle({
    required AppPalette palette,
    required Brightness brightness,
    Color? navigationBarColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final iconBrightness = isDark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: navigationBarColor ?? palette.canvas,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final textTheme = AppTypography.textTheme(p);
    final stadium = const StadiumBorder();

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: p.ink,
      secondary: p.accentStrong,
      onSecondary: p.onAccent,
      tertiary: p.chartAlt,
      onTertiary: p.onInk,
      error: p.error,
      onError: p.onError,
      surface: p.canvas,
      onSurface: p.onCanvas,
      onSurfaceVariant: p.onCanvasSecondary,
      surfaceContainerLowest: p.canvas,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      // Card-like containers must stay visible on the canvas, which in light
      // mode is the same white as surfaceRaised, so they use `surface`.
      surfaceContainerHigh: p.surface,
      surfaceContainerHighest: p.surface,
      outline: p.onCanvasMuted,
      outlineVariant: p.divider,
      inverseSurface: p.ink,
      onInverseSurface: p.onInk,
      inversePrimary: p.accentSoft,
      scrim: p.scrim,
      shadow: Colors.black,
      surfaceTint: Colors.transparent,
    );

    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      splashColor: p.accent.withValues(alpha: 0.10),
      highlightColor: p.accent.withValues(alpha: 0.05),
      iconTheme: IconThemeData(color: p.onCanvas, size: 24),
      extensions: <ThemeExtension<dynamic>>[p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        foregroundColor: p.onCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: p.onCanvas, size: 24),
        actionsIconTheme: IconThemeData(color: p.onCanvas, size: 24),
        systemOverlayStyle: overlayStyle(palette: p, brightness: brightness),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: inputBorder(Colors.transparent, 0),
        enabledBorder: inputBorder(Colors.transparent, 0),
        focusedBorder: inputBorder(p.accent, 2),
        errorBorder: inputBorder(p.error, 1.5),
        focusedErrorBorder: inputBorder(p.error, 2),
        labelStyle: textTheme.bodyMedium?.copyWith(color: p.onCanvasMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: p.onCanvasMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.surfaceTrack,
          disabledForegroundColor: p.onCanvasDisabled,
          shape: stadium,
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.lg,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.surfaceTrack,
          disabledForegroundColor: p.onCanvasDisabled,
          shape: stadium,
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.lg,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.onCanvas,
          disabledForegroundColor: p.onCanvasDisabled,
          shape: stadium,
          side: BorderSide(color: p.border, width: 1.5),
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.lg,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          disabledForegroundColor: p.onCanvasDisabled,
          shape: stadium,
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceRaised,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceRaised,
        modalBackgroundColor: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
        dragHandleColor: p.onCanvasDisabled,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accent,
        disabledColor: p.surfaceTrack,
        checkmarkColor: p.onAccent,
        labelStyle: textTheme.labelMedium?.copyWith(color: p.onCanvas),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: p.onAccent),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: stadium,
        side: BorderSide.none,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.accent : p.surfaceTrack,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.surfaceTrack,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.20),
        valueIndicatorColor: p.ink,
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
          color: p.onInk,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceTrack,
        circularTrackColor: p.surfaceTrack,
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 62,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? p.accent : p.onInk.withValues(alpha: 0.6),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.accent : p.onInk.withValues(alpha: 0.6),
            size: 26,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.onInk),
        actionTextColor: p.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: p.surface,
        textColor: p.onCanvas,
        iconColor: p.accentText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: p.badge,
        textColor: Colors.white,
        textStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: textTheme.bodyLarge?.copyWith(color: p.onCanvas),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.30),
        selectionHandleColor: p.accent,
      ),
    );
  }
}
