import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ves_exchange_calculator/theme/glass_tokens.dart';

/// One option of a [SegmentedPills] control.
class PillOption<T> {
  const PillOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// A row of mutually exclusive pills.
///
/// The selected pill is opaque, the rest are glass — the same "the opaque one is
/// the active one" rule the equals key follows on the keypad. That keeps the
/// amber accent reserved for money.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<PillOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Row(
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Pill(
              label: options[i].label,
              isSelected: options[i].value == selected,
              glass: glass,
              onTap: () => onChanged(options[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.isSelected,
    required this.glass,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final GlassTokens glass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? glass.keyOpaqueFill : glass.keyFillMuted,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? Colors.transparent : glass.keyBorder,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isSelected ? glass.keyOpaqueText : glass.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
