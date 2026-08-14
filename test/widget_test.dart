import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ves_exchange_calculator/components/calculator/calculator_keypad.dart';
import 'package:ves_exchange_calculator/theme/app_theme.dart';

void main() {
  Widget keypad(void Function(String) onKeyPressed) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: CalculatorKeypad(onKeyPressed: onKeyPressed)),
      );

  testWidgets('el teclado reporta la tecla pulsada', (WidgetTester tester) async {
    final List<String> pressed = <String>[];

    await tester.pumpWidget(keypad(pressed.add));

    await tester.tap(find.text('7'));
    await tester.tap(find.text('+'));
    await tester.tap(find.text('='));
    await tester.pump();

    expect(pressed, <String>['7', '+', '=']);
  });

  testWidgets('el teclado expone todas las teclas del layout',
      (WidgetTester tester) async {
    await tester.pumpWidget(keypad((_) {}));

    for (final String label in <String>[
      'C', '%', '÷', '×', '−', '+', '=', '.',
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'falta la tecla $label');
    }

    // DEL se dibuja como icono, no como texto.
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
  });
}
