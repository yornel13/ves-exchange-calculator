import 'package:flutter/material.dart';
import 'package:ves_exchange_calculator/services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HistoryEntry>> _futureHistory;

  @override
  void initState() {
    super.initState();
    _futureHistory = HistoryService.getHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureHistory = HistoryService.getHistory();
    });
  }

  Future<void> _clearHistory() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Borrar historial'),
          content:
              const Text('Se eliminarán todas las operaciones del historial.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
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

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              size: 18,
              color: colorScheme.onInverseSurface,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Historial eliminado.',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.inverseSurface.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        // Handle superior para indicar que se puede arrastrar
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Historial',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Borrar historial',
                onPressed: _clearHistory,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<HistoryEntry>>(
            future: _futureHistory,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final entries = snapshot.data ?? const <HistoryEntry>[];

              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    'Sin operaciones recientes',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12.0),
                      onTap: () {
                        Navigator.of(context).pop(entry);
                      },
                      child: _buildHistoryItem(context, entry),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8.0),
                  itemCount: entries.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(BuildContext context, HistoryEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dt = DateTime.fromMillisecondsSinceEpoch(entry.timestampMs);
    final String dateStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final String timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF26262A)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila 1: fecha y hora
            Text(
              '$dateStr  $timeStr',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4.0),
            // Fila 2: operación completa y resultado
            Text(
              '${entry.expression} = ${entry.result}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
