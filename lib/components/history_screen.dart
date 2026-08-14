import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/services/history_service.dart';
import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';
import 'package:ves_exchange_calculator/utils/number_formatter.dart';
import 'package:ves_exchange_calculator/widgets/app_toast.dart';
import 'package:ves_exchange_calculator/widgets/glass_surface.dart';

/// Past operations, shown in a bottom sheet. Tapping one puts it back on the
/// display.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HistoryEntry>> _futureHistory =
      HistoryService.getHistory();

  Future<void> _refresh() async {
    setState(() {
      _futureHistory = HistoryService.getHistory();
    });
  }

  Future<void> _clearHistory() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Borrar el historial'),
          content: const Text(
            'Se eliminarán todas las operaciones guardadas.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Borrar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await HistoryService.clearHistory();
    await _refresh();

    if (!mounted) return;
    AppToast.show(context, 'Historial eliminado', icon: Icons.delete_outline);
  }

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: 10),
        // Handle: indica que el panel se puede arrastrar.
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: glass.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 8.0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Historial',
                  style: AppTypography.headerTitle.copyWith(
                    color: glass.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Borrar el historial',
                onPressed: _clearHistory,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: glass.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: FutureBuilder<List<HistoryEntry>>(
            future: _futureHistory,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<HistoryEntry>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(glass.textSecondary),
                    ),
                  ),
                );
              }

              final List<HistoryEntry> entries =
                  snapshot.data ?? const <HistoryEntry>[];

              if (entries.isEmpty) {
                return _EmptyState(glass: glass);
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 20.0),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8.0),
                  itemBuilder: (BuildContext context, int index) {
                    return _HistoryTile(
                      entry: entries[index],
                      onTap: () => Navigator.of(context).pop(entries[index]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  static const Map<String, IconData> _operationIcons = <String, IconData>{
    'add': Icons.add_rounded,
    'sub': Icons.remove_rounded,
    'mul': Icons.close_rounded,
    'div': Icons.percent_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;
    final DateTime at = DateTime.fromMillisecondsSinceEpoch(entry.timestampMs);

    String two(int value) => value.toString().padLeft(2, '0');
    final String when =
        '${two(at.day)}/${two(at.month)}/${at.year}  ${two(at.hour)}:${two(at.minute)}';

    return Material(
      color: glass.keyFillMuted,
      borderRadius: BorderRadius.circular(18.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: glass.keyFill,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _operationIcons[entry.operationType] ??
                        Icons.drag_handle_rounded,
                    size: 15,
                    color: glass.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      NumberFormatter.expression(entry.expression),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.expressionCompact.copyWith(
                        color: glass.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormatter.amount(entry.result),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.money.copyWith(
                        fontSize: 19,
                        color: glass.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                when,
                style: AppTypography.chip.copyWith(
                  fontSize: 11.5,
                  color: glass.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.glass});

  final GlassTokens glass;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.history_rounded, size: 30, color: glass.textMuted),
            const SizedBox(height: 12),
            Text(
              'Todavía no hay operaciones',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: glass.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Lo que calcules aparecerá acá para volver a usarlo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: glass.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frame for the history sheet: a glass panel anchored to the bottom.
class HistorySheet extends StatelessWidget {
  const HistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.8;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: height,
        child: GlassPanel(
          padding: EdgeInsets.zero,
          borderRadius: 28.0,
          fill: context.glass.sheetFill,
          child: const HistoryScreen(),
        ),
      ),
    );
  }
}
