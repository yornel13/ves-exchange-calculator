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
  String _selectedOption = 'Calculadora';
  final List<String> _options = ['Calculadora', 'Cambio Monetario'];

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
                              children: _exchangeOptions.map((option) {
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
                              _currencyField3 = '0.00';
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

  // Campos para el modo Cambio Monetario
  String _currencyField1 = '0.00';
  String _currencyField2 = '0.00';
  String _currencyField3 = '0.00';
  int _activeCurrencyField = 1; // 1, 2 o 3
  String _fromExchangeType = 'BCV';
  String _toExchangeType = 'USD';
  final List<String> _exchangeOptions = ['BCV', 'Euro', 'USD', 'USDT'];

  void _showOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                    'Seleccionar Modo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._options.map((option) {
                    bool isSelected = _selectedOption == option;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedOption = option;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).highlightColor
                              : null,
                          borderRadius: BorderRadius.circular(10.0),
                          border: const Border(
                            bottom: BorderSide(
                              color: Colors.black12,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            option,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 18,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
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

  void _currencyButtonPressed(String buttonText) {
    setState(() {
      // El campo 3 es solo de resultado, no debe permitir escritura desde el teclado
      if (_activeCurrencyField == 3) {
        return;
      }

      String current;
      switch (_activeCurrencyField) {
        case 1:
          current = _currencyField1;
          break;
        case 2:
          current = _currencyField2;
          break;
        case 3:
          current = _currencyField3;
          break;
        default:
          current = _currencyField1;
      }

      if (buttonText == 'DEL') {
        if (current.isNotEmpty) {
          current = current.substring(0, current.length - 1);
        }
      } else {
        // Limitar a un solo punto decimal
        if (buttonText == '.' && current.contains('.')) {
          return;
        }

        // Limitar a 2 decimales después del punto
        if (current.contains('.')) {
          final dotIndex = current.indexOf('.');
          final decimals = current.length - dotIndex - 1;
          if (decimals >= 2 && buttonText != 'DEL' && buttonText != '.') {
            return;
          }
        }

        current += buttonText;
      }

      switch (_activeCurrencyField) {
        case 1:
          _currencyField1 = current;
          break;
        case 2:
          _currencyField2 = current;
          break;
        case 3:
          _currencyField3 = current;
          break;
      }
    });
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

    Widget _buildCurrencyExchangeKeyboard() {
    return Column(
      children: [
        Row(
          children: <Widget>[
            _buildCurrencyButton('7'),
            _buildCurrencyButton('8'),
            _buildCurrencyButton('9'),
          ],
        ),
        Row(
          children: <Widget>[
            _buildCurrencyButton('4'),
            _buildCurrencyButton('5'),
            _buildCurrencyButton('6'),
          ],
        ),
        Row(
          children: <Widget>[
            _buildCurrencyButton('1'),
            _buildCurrencyButton('2'),
            _buildCurrencyButton('3'),
          ],
        ),
        Row(
          children: <Widget>[
            _buildCurrencyButton('.'),
            _buildCurrencyButton('0'),
            _buildCurrencyButton('DEL'),
          ],
        ),
      ],
    );
  }

    Widget _buildCurrencyButton(String buttonText, {int flex = 1}) {
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
                ? const Icon(Icons.backspace, size: 24.0)
                : Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
            onPressed: () => _currencyButtonPressed(buttonText),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showOptionsDialog,
            ),
            const SizedBox(width: 16),
            Text(
              _selectedOption,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
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
                    child: _selectedOption == 'Calculadora'
                        // Modo Calculadora: container con 5 filas de colores diferenciados
                        ? Container(
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
                                    alignment: Alignment.centerRight,
                                    child: const Text(
                                      '1',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                // Separador entre fila 1 y 2 (fino)
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
                          )
                        // Modo Cambio Monetario: contenedor con padding y contenido interno
                        : Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                            TextField(
                              readOnly: true,
                              textAlign: TextAlign.center,
                              onTap: () {
                                setState(() {
                                  _activeCurrencyField = 1;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Personalizado',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 16.0,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ),
                              controller: TextEditingController(
                                text: _currencyField1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              readOnly: true,
                              textAlign: TextAlign.center,
                              onTap: () {
                                setState(() {
                                  _activeCurrencyField = 2;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: _fromExchangeType,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 16.0,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ),
                              controller: TextEditingController(
                                text: _currencyField2.isEmpty
                                    ? ''
                                    : '$_currencyField2 $_fromExchangeType',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: SizedBox(
                                height: 30,
                                width: 30,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  splashRadius: 18,
                                  onPressed: _showExchangeTypeDialog,
                                  icon: Icon(
                                    Icons.sync,
                                    size: 26,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              readOnly: true,
                              textAlign: TextAlign.center,
                              onTap: () {
                                setState(() {
                                  _activeCurrencyField = 3;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: _toExchangeType,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 16.0,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ),
                              controller: TextEditingController(
                                text: _currencyField3.isEmpty
                                    ? ''
                                    : '$_currencyField3 $_toExchangeType',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _currencyField1 = '0.00';
                                      _currencyField2 = '0.00';
                                      _currencyField3 = '0.00';
                                      _activeCurrencyField = 1;
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'Reiniciar',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(
                                        Icons.refresh,
                                        size: 16,
                                      ),
                                    ],
                                  ),
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
                  child: _selectedOption == 'Calculadora'
                      ? _buildCalculatorKeyboard()
                      : Align(
                          alignment: Alignment.bottomCenter,
                          child: _buildCurrencyExchangeKeyboard(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
