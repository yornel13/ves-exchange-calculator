import 'package:flutter/material.dart';

/// Design tokens for the translucent ("glass") surface system.
///
/// Every surface in the app floats over the user's background image. To keep
/// text legible over an arbitrary photo, a scrim always sits between the
/// background and the glass — see [scrim]. That guarantee is what lets the
/// token set commit to a single text color per brightness.
///
/// Dark variant: white wash over a darkened background.
/// Light variant: frosted white panel with dark text.
@immutable
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.panelFill,
    required this.panelBorder,
    required this.sheetFill,
    required this.chipFill,
    required this.chipBorder,
    required this.keyFill,
    required this.keyFillTranslucent,
    required this.keyFillMuted,
    required this.keyFillMutedTranslucent,
    required this.keyBorder,
    required this.keyOpaqueFill,
    required this.keyOpaqueText,
    required this.accent,
    required this.positive,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.scrim,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.blurSigma,
  });

  /// Fill of the main display panel. The only surface that gets a real blur.
  final Color panelFill;
  final Color panelBorder;

  /// Fill for panels that cover most of the screen (the history sheet). More
  /// opaque than [panelFill]: over that much area, a 13% wash lets the blurred
  /// keypad bleed through and the content stops being legible.
  final Color sheetFill;

  /// Fill of the floating pills in the header (rate chip, mode chip).
  final Color chipFill;
  final Color chipBorder;

  /// Digit keys. `Translucent` variants are used when the user enables the
  /// "transparent buttons" preference.
  final Color keyFill;
  final Color keyFillTranslucent;

  /// Control and operator keys — one step quieter than digit keys.
  final Color keyFillMuted;
  final Color keyFillMutedTranslucent;
  final Color keyBorder;

  /// The equals key: the single opaque element on screen, so it reads as the
  /// visual anchor of the keypad.
  final Color keyOpaqueFill;
  final Color keyOpaqueText;

  /// Single accent of the system. Used for operators and for money in VES —
  /// never for decoration.
  final Color accent;

  /// Status colors, reserved for the live rate indicator.
  final Color positive;
  final Color warning;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;

  /// Wash applied over the background image. Non-negotiable: without it,
  /// white-on-photo text fails contrast.
  final Color scrim;

  /// Brand background, used when the user has not picked an image.
  final Color backgroundTop;
  final Color backgroundBottom;

  final double blurSigma;

  /// Resolves the digit-key fill for the current transparency preference.
  Color keyFillFor({required bool translucent, required bool muted}) {
    if (muted) {
      return translucent ? keyFillMutedTranslucent : keyFillMuted;
    }
    return translucent ? keyFillTranslucent : keyFill;
  }

  static const GlassTokens dark = GlassTokens(
    panelFill: Color(0x21FFFFFF),
    panelBorder: Color(0x33FFFFFF),
    sheetFill: Color(0xD91C232C),
    chipFill: Color(0x24FFFFFF),
    chipBorder: Color(0x38FFFFFF),
    keyFill: Color(0x29FFFFFF),
    keyFillTranslucent: Color(0x17FFFFFF),
    keyFillMuted: Color(0x1AFFFFFF),
    keyFillMutedTranslucent: Color(0x0FFFFFFF),
    keyBorder: Color(0x2BFFFFFF),
    keyOpaqueFill: Color(0xFFF4F1EC),
    keyOpaqueText: Color(0xFF22303F),
    accent: Color(0xFFFAC775),
    positive: Color(0xFF5DCAA5),
    warning: Color(0xFFEF9F27),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB8FFFFFF),
    textMuted: Color(0x8AFFFFFF),
    divider: Color(0x2EFFFFFF),
    scrim: Color(0x73000000),
    backgroundTop: Color(0xFF2E4257),
    backgroundBottom: Color(0xFF141B24),
    blurSigma: 24.0,
  );

  static const GlassTokens light = GlassTokens(
    panelFill: Color(0xCCFFFFFF),
    panelBorder: Color(0xE6FFFFFF),
    sheetFill: Color(0xF2FFFFFF),
    chipFill: Color(0xC2FFFFFF),
    chipBorder: Color(0xE0FFFFFF),
    keyFill: Color(0xD9FFFFFF),
    keyFillTranslucent: Color(0x9AFFFFFF),
    keyFillMuted: Color(0x8FFFFFFF),
    keyFillMutedTranslucent: Color(0x66FFFFFF),
    keyBorder: Color(0x40FFFFFF),
    keyOpaqueFill: Color(0xFF22303F),
    keyOpaqueText: Color(0xFFF4F1EC),
    accent: Color(0xFF8A5108),
    positive: Color(0xFF0F6E56),
    warning: Color(0xFF854F0B),
    textPrimary: Color(0xFF1B2430),
    textSecondary: Color(0xB31B2430),
    textMuted: Color(0x801B2430),
    divider: Color(0x2E1B2430),
    scrim: Color(0x40FFFFFF),
    backgroundTop: Color(0xFFB9C6D4),
    backgroundBottom: Color(0xFF8095AB),
    blurSigma: 24.0,
  );

  @override
  GlassTokens copyWith({
    Color? panelFill,
    Color? panelBorder,
    Color? sheetFill,
    Color? chipFill,
    Color? chipBorder,
    Color? keyFill,
    Color? keyFillTranslucent,
    Color? keyFillMuted,
    Color? keyFillMutedTranslucent,
    Color? keyBorder,
    Color? keyOpaqueFill,
    Color? keyOpaqueText,
    Color? accent,
    Color? positive,
    Color? warning,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? scrim,
    Color? backgroundTop,
    Color? backgroundBottom,
    double? blurSigma,
  }) {
    return GlassTokens(
      panelFill: panelFill ?? this.panelFill,
      panelBorder: panelBorder ?? this.panelBorder,
      sheetFill: sheetFill ?? this.sheetFill,
      chipFill: chipFill ?? this.chipFill,
      chipBorder: chipBorder ?? this.chipBorder,
      keyFill: keyFill ?? this.keyFill,
      keyFillTranslucent: keyFillTranslucent ?? this.keyFillTranslucent,
      keyFillMuted: keyFillMuted ?? this.keyFillMuted,
      keyFillMutedTranslucent:
          keyFillMutedTranslucent ?? this.keyFillMutedTranslucent,
      keyBorder: keyBorder ?? this.keyBorder,
      keyOpaqueFill: keyOpaqueFill ?? this.keyOpaqueFill,
      keyOpaqueText: keyOpaqueText ?? this.keyOpaqueText,
      accent: accent ?? this.accent,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      scrim: scrim ?? this.scrim,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      blurSigma: blurSigma ?? this.blurSigma,
    );
  }

  @override
  GlassTokens lerp(ThemeExtension<GlassTokens>? other, double t) {
    if (other is! GlassTokens) return this;
    return GlassTokens(
      panelFill: Color.lerp(panelFill, other.panelFill, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      sheetFill: Color.lerp(sheetFill, other.sheetFill, t)!,
      chipFill: Color.lerp(chipFill, other.chipFill, t)!,
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t)!,
      keyFill: Color.lerp(keyFill, other.keyFill, t)!,
      keyFillTranslucent:
          Color.lerp(keyFillTranslucent, other.keyFillTranslucent, t)!,
      keyFillMuted: Color.lerp(keyFillMuted, other.keyFillMuted, t)!,
      keyFillMutedTranslucent: Color.lerp(
        keyFillMutedTranslucent,
        other.keyFillMutedTranslucent,
        t,
      )!,
      keyBorder: Color.lerp(keyBorder, other.keyBorder, t)!,
      keyOpaqueFill: Color.lerp(keyOpaqueFill, other.keyOpaqueFill, t)!,
      keyOpaqueText: Color.lerp(keyOpaqueText, other.keyOpaqueText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(backgroundBottom, other.backgroundBottom, t)!,
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
    );
  }
}

/// Shorthand for reading the glass tokens off the current theme.
extension GlassTokensContext on BuildContext {
  GlassTokens get glass =>
      Theme.of(this).extension<GlassTokens>() ?? GlassTokens.dark;
}
