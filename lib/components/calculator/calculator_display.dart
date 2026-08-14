import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/components/calculator/currency_glyph.dart';
import 'package:ves_exchange_calculator/models/currency_option.dart';
import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';
import 'package:ves_exchange_calculator/widgets/glass_surface.dart';

/// The display panel: the only surface in the app with a real backdrop blur.
///
/// Hierarchy is deliberate — the result dominates at 44px, the expression is
/// quiet supporting text, and the converted amount carries the single accent
/// color. All numeric text uses tabular figures so digits never shift.
class CalculatorDisplay extends StatelessWidget {
  const CalculatorDisplay({
    super.key,
    required this.isExchangeMode,
    required this.expression,
    required this.result,
    required this.isExpressionValid,
    required this.from,
    required this.to,
    required this.convertedAmount,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSwap,
    required this.onCopyResult,
    required this.onCopyConverted,
    required this.onShowCurrencyInfo,
  });

  final bool isExchangeMode;

  /// Already formatted for display (thousands separators applied).
  final String expression;
  final String result;
  final String convertedAmount;

  final bool isExpressionValid;

  final CurrencyOption from;
  final CurrencyOption to;

  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onSwap;
  final VoidCallback onCopyResult;
  final VoidCallback onCopyConverted;
  final VoidCallback onShowCurrencyInfo;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18.0, 16.0, 18.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The selector row is pinned to the top of the panel. Centering the
          // whole column instead left a wide gap above it.
          if (isExchangeMode) _CurrencyRow(
            from: from,
            to: to,
            onPickFrom: onPickFrom,
            onPickTo: onPickTo,
            onSwap: onSwap,
          ),
          Expanded(
            child: Column(
              // The numbers take the space left between the pinned rows.
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      expression,
                      textAlign: TextAlign.right,
                      style: AppTypography.expression.copyWith(
                        // An invalid expression (trailing operator, double
                        // decimal point) is warned about, not blocked.
                        color: isExpressionValid
                            ? glass.textSecondary
                            : glass.warning,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onCopyResult,
                  borderRadius: BorderRadius.circular(12.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        result.isEmpty ? '0' : result,
                        textAlign: TextAlign.right,
                        style: AppTypography.result.copyWith(
                          color: result.isEmpty
                              ? glass.textMuted
                              : glass.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isExchangeMode) ...<Widget>[
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: glass.divider),
            const SizedBox(height: 12),
            _ConvertedRow(
              to: to,
              amount: convertedAmount,
              onCopy: onCopyConverted,
              onShowInfo: onShowCurrencyInfo,
            ),
          ],
        ],
      ),
    );
  }
}

/// Source and target currency selectors with the swap control between them.
class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSwap,
  });

  final CurrencyOption from;
  final CurrencyOption to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Row(
      children: <Widget>[
        Expanded(
          child: _CurrencyButton(
            currency: from,
            alignment: Alignment.centerLeft,
            onTap: onPickFrom,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Material(
            color: glass.chipFill,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              onPressed: onSwap,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
              tooltip: 'Invertir monedas',
              icon: Icon(
                Icons.swap_horiz_rounded,
                size: 18,
                color: glass.textPrimary,
              ),
            ),
          ),
        ),
        Expanded(
          child: _CurrencyButton(
            currency: to,
            alignment: Alignment.centerRight,
            onTap: onPickTo,
          ),
        ),
      ],
    );
  }
}

class _CurrencyButton extends StatelessWidget {
  const _CurrencyButton({
    required this.currency,
    required this.alignment,
    required this.onTap,
  });

  final CurrencyOption currency;
  final Alignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Align(
      alignment: alignment,
      child: GlassChip(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CurrencyGlyph(
                code: currency.code,
                icon: currency.icon,
                color: glass.textPrimary,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                // The code, not the label: USD and Euro share the label "BCV",
                // so labelling both selectors with it makes them identical.
                currency.code,
                style: AppTypography.currencyCode.copyWith(
                  color: glass.textPrimary,
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: glass.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The converted amount — the reason the app exists, so it gets the accent.
class _ConvertedRow extends StatelessWidget {
  const _ConvertedRow({
    required this.to,
    required this.amount,
    required this.onCopy,
    required this.onShowInfo,
  });

  final CurrencyOption to;
  final String amount;
  final VoidCallback onCopy;
  final VoidCallback onShowInfo;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Row(
      children: <Widget>[
        InkWell(
          onTap: onShowInfo,
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  to.code,
                  style: AppTypography.moneyLabel.copyWith(
                    color: glass.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: glass.textMuted,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 4.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    amount,
                    textAlign: TextAlign.right,
                    style: AppTypography.money.copyWith(color: glass.accent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
