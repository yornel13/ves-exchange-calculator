import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/theme/glass_tokens.dart';

/// Bottom layer of the screen: the user's background image (or the brand
/// background when none is set), plus the scrim that guarantees contrast for
/// everything floating above it.
///
/// The scrim is not optional. White text over an arbitrary photo fails
/// contrast, so the glass system depends on this wash always being present.
class BackgroundLayer extends StatelessWidget {
  const BackgroundLayer({
    super.key,
    required this.imagePath,
    required this.child,
  });

  /// Absolute path to the user-selected image, or null for the brand default.
  final String? imagePath;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;
    final String? path = imagePath;
    final bool hasImage = path != null && path.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[glass.backgroundTop, glass.backgroundBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (hasImage)
            Image.file(
              File(path),
              fit: BoxFit.cover,
              // A missing or deleted file falls back to the brand gradient
              // instead of crashing the screen.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          // The scrim exists to tame an unknown photo. The brand gradient is
          // already contrast-checked, so washing it out only makes the glass
          // look like flat gray.
          if (hasImage) ColoredBox(color: glass.scrim),
          child,
        ],
      ),
    );
  }
}
