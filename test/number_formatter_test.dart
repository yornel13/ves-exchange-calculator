import 'package:flutter_test/flutter_test.dart';

import 'package:ves_exchange_calculator/utils/number_formatter.dart';

/// Venezuelan convention: '.' groups thousands, ',' separates decimals.
void main() {
  group('NumberFormatter.amount', () {
    test('agrupa miles con punto', () {
      expect(NumberFormatter.amount('193377'), '193.377');
      expect(NumberFormatter.amount('1000'), '1.000');
      expect(NumberFormatter.amount('1234567'), '1.234.567');
    });

    test('usa coma para los decimales', () {
      expect(NumberFormatter.amount('193377.60'), '193.377,60');
      expect(NumberFormatter.amount('0.5'), '0,5');
    });

    test('muestra la coma en cuanto se pulsa el punto', () {
      expect(NumberFormatter.amount('1000.'), '1.000,');
    });

    test('no agrupa números de tres dígitos o menos', () {
      expect(NumberFormatter.amount('999'), '999');
      expect(NumberFormatter.amount('7'), '7');
    });

    test('conserva el signo negativo', () {
      expect(NumberFormatter.amount('-1234.5'), '-1.234,5');
    });

    test('deja pasar los valores de error sin tocarlos', () {
      expect(NumberFormatter.amount('Error'), 'Error');
      expect(NumberFormatter.amount('División por cero'), 'División por cero');
      expect(NumberFormatter.amount(''), '');
    });
  });

  group('NumberFormatter.expression', () {
    test('formatea cada número y respeta los operadores', () {
      expect(NumberFormatter.expression('1000+2500'), '1.000+2.500');
      expect(NumberFormatter.expression('12000×3'), '12.000×3');
    });

    test('mantiene el separador decimal a medio escribir', () {
      // Al pulsar '.' el separador debe verse de inmediato.
      expect(NumberFormatter.expression('1000.'), '1.000,');
      expect(NumberFormatter.expression('50.2−1000'), '50,2−1.000');
    });

    test('conserva el porcentaje', () {
      expect(NumberFormatter.expression('1500+10%'), '1.500+10%');
    });

    test('una expresión vacía no produce nada', () {
      expect(NumberFormatter.expression(''), '');
    });
  });
}
