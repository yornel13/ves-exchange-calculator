import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final String id;
  final String expression;
  final String result;
  final String operationType; // add, sub, mul, div, other
  final int timestampMs;

  HistoryEntry({
    required this.id,
    required this.expression,
    required this.result,
    required this.operationType,
    required this.timestampMs,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      expression: json['expr'] as String,
      result: json['res'] as String,
      operationType: json['op'] as String? ?? 'other',
      timestampMs: json['ts'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'expr': expression,
      'res': result,
      'op': operationType,
      'ts': timestampMs,
    };
  }
}

class HistoryService {
  static const String _kHistoryKey = 'calculator_history_entries';
  static const int _kMaxEntries = 100;

  static Future<List<HistoryEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_kHistoryKey) ?? <String>[];

    final List<HistoryEntry> entries = <HistoryEntry>[];
    for (final item in raw) {
      try {
        final Map<String, dynamic> jsonMap =
            json.decode(item) as Map<String, dynamic>;
        entries.add(HistoryEntry.fromJson(jsonMap));
      } catch (_) {
        // Ignorar entradas corruptas
      }
    }

    // Ordenar descendente por fecha (más reciente primero)
    entries.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    if (entries.length > _kMaxEntries) {
      return entries.sublist(0, _kMaxEntries);
    }
    return entries;
  }

  static Future<void> addEntry({
    required String expression,
    required String result,
    required String operationType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_kHistoryKey) ?? <String>[];

    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = HistoryEntry(
      id: now.toString(),
      expression: expression,
      result: result,
      operationType: operationType,
      timestampMs: now,
    );

    final String encoded = json.encode(entry.toJson());

    // Insertar al inicio para mantener orden reciente primero
    final List<String> updated = <String>[encoded, ...raw];
    if (updated.length > _kMaxEntries) {
      updated.removeRange(_kMaxEntries, updated.length);
    }

    await prefs.setStringList(_kHistoryKey, updated);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistoryKey);
  }
}
