import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';
import 'package:ves_exchange_calculator/widgets/glass_surface.dart';

/// Top bar of the screen. Drawn by the app instead of an [AppBar] so the
/// background image reaches the top edge without a colored band over it.
class CalculatorHeader extends StatelessWidget {
  const CalculatorHeader({
    super.key,
    required this.title,
    required this.onOpenHistory,
    required this.onShare,
    required this.onOpenModeDialog,
    required this.onOpenSettings,
    required this.onShareApp,
  });

  final String title;
  final VoidCallback onOpenHistory;
  final VoidCallback onShare;
  final VoidCallback onOpenModeDialog;
  final VoidCallback onOpenSettings;

  /// Shares the store link, not the screen — [onShare] is the screenshot.
  final VoidCallback onShareApp;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: AppTypography.headerTitle.copyWith(
              color: glass.textSecondary,
            ),
          ),
        ),
        _HeaderAction(
          icon: Icons.history_rounded,
          tooltip: 'Historial',
          onPressed: onOpenHistory,
        ),
        _HeaderAction(
          icon: Icons.ios_share_rounded,
          tooltip: 'Compartir',
          onPressed: onShare,
        ),
        PopupMenuButton<int>(
          icon: Icon(Icons.more_vert_rounded, size: 20, color: glass.textPrimary),
          tooltip: 'Más opciones',
          padding: EdgeInsets.zero,
          offset: const Offset(0, 40),
          onSelected: (int value) {
            if (value == 0) {
              onOpenModeDialog();
            } else if (value == 1) {
              onOpenSettings();
            } else if (value == 2) {
              onShareApp();
            }
          },
          itemBuilder: (BuildContext context) => const <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: Row(
                children: <Widget>[
                  Icon(Icons.calculate_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Tipo de calculadora'),
                ],
              ),
            ),
            PopupMenuItem<int>(
              value: 2,
              child: Row(
                children: <Widget>[
                  Icon(Icons.link_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Compartir la app'),
                ],
              ),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: Row(
                children: <Widget>[
                  Icon(Icons.settings_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Ajustes'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20, color: context.glass.textPrimary),
    );
  }
}

/// Shortcut out of plain calculator mode. Switching modes used to require the
/// overflow menu plus a dialog.
class ModeChip extends StatelessWidget {
  const ModeChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return GlassChip(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.currency_exchange_rounded,
            size: 14,
            color: glass.textSecondary,
          ),
          const SizedBox(width: 7),
          Text(
            'Convertir a Bs',
            style: AppTypography.chip.copyWith(color: glass.textSecondary),
          ),
        ],
      ),
    );
  }
}
