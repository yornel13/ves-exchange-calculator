import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';
import 'package:ves_exchange_calculator/widgets/glass_surface.dart';

/// A settings group: a glass panel with a quiet title and an optional action on
/// the right of the header.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 16.0),
      borderRadius: 22.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.headerTitle.copyWith(
                    color: glass.textSecondary,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// A row inside a section: icon, label, and either a trailing widget or a tap
/// action. Replaces the ListTile stack, which brought Material's own padding
/// and ink colors into the glass surface.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;
    final Color foreground = enabled ? glass.textPrimary : glass.textMuted;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 4.0),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 19, color: foreground),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: foreground,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12.5, color: glass.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (trailing == null && onTap != null)
            Icon(Icons.chevron_right_rounded, size: 18, color: glass.textMuted),
        ],
      ),
    );

    if (onTap == null || !enabled) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: content,
      ),
    );
  }
}

/// Explanatory line under a control, for the cases where the labels alone do
/// not say what the choice does.
class SettingsHint extends StatelessWidget {
  const SettingsHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        text,
        style: AppTypography.chip.copyWith(
          color: context.glass.textMuted,
          height: 1.35,
        ),
      ),
    );
  }
}

/// Hairline divider between rows of a section.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Divider(height: 1, thickness: 1, color: context.glass.divider),
    );
  }
}
