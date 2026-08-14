import 'package:flutter/material.dart';

import 'package:ves_exchange_calculator/widgets/glass_surface.dart';

/// One key definition in the layout grid.
class _KeySpec {
  const _KeySpec(this.value, this.role, {this.icon, this.flex = 1});

  /// The token sent to the calculator engine.
  final String value;
  final GlassKeyRole role;
  final IconData? icon;

  /// Column span. The equals key spans two.
  final int flex;
}

/// The calculator keypad.
///
/// Lays out on flexible rows rather than fixed aspect ratios, so it always
/// fills exactly the space it is given instead of overflowing on short screens.
class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.onKeyPressed,
    this.translucent = false,
    this.spacing = 8.0,
  });

  final ValueChanged<String> onKeyPressed;

  /// Mirrors the user's "transparent buttons" preference.
  final bool translucent;

  final double spacing;

  static const List<List<_KeySpec>> _layout = <List<_KeySpec>>[
    <_KeySpec>[
      _KeySpec('C', GlassKeyRole.control),
      _KeySpec('%', GlassKeyRole.control),
      _KeySpec('DEL', GlassKeyRole.control, icon: Icons.backspace_outlined),
      _KeySpec('÷', GlassKeyRole.operator),
    ],
    <_KeySpec>[
      _KeySpec('7', GlassKeyRole.digit),
      _KeySpec('8', GlassKeyRole.digit),
      _KeySpec('9', GlassKeyRole.digit),
      _KeySpec('×', GlassKeyRole.operator),
    ],
    <_KeySpec>[
      _KeySpec('4', GlassKeyRole.digit),
      _KeySpec('5', GlassKeyRole.digit),
      _KeySpec('6', GlassKeyRole.digit),
      _KeySpec('−', GlassKeyRole.operator),
    ],
    <_KeySpec>[
      _KeySpec('1', GlassKeyRole.digit),
      _KeySpec('2', GlassKeyRole.digit),
      _KeySpec('3', GlassKeyRole.digit),
      _KeySpec('+', GlassKeyRole.operator),
    ],
    <_KeySpec>[
      _KeySpec('.', GlassKeyRole.digit),
      _KeySpec('0', GlassKeyRole.digit),
      _KeySpec('=', GlassKeyRole.equals, flex: 2),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int row = 0; row < _layout.length; row++) ...<Widget>[
          if (row > 0) SizedBox(height: spacing),
          Expanded(
            child: Row(
              children: <Widget>[
                for (int col = 0; col < _layout[row].length; col++) ...<Widget>[
                  if (col > 0) SizedBox(width: spacing),
                  Expanded(
                    flex: _layout[row][col].flex,
                    child: _buildKey(_layout[row][col]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKey(_KeySpec spec) {
    return GlassKey(
      role: spec.role,
      icon: spec.icon,
      label: spec.icon == null ? spec.value : null,
      semanticLabel: spec.value == 'DEL' ? 'Borrar' : spec.value,
      translucent: translucent,
      onPressed: () => onKeyPressed(spec.value),
    );
  }
}
