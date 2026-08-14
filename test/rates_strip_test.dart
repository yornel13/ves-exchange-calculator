import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ves_exchange_calculator/components/calculator/rates_strip.dart';
import 'package:ves_exchange_calculator/models/currency_option.dart';
import 'package:ves_exchange_calculator/theme/app_theme.dart';

/// The strip is the only place the rates and their freshness are shown, so
/// every state has to be legible on its own.
void main() {
  final List<CurrencyOption> currencies = <CurrencyOption>[
    CurrencyOption(
      code: 'USDT',
      label: 'USDT',
      description: '',
      value: 320.5,
      icon: Icons.currency_bitcoin,
    ),
    CurrencyOption(
      code: 'USD',
      label: 'BCV',
      description: '',
      value: 235.6,
      icon: Icons.attach_money,
    ),
    CurrencyOption(
      code: 'Euro',
      label: 'BCV',
      description: '',
      value: 268.1,
      icon: Icons.euro,
    ),
  ];

  Widget strip(
    RateStatus status, {
    RatesStripStyle style = RatesStripStyle.labeled,
    DateTime? updatedAt,
    VoidCallback? onRefresh,
    ValueChanged<String>? onSelect,
  }) =>
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: RatesStrip(
              currencies: currencies,
              updatedAt: updatedAt,
              status: status,
              style: style,
              onRefresh: onRefresh ?? () {},
              onSelect: onSelect,
            ),
          ),
        ),
      );

  testWidgets('muestra una tasa por moneda con su nombre',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      strip(RateStatus.idle, updatedAt: DateTime.now()),
    );

    expect(find.text('USDT'), findsOneWidget);
    expect(find.text('320,50'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('235,60'), findsOneWidget);
    // `Euro` es el código interno; el chip muestra EUR.
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('268,10'), findsOneWidget);
  });

  testWidgets('el estilo compacto oculta los nombres pero no los montos',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      strip(
        RateStatus.idle,
        style: RatesStripStyle.compact,
        updatedAt: DateTime.now(),
      ),
    );

    expect(find.text('USDT'), findsNothing);
    expect(find.text('EUR'), findsNothing);
    expect(find.text('320,50'), findsOneWidget);
    expect(find.text('268,10'), findsOneWidget);
  });

  testWidgets('el chip de estado dice hace cuánto se actualizó',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      strip(
        RateStatus.idle,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );

    expect(find.text('hace 5 min'), findsOneWidget);
  });

  testWidgets('sin datos avisa en lugar de mostrar un tiempo falso',
      (WidgetTester tester) async {
    await tester.pumpWidget(strip(RateStatus.idle));

    expect(find.text('sin datos'), findsOneWidget);
  });

  testWidgets('mientras carga muestra el progreso', (WidgetTester tester) async {
    await tester.pumpWidget(
      strip(RateStatus.updating, updatedAt: DateTime.now()),
    );

    expect(find.text('Actualizando'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('al terminar confirma la actualización',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      strip(RateStatus.updated, updatedAt: DateTime.now()),
    );

    expect(find.text('Actualizado'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('solo el chip de estado dispara la actualización',
      (WidgetTester tester) async {
    int refreshes = 0;

    await tester.pumpWidget(
      strip(
        RateStatus.idle,
        updatedAt: DateTime.now(),
        onRefresh: () => refreshes++,
      ),
    );

    await tester.tap(find.text('320,50'));
    await tester.pump();
    expect(refreshes, 0);

    await tester.tap(find.byType(RatesStatusChip));
    await tester.pump();
    expect(refreshes, 1);
  });

  testWidgets('no acepta toques mientras carga', (WidgetTester tester) async {
    int refreshes = 0;

    await tester.pumpWidget(
      strip(
        RateStatus.updating,
        updatedAt: DateTime.now(),
        onRefresh: () => refreshes++,
      ),
    );

    await tester.tap(find.byType(RatesStatusChip));
    await tester.pump();
    expect(refreshes, 0);
  });

  testWidgets('tocar una tasa la selecciona', (WidgetTester tester) async {
    final List<String> selected = <String>[];

    await tester.pumpWidget(
      strip(
        RateStatus.idle,
        updatedAt: DateTime.now(),
        onSelect: selected.add,
      ),
    );

    await tester.tap(find.text('320,50'));
    await tester.pump();

    expect(selected, <String>['USDT']);
  });
}
