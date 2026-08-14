import 'package:flutter/material.dart';

/// Typography for the app.
///
/// Every style that can render a number uses tabular figures. Without them the
/// digits have proportional widths, so the result shifts horizontally on each
/// keystroke — very noticeable in a money app.
class AppTypography {
  const AppTypography._();

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// The result of the operation. Dominates the display by design.
  static const TextStyle result = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w500,
    letterSpacing: -1.5,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// The expression being typed. Quieter than the result, but big enough to
  /// read while typing — at 15px it was unreadable on a real phone.
  static const TextStyle expression = TextStyle(
    fontSize: 27,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    fontFeatures: _tabular,
  );

  /// The expression in secondary contexts (history rows), where it labels a
  /// result instead of being typed.
  static const TextStyle expressionCompact = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    fontFeatures: _tabular,
  );

  /// The converted amount in VES.
  static const TextStyle money = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    fontFeatures: _tabular,
  );

  /// Currency code next to the converted amount.
  static const TextStyle moneyLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  static const TextStyle key = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
  );

  static const TextStyle keyEquals = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle chip = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    fontFeatures: _tabular,
  );

  static const TextStyle headerTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const TextStyle currencyCode = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  /// Applies tabular figures to the Material text theme so that any inherited
  /// numeric text (dialogs, settings, history) stays aligned too.
  static TextTheme withTabularFigures(TextTheme base) {
    TextStyle? tab(TextStyle? style) =>
        style?.copyWith(fontFeatures: _tabular);

    return base.copyWith(
      displayLarge: tab(base.displayLarge),
      displayMedium: tab(base.displayMedium),
      displaySmall: tab(base.displaySmall),
      headlineLarge: tab(base.headlineLarge),
      headlineMedium: tab(base.headlineMedium),
      headlineSmall: tab(base.headlineSmall),
      titleLarge: tab(base.titleLarge),
      titleMedium: tab(base.titleMedium),
      titleSmall: tab(base.titleSmall),
      bodyLarge: tab(base.bodyLarge),
      bodyMedium: tab(base.bodyMedium),
      bodySmall: tab(base.bodySmall),
      labelLarge: tab(base.labelLarge),
      labelMedium: tab(base.labelMedium),
      labelSmall: tab(base.labelSmall),
    );
  }
}
