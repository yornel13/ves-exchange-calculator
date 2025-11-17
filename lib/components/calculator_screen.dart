import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;
import 'package:smart_calculator/components/settings_screen.dart';

class CalculatorScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;

  const CalculatorScreen({super.key, required this.onThemeChanged});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> with WidgetsBindingObserver {
  String? _backgroundImagePath;
  bool _isButtonTransparent = false;

      @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
  }

  void _showExchangeTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempFrom = _fromExchangeType;
        String tempTo = _toExchangeType;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Seleccionar tipo de cambio monetario',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Lista izquierda: incluye "Personalizado"
                          Expanded(
                            child: Column(
                              children: _exchangeOptions.map((option) {
                                final bool isSelected = tempFrom == option;
                                final bool isDisabled = tempTo == option;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20.0),
                                    onTap: isDisabled
                                        ? null
                                        : () {
                                            setStateDialog(() {
                                              tempFrom = option;
                                            });
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6.0,
                                        horizontal: 14.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : isDisabled
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                    .withOpacity(0.2)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                    .withOpacity(0.4),
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                        boxShadow: isDisabled
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Text(
                                          option,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                : isDisabled
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withOpacity(0.4)
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Icon(
                              Icons.keyboard_double_arrow_right,
                              size: 24,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: _exchangeOptionsRight.map((option) {
                                final bool isSelected = tempTo == option;
                                final bool isDisabled = tempFrom == option;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20.0),
                                    onTap: isDisabled
                                        ? null
                                        : () {
                                            setStateDialog(() {
                                              tempTo = option;
                                            });
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6.0,
                                        horizontal: 14.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : isDisabled
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                    .withOpacity(0.2)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                    .withOpacity(0.4),
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                        boxShadow: isDisabled
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Text(
                                          option,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                : isDisabled
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withOpacity(0.4)
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _fromExchangeType = tempFrom;
                              _toExchangeType = tempTo;
                            });
                            Navigator.of(context).pop();
                          },
                          child: const Text('OK'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

    @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPreferences();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundImagePath = prefs.getString('backgroundImage');
      _isButtonTransparent = prefs.getBool('buttonTransparency') ?? false;
    });
  }

  String _expression = '';
  String _result = '';

  String _fromExchangeType = 'BCV'; // valor seleccionado lista 1 (izquierda)
  String _toExchangeType = 'USD';   // valor seleccionado lista 2 (derecha)
  // Opciones para la lista izquierda (incluye "Personalizado"), ordenadas alfabéticamente
  final List<String> _exchangeOptions = [
    'BCV',
    'Euro',
    'Personalizado',
    'USD',
    'USDT',
  ];
  // Opciones para la lista derecha (sin "Personalizado"), ordenadas alfabéticamente
  final List<String> _exchangeOptionsRight = [
    'BCV',
    'Euro',
    'USD',
    'USDT',
  ];

  void _swapExchangeTypes() {
    setState(() {
      final temp = _fromExchangeType;
      _fromExchangeType = _toExchangeType;
      _toExchangeType = temp;
    });
  }

  void _buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == 'C') {
        _expression = '';
        _result = '';
      } else if (buttonText == 'DEL') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (buttonText == '=') {
        try {
          String finalExpression = _expression;
          finalExpression = finalExpression.replaceAll('×', '*');
          finalExpression = finalExpression.replaceAll('÷', '/');
          finalExpression = finalExpression.replaceAll('−', '-');

          Parser p = Parser();
          Expression exp = p.parse(finalExpression);
          ContextModel cm = ContextModel();
          double eval = exp.evaluate(EvaluationType.REAL, cm);

          _result = eval.toString();
          if (_result.endsWith('.0')) {
            _result = _result.substring(0, _result.length - 2);
          }
        } catch (e) {
          _result = 'Error';
        }
      } else {
        if (buttonText == '.') {
          final currentNumber = _getCurrentNumber(_expression);
          if (currentNumber.contains('.')) {
            return;
          }
        } else if (RegExp(r'[0-9]').hasMatch(buttonText)) {
          final currentNumber = _getCurrentNumber(_expression);
          if (currentNumber.contains('.')) {
            final dotIndex = currentNumber.indexOf('.');
            final decimals = currentNumber.length - dotIndex - 1;
            if (decimals >= 2) {
              return;
            }
          }
        }

        _expression += buttonText;
      }
    });
  }

  String _getCurrentNumber(String expression) {
    if (expression.isEmpty) {
      return '';
    }
    String buffer = '';
    for (int i = expression.length - 1; i >= 0; i--) {
      final ch = expression[i];
      if (!RegExp(r'[0-9.]').hasMatch(ch)) {
        break;
      }
      buffer = ch + buffer;
    }
    return buffer;
  }

  Widget _buildButton(String buttonText, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: AspectRatio(
          aspectRatio: 1 / 0.95,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              backgroundColor: _isButtonTransparent
                  ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4)
                  : Theme.of(context).colorScheme.surfaceVariant,
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: buttonText == "DEL"
                ? const Icon(Icons.backspace, size: 30.0)
                : Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 24.0, // Reducido para botones más pequeños
                      fontWeight: FontWeight.w900,
                    ),
                  ),
            onPressed: () => _buttonPressed(buttonText),
          ),
        ),
      ),
    );
  }

    Widget _buildCalculatorKeyboard() {
    return Column(
      children: [
        Row(
          children: <Widget>[
            _buildButton("C"),
            const Expanded(child: SizedBox()),
            _buildButton("DEL"),
            _buildButton("÷"),
          ],
        ),
        Row(
          children: <Widget>[
            _buildButton("7"),
            _buildButton("8"),
            _buildButton("9"),
            _buildButton("×"),
          ],
        ),
        Row(
          children: <Widget>[
            _buildButton("4"),
            _buildButton("5"),
            _buildButton("6"),
            _buildButton("−"),
          ],
        ),
        Row(
          children: <Widget>[
            _buildButton("1"),
            _buildButton("2"),
            _buildButton("3"),
            _buildButton("+"),
          ],
        ),
        Row(
          children: <Widget>[
            _buildButton("."),
            _buildButton("0"),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: AspectRatio(
                  // Doble de ancho que un botón normal, pero misma altura (2/0.95)
                  aspectRatio: 2 / 0.95,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      backgroundColor: _isButtonTransparent
                          ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4)
                          : Theme.of(context).colorScheme.surfaceVariant,
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    child: const Text(
                      '=',
                      style: TextStyle(
                        fontSize: 30.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: () => _buttonPressed('='),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calculadora',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: widget.onThemeChanged,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadPreferences());
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image:
              _backgroundImagePath != null &&
                  File(_backgroundImagePath!).existsSync()
              ? DecorationImage(
                  image: FileImage(File(_backgroundImagePath!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Padding(
                    // Solo separación inferior; el padding externo de 16 ya maneja los bordes laterales
                    padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        children: [
                                // Fila 1
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    alignment: Alignment.center,
                                    child: Stack(
                                      children: [
                                        // Fila de ancho completo: texto izq, botón, texto der
                                        Align(
                                          alignment: Alignment.center,
                                          child: Row(
                                            children: [
                                              // Texto izquierda dentro de Expanded
                                              Expanded(
                                                child: Align(
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    _fromExchangeType,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Botón centrado geométricamente
                                              SizedBox(
                                                width: 40,
                                                height: 32,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(8.0),
                                                    onTap: _swapExchangeTypes,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.10),
                                                        borderRadius:
                                                            BorderRadius.circular(8.0),
                                                      ),
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.compare_arrows,
                                                          size: 18,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Texto derecha dentro de Expanded
                                              Expanded(
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    _toExchangeType,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Número de la fila en la esquina derecha
                                        const Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            '1',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Separador entre fila 1 y 2 (fino, 50% del ancho y centrado)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15.0,
                                  ),
                                  child: Center(
                                    child: FractionallySizedBox(
                                      widthFactor: 0.5,
                                      child: Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.15),
                                      ),
                                    ),
                                  ),
                                ),

                                // Fila 2
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    alignment: Alignment.centerRight,
                                    child: const Text(
                                      '2',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                // Separador entre fila 2 y 3 (fino)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15.0,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.15),
                                  ),
                                ),

                                // Fila 3: expresión
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _expression,
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          '3',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Separador entre fila 3 (expresión) y fila 4 (resultado) - GRUESO
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15.0,
                                  ),
                                  child: Divider(
                                    height: 2,
                                    thickness: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.30),
                                  ),
                                ),

                                // Fila 4: resultado
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _result,
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          '4',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Separador entre fila 4 y 5 (fino) con botón centrado
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15.0,
                                  ),
                                  child: SizedBox(
                                    height: 32,
                                    child: Row(
                                      children: [
                                        // Línea a la izquierda del botón
                                        Expanded(
                                          child: Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.15),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Botón cuadrado centrado
                                        SizedBox(
                                          width: 40,
                                          height: 32,
                                          child: ElevatedButton(
                                            onPressed: _showExchangeTypeDialog,
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.10),
                                              foregroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              elevation: 0,
                                            ),
                                            child: const Icon(
                                              Icons.keyboard_double_arrow_down,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Línea a la derecha del botón
                                        Expanded(
                                          child: Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.15),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Fila 5
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    alignment: Alignment.centerRight,
                                    child: const Text(
                                      '5',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const Divider(),
                Expanded(
                  flex: 3,
                  child: _buildCalculatorKeyboard(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
