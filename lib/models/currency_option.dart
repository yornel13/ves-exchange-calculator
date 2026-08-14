import 'package:flutter/material.dart';

/// A currency the calculator can convert between.
///
/// [value] is the currency's worth in VES, so VES itself is always 1.0.
class CurrencyOption {
  CurrencyOption({
    required this.code,
    required this.label,
    required this.description,
    required this.value,
    required this.icon,
  });

  final String code;
  final String label;
  final String description;
  double value;
  final IconData icon;
}
