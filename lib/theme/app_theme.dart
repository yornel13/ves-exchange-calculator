import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';

/// Single source of truth for the app's visual system.
///
/// Replaces the bare `ThemeData.light()` / `ThemeData.dark()` the app used
/// before, which produced the default Material baseline palette.
class AppTheme {
  const AppTheme._();

  /// Seed for the Material color scheme. Steel blue, matching the default
  /// brand background the glass floats over.
  static const Color _seed = Color(0xFF2E4257);

  static ThemeData light() => _build(Brightness.light, GlassTokens.light);

  static ThemeData dark() => _build(Brightness.dark, GlassTokens.dark);

  static ThemeData _build(Brightness brightness, GlassTokens glass) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[glass],
      textTheme: AppTypography.withTabularFigures(base.textTheme),
      scaffoldBackgroundColor: glass.backgroundBottom,
      // The header is drawn by the app itself so the background image reaches
      // the top of the screen.
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: glass.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
