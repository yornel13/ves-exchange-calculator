import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ves_exchange_calculator/components/settings/settings_section.dart';
import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';
import 'package:ves_exchange_calculator/utils/number_formatter.dart';

/// Everything the section needs to know about one currency.
class RateFieldData {
  const RateFieldData({
    required this.code,
    required this.controller,
    required this.official,
  });

  final String code;
  final TextEditingController controller;

  /// Official rate, or null while it has never been fetched.
  final double? official;

  /// True when the field already holds the official value, so restoring it
  /// would do nothing.
  bool get matchesOfficial {
    final double? value = official;
    if (value == null) return false;
    return controller.text.trim().replaceAll(',', '.') ==
        value.toStringAsFixed(2);
  }
}

/// Lets the user override each rate. Editing these is the whole reason the
/// settings screen exists, so it gets the most room.
class CustomRatesSection extends StatelessWidget {
  const CustomRatesSection({
    super.key,
    required this.fields,
    required this.onSaveAll,
    required this.onRestoreOne,
    required this.onRestoreAll,
  });

  final List<RateFieldData> fields;
  final VoidCallback onSaveAll;
  final ValueChanged<String> onRestoreOne;
  final VoidCallback onRestoreAll;

  bool get _allMatchOfficial => fields.every((RateFieldData f) => f.matchesOfficial);

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return SettingsSection(
      title: 'Montos personalizados (VES)',
      action: _IconAction(
        icon: Icons.restart_alt_rounded,
        tooltip: 'Restablecer todos los valores oficiales',
        onPressed: _allMatchOfficial ? null : onRestoreAll,
      ),
      children: <Widget>[
        for (int i = 0; i < fields.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 16),
          _RateField(
            data: fields[i],
            onRestore: () => onRestoreOne(fields[i].code),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: glass.keyOpaqueFill,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onSaveAll();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13.0),
                child: Text(
                  'Guardar cambios',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: glass.keyOpaqueText,
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

class _RateField extends StatelessWidget {
  const _RateField({required this.data, required this.onRestore});

  final RateFieldData data;
  final VoidCallback onRestore;

  /// Digits plus one separator — comma or period — and at most two decimals.
  static final List<TextInputFormatter> _twoDecimals = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'^\d*([.,]\d{0,2})?')),
  ];

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;
    final double? official = data.official;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '${data.code} a VES',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: glass.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              official == null
                  ? 'oficial: --'
                  : 'oficial: ${NumberFormatter.amount(official.toStringAsFixed(2))} Bs',
              style: AppTypography.chip.copyWith(color: glass.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: data.controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: _twoDecimals,
                style: TextStyle(
                  fontSize: 15,
                  color: glass.textPrimary,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
                cursorColor: glass.accent,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: glass.keyFillMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 13.0,
                  ),
                  prefixText: '${data.code}  ',
                  prefixStyle: TextStyle(
                    fontSize: 13,
                    color: glass.textMuted,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: BorderSide(color: glass.keyBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: BorderSide(color: glass.keyBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: BorderSide(color: glass.accent, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _IconAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Volver al valor oficial de ${data.code}',
              onPressed:
                  data.matchesOfficial || official == null ? null : onRestore,
            ),
          ],
        ),
      ],
    );
  }
}

/// Square glass button used for the restore actions.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;

  /// Null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;
    final bool enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? glass.keyFill : glass.keyFillMutedTranslucent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.0),
          side: BorderSide(color: glass.keyBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: Icon(
                icon,
                size: 19,
                color: enabled ? glass.textPrimary : glass.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
