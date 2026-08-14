import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ves_exchange_calculator/theme/app_theme.dart';
import 'package:ves_exchange_calculator/widgets/app_toast.dart';

/// Confirmation messages must never dock at the bottom of the screen: that is
/// where the keypad is, and a snack bar sitting on top of the keys was the
/// original complaint.
void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext captured;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              captured = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    return captured;
  }

  testWidgets('el mensaje se muestra en la mitad superior de la pantalla',
      (WidgetTester tester) async {
    final BuildContext context = await pumpHost(tester);

    AppToast.show(context, 'Resultado copiado');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final Finder message = find.text('Resultado copiado');
    expect(message, findsOneWidget);

    final double screenHeight = tester.getSize(find.byType(Scaffold)).height;
    expect(tester.getCenter(message).dy, lessThan(screenHeight / 2));

    // Deja que el temporizador se agote para no dejar timers pendientes.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('no usa SnackBar', (WidgetTester tester) async {
    final BuildContext context = await pumpHost(tester);

    AppToast.show(context, 'Monto convertido copiado');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('desaparece solo', (WidgetTester tester) async {
    final BuildContext context = await pumpHost(tester);

    AppToast.show(context, 'Historial eliminado');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Historial eliminado'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Historial eliminado'), findsNothing);
  });

  testWidgets('un mensaje nuevo reemplaza al anterior',
      (WidgetTester tester) async {
    final BuildContext context = await pumpHost(tester);

    AppToast.show(context, 'Primero');
    await tester.pump();
    AppToast.show(context, 'Segundo');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Primero'), findsNothing);
    expect(find.text('Segundo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });
}
