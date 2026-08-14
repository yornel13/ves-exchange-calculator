import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ves_exchange_calculator/components/settings/settings_section.dart';
import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';

/// When the official rates were last fetched, and when the next automatic
/// refresh is due.
class RatesStatusSection extends StatelessWidget {
  const RatesStatusSection({
    super.key,
    required this.lastUpdate,
    required this.timeToNextRefresh,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final DateTime? lastUpdate;
  final Duration timeToNextRefresh;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  String get _lastUpdateText {
    final DateTime? at = lastUpdate;
    if (at == null) return 'Sin consultas registradas';

    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year}  ${two(at.hour)}:${two(at.minute)}';
  }

  String get _countdownText {
    final int total = timeToNextRefresh.inSeconds;
    if (total <= 0) return 'Actualizando en cualquier momento';

    String two(int value) => value.toString().padLeft(2, '0');
    final String hours = two(total ~/ 3600);
    final String minutes = two((total % 3600) ~/ 60);
    final String seconds = two(total % 60);
    return 'Próxima actualización en $hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return SettingsSection(
      title: 'Tasas oficiales',
      action: _RefreshAction(
        isRefreshing: isRefreshing,
        onRefresh: onRefresh,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.schedule_rounded, size: 17, color: glass.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _lastUpdateText,
                style: TextStyle(
                  fontSize: 14.5,
                  color: glass.textPrimary,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (lastUpdate != null) ...<Widget>[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 27.0),
            child: Text(
              _countdownText,
              style: AppTypography.chip.copyWith(color: glass.textMuted),
            ),
          ),
        ],
      ],
    );
  }
}

class _RefreshAction extends StatelessWidget {
  const _RefreshAction({required this.isRefreshing, required this.onRefresh});

  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Material(
      color: glass.keyFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.0),
        side: BorderSide(color: glass.keyBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isRefreshing
            ? null
            : () {
                HapticFeedback.selectionClick();
                onRefresh();
              },
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: isRefreshing
                // Progress replaces the icon in place: the old screen opened a
                // blocking dialog over the whole page for this.
                ? SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(glass.textSecondary),
                    ),
                  )
                : Icon(Icons.sync_rounded, size: 19, color: glass.textPrimary),
          ),
        ),
      ),
    );
  }
}
