import 'package:flutter/material.dart';

/// The symbol for a currency.
///
/// VES has no Material icon, so it is drawn as a ringed "Bs" mark; every other
/// currency uses its icon.
class CurrencyGlyph extends StatelessWidget {
  const CurrencyGlyph({
    super.key,
    required this.code,
    required this.icon,
    required this.color,
    this.size = 20,
  });

  final String code;
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (code != 'VES') {
      return Icon(icon, size: size, color: color);
    }

    return Container(
      width: size + 4,
      height: size + 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Bs',
          style: TextStyle(
            color: color,
            fontSize: size * 0.45,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
