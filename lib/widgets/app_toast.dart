import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';

/// A brief message that appears at the TOP of the screen.
///
/// Material snack bars dock at the bottom, where they sit right on top of the
/// keypad — the one part of a calculator that must never be covered. This is an
/// overlay entry instead, so it never takes space from the layout and never
/// blocks a key.
class AppToast {
  const AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_rounded,
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    dismiss();

    final GlassTokens glass = context.glass;
    final double topInset = MediaQuery.of(context).viewPadding.top;

    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        top: topInset + 10,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: _ToastBubble(
              message: message,
              icon: icon,
              glass: glass,
            ),
          ),
        ),
      ),
    );

    _current = entry;
    overlay.insert(entry);

    _timer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastBubble extends StatefulWidget {
  const _ToastBubble({
    required this.message,
    required this.icon,
    required this.glass,
  });

  final String message;
  final IconData icon;
  final GlassTokens glass;

  @override
  State<_ToastBubble> createState() => _ToastBubbleState();
}

class _ToastBubbleState extends State<_ToastBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 220),
    vsync: this,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.4),
          end: Offset.zero,
        ).animate(curve),
        child: Material(
          color: widget.glass.keyOpaqueFill,
          shape: const StadiumBorder(),
          elevation: 3,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.glass.keyOpaqueText,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.message,
                  style: AppTypography.chip.copyWith(
                    color: widget.glass.keyOpaqueText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
