import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/components/calculator/currency_glyph.dart';
import 'package:ves_exchange_calculator/models/currency_option.dart';
import 'package:ves_exchange_calculator/utils/number_formatter.dart';

/// The two calculator modes. Stored verbatim in shared preferences, so the
/// strings must not change.
const String kModeCalculator = 'Calculadora';
const String kModeExchange = 'Cambio Monetario';

/// What the app opens on when the user has not chosen: the rates are the
/// reason people open this app, and the plain keypad is one tap away.
const String kDefaultMode = kModeExchange;

/// Reads a stored mode. Anything unrecognised — including a first run with no
/// preference at all — falls back to [kDefaultMode].
///
/// Shared by the calculator and the settings screen so they cannot disagree
/// about what "default" means.
String modeFromStorage(String? stored) {
  return stored == kModeCalculator || stored == kModeExchange
      ? stored!
      : kDefaultMode;
}

/// Lets the user pick a currency. Returns the selected code, or null on
/// dismiss.
///
/// The dialog only reports the choice — reconciling it with the other side of
/// the pair is the caller's job.
Future<String?> showCurrencyPickerDialog({
  required BuildContext context,
  required List<CurrencyOption> options,
  required String selectedCode,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      final ColorScheme scheme = Theme.of(context).colorScheme;

      return AlertDialog(
        title: const Text('Selecciona la moneda'),
        contentPadding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 16.0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final CurrencyOption option in options)
              _CurrencyTile(
                option: option,
                isSelected: option.code == selectedCode,
                onTap: () => Navigator.of(context).pop(option.code),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    },
  );
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final CurrencyOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground =
        isSelected ? scheme.onPrimaryContainer : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Material(
        color: isSelected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.0),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 11.0),
            child: Row(
              children: <Widget>[
                CurrencyGlyph(
                  code: option.code,
                  icon: option.icon,
                  color: foreground,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        option.code,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                      Text(
                        option.code == 'VES'
                            ? 'Moneda base'
                            : '${NumberFormatter.amount(option.value.toStringAsFixed(2))} Bs',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: foreground.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded, size: 18, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Explains where a currency's rate comes from.
Future<void> showCurrencyInfoDialog({
  required BuildContext context,
  required CurrencyOption currency,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final ColorScheme scheme = Theme.of(context).colorScheme;

      return AlertDialog(
        title: Row(
          children: <Widget>[
            CurrencyGlyph(
              code: currency.code,
              icon: currency.icon,
              color: scheme.onSurface,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(currency.label),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '1 ${currency.code} = '
              '${NumberFormatter.amount(currency.value.toStringAsFixed(2))} VES',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            if (currency.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                currency.description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );
}

/// Switches between plain calculator and exchange mode. Returns the chosen
/// mode, or null on dismiss.
Future<String?> showCalculatorModeDialog({
  required BuildContext context,
  required String currentMode,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Tipo de calculadora'),
        contentPadding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 16.0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ModeTile(
              icon: Icons.calculate_outlined,
              title: kModeCalculator,
              subtitle: 'Solo operaciones',
              isSelected: currentMode == kModeCalculator,
              onTap: () => Navigator.of(context).pop(kModeCalculator),
            ),
            _ModeTile(
              icon: Icons.currency_exchange_rounded,
              title: 'Cambio monetario',
              subtitle: 'Convierte a bolívares',
              isSelected: currentMode == kModeExchange,
              onTap: () => Navigator.of(context).pop(kModeExchange),
            ),
          ],
        ),
      );
    },
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground =
        isSelected ? scheme.onPrimaryContainer : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Material(
        color: isSelected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 22, color: foreground),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: foreground.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded, size: 18, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
