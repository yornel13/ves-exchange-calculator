import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/components/calculator/currency_glyph.dart';
import 'package:ves_exchange_calculator/models/currency_option.dart';
import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';
import 'package:ves_exchange_calculator/utils/number_formatter.dart';
import 'package:ves_exchange_calculator/widgets/glass_surface.dart';

/// What the status chip is currently saying.
enum RateStatus {
  /// Showing how long ago the rates were fetched.
  idle,

  /// A fetch is in flight.
  updating,

  /// A fetch just succeeded — shown briefly, then back to [idle].
  updated,
}

/// How much of a rate chip is spelled out.
enum RatesStripStyle {
  /// Symbol, currency code and value: `$ USD 235,60`. The default — it is the
  /// only variant that survives being read out of the corner of the eye. The
  /// four chips do not fit a phone width, so the strip scrolls.
  labeled,

  /// Symbol and value only: `$ 235,60`. Everything fits without scrolling, at
  /// the cost of the user having to know the symbols.
  compact;

  /// Shared preferences key. Lives here so the calculator and the settings
  /// screen cannot drift apart on where the choice is stored.
  static const String prefsKey = 'ratesStripStyle';

  static const String _labeledKey = 'labeled';
  static const String _compactKey = 'compact';

  /// Value stored in shared preferences. Not [name]: the stored string must
  /// survive a rename of the enum entries.
  String get storageKey =>
      this == RatesStripStyle.compact ? _compactKey : _labeledKey;

  /// Anything unrecognised (including a missing preference) falls back to
  /// [labeled].
  static RatesStripStyle fromStorage(String? key) =>
      key == _compactKey ? RatesStripStyle.compact : RatesStripStyle.labeled;
}

/// The rate chips in the header: one per currency, plus a status chip.
///
/// Splitting the old single chip in two separates the data from its freshness —
/// the user reads three rates at a glance instead of only the one belonging to
/// the active pair, and the refresh action keeps a chip of its own.
///
/// The strip scrolls horizontally: in [RatesStripStyle.labeled] the four chips
/// are wider than a phone.
///
/// It is laid out edge to edge, and keeps the screen margin as its own
/// [horizontalPadding] instead. That padding scrolls with the content, so the
/// chips line up with the rest of the screen at rest but run all the way to the
/// edge of the display once dragged — a chip clipped against an invisible
/// margin reads as a rendering bug.
class RatesStrip extends StatelessWidget {
  const RatesStrip({
    super.key,
    required this.currencies,
    required this.updatedAt,
    required this.status,
    required this.style,
    required this.onRefresh,
    this.onSelect,
    this.horizontalPadding = 16.0,
  });

  /// Rates to show, in display order. VES is not one of them: it is the base
  /// and is always 1.
  final List<CurrencyOption> currencies;

  final DateTime? updatedAt;
  final RateStatus status;
  final RatesStripStyle style;

  /// Fired by the status chip — the only chip that pushes an update.
  final VoidCallback onRefresh;

  /// Makes a currency the left side of the active pair. Null leaves the value
  /// chips inert.
  final ValueChanged<String>? onSelect;

  /// Screen margin, applied inside the scroll view. Match it to the horizontal
  /// padding of whatever lays the strip out.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    // Dimmed while a fetch is in flight: the numbers on screen are the old
    // ones, and saying so is cheaper than a spinner per chip.
    final bool isStale = status == RateStatus.updating;

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: currencies.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          if (index == currencies.length) {
            return RatesStatusChip(
              updatedAt: updatedAt,
              status: status,
              onRefresh: onRefresh,
            );
          }

          final CurrencyOption currency = currencies[index];
          return RateValueChip(
            currency: currency,
            style: style,
            isStale: isStale,
            onTap: onSelect == null ? null : () => onSelect!(currency.code),
          );
        },
      ),
    );
  }
}

/// A single rate: symbol, optionally the code, and the value.
class RateValueChip extends StatelessWidget {
  const RateValueChip({
    super.key,
    required this.currency,
    required this.style,
    required this.isStale,
    this.onTap,
  });

  final CurrencyOption currency;
  final RatesStripStyle style;
  final bool isStale;
  final VoidCallback? onTap;

  /// `Euro` is the internal code; `EUR` is what fits and what people read.
  String get _shortCode => currency.code == 'Euro' ? 'EUR' : currency.code;

  String get _value =>
      NumberFormatter.amount(currency.value.toStringAsFixed(2));

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;
    final Color symbolColor = isStale ? glass.textMuted : glass.accent;
    final Color valueColor = isStale ? glass.textMuted : glass.textPrimary;

    return GlassChip(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CurrencyGlyph(
            code: currency.code,
            icon: currency.icon,
            color: symbolColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          if (style == RatesStripStyle.labeled) ...<Widget>[
            Text(
              _shortCode,
              style: AppTypography.chip.copyWith(
                color: isStale ? glass.textMuted : glass.textSecondary,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(_value, style: AppTypography.chip.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

/// How fresh the rates are, and the manual refresh.
///
/// Stateful because the label is relative ("hace 5 min") and would otherwise
/// freeze at whatever it said when the screen was built.
class RatesStatusChip extends StatefulWidget {
  const RatesStatusChip({
    super.key,
    required this.updatedAt,
    required this.status,
    required this.onRefresh,
  });

  final DateTime? updatedAt;
  final RateStatus status;
  final VoidCallback onRefresh;

  @override
  State<RatesStatusChip> createState() => _RatesStatusChipState();
}

class _RatesStatusChipState extends State<RatesStatusChip> {
  /// Half a minute: the label's finest step is one minute, so this is the
  /// coarsest tick that never shows a stale number for long.
  static const Duration _tick = Duration(seconds: 30);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsedText {
    final DateTime? at = widget.updatedAt;
    if (at == null) return 'sin datos';

    final Duration elapsed = DateTime.now().difference(at);
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'ahora';
    if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';
    if (elapsed.inDays == 1) return 'ayer';
    return 'hace ${elapsed.inDays} d';
  }

  /// Rates are refreshed hourly, so anything older than that is worth flagging.
  bool get _isStale {
    final DateTime? at = widget.updatedAt;
    if (at == null) return true;
    return DateTime.now().difference(at) >= const Duration(hours: 2);
  }

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return GlassChip(
      onTap: widget.status == RateStatus.updating ? null : widget.onRefresh,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildIndicator(glass),
            const SizedBox(width: 6),
            Text(
              _label,
              style: AppTypography.chip.copyWith(color: _labelColor(glass)),
            ),
          ],
        ),
      ),
    );
  }

  String get _label {
    switch (widget.status) {
      case RateStatus.updating:
        return 'Actualizando';
      case RateStatus.updated:
        return 'Actualizado';
      case RateStatus.idle:
        return _elapsedText;
    }
  }

  Color _labelColor(GlassTokens glass) {
    switch (widget.status) {
      case RateStatus.updating:
        return glass.textSecondary;
      case RateStatus.updated:
        return glass.textPrimary;
      case RateStatus.idle:
        return _isStale ? glass.warning : glass.textMuted;
    }
  }

  Widget _buildIndicator(GlassTokens glass) {
    switch (widget.status) {
      case RateStatus.updating:
        return SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            valueColor: AlwaysStoppedAnimation<Color>(glass.textSecondary),
          ),
        );
      case RateStatus.updated:
        return Icon(Icons.check_rounded, size: 13, color: glass.positive);
      case RateStatus.idle:
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _isStale ? glass.warning : glass.positive,
            shape: BoxShape.circle,
          ),
        );
    }
  }
}
