import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';

/// A real frosted-glass panel: it blurs whatever sits behind it.
///
/// PERFORMANCE: [BackdropFilter] is expensive. Use at most one or two per
/// screen — never one per key. The keypad deliberately uses flat translucent
/// fills ([GlassKey]) instead, which cost nothing and read almost identically
/// over a blurred backdrop.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 26.0,
    this.fill,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Overrides [GlassTokens.panelFill]. Large panels use
  /// [GlassTokens.sheetFill] so their content stays legible.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: glass.blurSigma,
          sigmaY: glass.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill ?? glass.panelFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: glass.panelBorder, width: 1),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A floating pill. Flat translucent fill, no blur of its own.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Material(
      color: glass.chipFill,
      shape: StadiumBorder(
        side: BorderSide(color: glass.chipBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Visual role of a keypad key. Drives fill and label color.
enum GlassKeyRole {
  /// Digits and the decimal separator.
  digit,

  /// C, %, DEL — one step quieter than digits.
  control,

  /// + − × ÷ — carry the accent color.
  operator,

  /// The equals key: the only opaque surface on screen.
  equals,
}

/// A single keypad key.
///
/// Flat translucent fill (no per-key blur) plus a press animation and haptic
/// feedback, which is what makes the keypad feel responsive rather than dead.
class GlassKey extends StatefulWidget {
  const GlassKey({
    super.key,
    required this.onPressed,
    required this.role,
    this.label,
    this.icon,
    this.translucent = false,
    this.semanticLabel,
  }) : assert(
          label != null || icon != null,
          'A key needs either a label or an icon',
        );

  final VoidCallback onPressed;
  final GlassKeyRole role;
  final String? label;
  final IconData? icon;

  /// Mirrors the user's "transparent buttons" preference.
  final bool translucent;

  final String? semanticLabel;

  @override
  State<GlassKey> createState() => _GlassKeyState();
}

class _GlassKeyState extends State<GlassKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    final bool isEquals = widget.role == GlassKeyRole.equals;
    final Color fill = isEquals
        ? glass.keyOpaqueFill
        : glass.keyFillFor(
            translucent: widget.translucent,
            muted: widget.role != GlassKeyRole.digit,
          );

    final Color foreground = switch (widget.role) {
      GlassKeyRole.equals => glass.keyOpaqueText,
      GlassKeyRole.operator => glass.accent,
      GlassKeyRole.control => glass.textSecondary,
      GlassKeyRole.digit => glass.textPrimary,
    };

    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: isEquals
                ? BorderSide.none
                : BorderSide(color: glass.keyBorder, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onPressed();
            },
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            child: Center(
              child: widget.icon != null
                  ? Icon(widget.icon, size: 22, color: foreground)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label!,
                        style: (isEquals
                                ? AppTypography.keyEquals
                                : AppTypography.key)
                            .copyWith(color: foreground),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
