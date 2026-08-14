import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;
import 'package:ves_exchange_calculator/components/calculator/calculator_dialogs.dart';
import 'package:ves_exchange_calculator/components/calculator/calculator_display.dart';
import 'package:ves_exchange_calculator/components/calculator/calculator_header.dart';
import 'package:ves_exchange_calculator/components/calculator/calculator_keypad.dart';
import 'package:ves_exchange_calculator/components/calculator/rates_strip.dart';
import 'package:ves_exchange_calculator/components/settings/settings_screen.dart';
import 'package:ves_exchange_calculator/components/history_screen.dart';
import 'package:ves_exchange_calculator/services/history_service.dart';
import 'package:ves_exchange_calculator/services/rates_controller.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';
import 'package:ves_exchange_calculator/utils/app_links.dart';
import 'package:ves_exchange_calculator/utils/number_formatter.dart';
import 'package:ves_exchange_calculator/widgets/app_toast.dart';
import 'package:ves_exchange_calculator/widgets/background_layer.dart';
import 'package:path_provider/path_provider.dart';

/// Screen margin. Applied per child rather than to the whole column, so the
/// rate strip can scroll edge to edge — see [RatesStrip.horizontalPadding].
const EdgeInsets _kGutter = EdgeInsets.symmetric(horizontal: 16.0);

class CalculatorScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const CalculatorScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with WidgetsBindingObserver {
  String? _backgroundImagePath;
  bool _isButtonTransparent = false;
  RatesStripStyle _ratesStripStyle = RatesStripStyle.labeled;
  final GlobalKey _displayKey = GlobalKey();

  /// Owns rates, overrides and the hourly refresh.
  final RatesController _rates = RatesController();

  /// Drives the brief "Tasas actualizadas" state of the rate chip.
  bool _ratesJustUpdated = false;
  Timer? _rateFeedbackTimer;

  static const _kStartupModeKey = 'startupMode';

  static const _kLastExpressionKey = 'last_calculator_expression';
  static const _kLastResultKey = 'last_calculator_result';
  static const _kFromCurrencyKey = 'from_exchange_type';
  static const _kToCurrencyKey = 'to_exchange_type';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _rates
      ..onEvent = _handleRatesEvent
      ..addListener(_onRatesChanged);

    _loadPreferences().then((_) {
      if (!mounted) return;
      _initRates();
    });

    _rates.startHourlyScheduler(
      shouldRefresh: () => _selectedMode == kModeExchange,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rateFeedbackTimer?.cancel();
    _rates
      ..removeListener(_onRatesChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPreferences();
    }
  }

  void _onRatesChanged() {
    if (mounted) setState(() {});
  }

  /// All rate feedback goes to the rate chip in the header — never to a snack
  /// bar, which docks at the bottom and covers the keypad.
  void _handleRatesEvent(RatesEvent event) {
    if (!mounted) return;

    switch (event) {
      case RatesEvent.fetchStarted:
      case RatesEvent.fetchFinished:
        // The chip reads the controller's loading flag directly.
        break;
      case RatesEvent.ratesUpdated:
      case RatesEvent.newRatesAvailable:
        _flashRatesUpdated();
    }
  }

  /// Briefly turns the rate chip into a confirmation, then lets it fall back to
  /// showing the rate and its timestamp.
  void _flashRatesUpdated() {
    _rateFeedbackTimer?.cancel();
    setState(() {
      _ratesJustUpdated = true;
    });

    _rateFeedbackTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _ratesJustUpdated = false;
      });
    });
  }

  RateStatus get _rateStatus {
    if (_rates.isLoading) return RateStatus.updating;
    if (_ratesJustUpdated) return RateStatus.updated;
    return RateStatus.idle;
  }

  /// Rates are loaded on every start, whatever the mode, so switching to
  /// exchange mode never shows stale numbers.
  Future<void> _initRates() async {
    try {
      await _rates.loadTimestamp();
      await _rates.loadStoredThenRefresh();
      await _rates.applyOverrides();

      final bool hasNew = await _rates.consumeNewRatesFlag();
      if (hasNew && mounted) {
        _flashRatesUpdated();
      }
    } catch (e) {
      debugPrint('Error initializing rates: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _backgroundImagePath = prefs.getString('backgroundImage');
      _isButtonTransparent = prefs.getBool('buttonTransparency') ?? false;
      _ratesStripStyle = RatesStripStyle.fromStorage(
        prefs.getString(RatesStripStyle.prefsKey),
      );

      _selectedMode = modeFromStorage(prefs.getString(_kStartupModeKey));

      // Restaurar última operación, si existe
      _expression = prefs.getString(_kLastExpressionKey) ?? '';
      _result = prefs.getString(_kLastResultKey) ?? '';

      // Restaurar selección de monedas en la fila superior
      _fromExchangeType = prefs.getString(_kFromCurrencyKey) ?? 'USD';
      _toExchangeType = prefs.getString(_kToCurrencyKey) ?? 'Euro';
    });
  }

  Future<void> _saveStartupMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStartupModeKey, mode);
  }

  // Se aplican valores personalizados desde SettingsScreen al volver mediante Navigator.pop

  String _expression = '';
  String _result = '';

  /// Until the stored preference is read. Matches the default so the first
  /// frame does not show the wrong mode and then swap.
  String _selectedMode = kDefaultMode;
  String _fromExchangeType = 'USD'; // valor seleccionado lista 1 (izquierda)
  String _toExchangeType = 'Euro'; // valor seleccionado lista 2 (derecha)

  // Indica si la última acción fue una evaluación con '='
  bool _justEvaluated = false;

  String _inferOperationType(String expression) {
    // Usar la expresión tal como la ve el usuario, con símbolos + - × ÷
    if (expression.contains('+') &&
        !expression.contains('−') &&
        !expression.contains('×') &&
        !expression.contains('÷')) {
      return 'add';
    }
    if (expression.contains('−') &&
        !expression.contains('+') &&
        !expression.contains('×') &&
        !expression.contains('÷')) {
      return 'sub';
    }
    if (expression.contains('×') &&
        !expression.contains('+') &&
        !expression.contains('−') &&
        !expression.contains('÷')) {
      return 'mul';
    }
    if (expression.contains('÷') &&
        !expression.contains('+') &&
        !expression.contains('−') &&
        !expression.contains('×')) {
      return 'div';
    }
    return 'other';
  }

  void _showCurrencyInfoDialog(String code) {
    showCurrencyInfoDialog(context: context, currency: _rates.option(code));
  }

  Future<void> _showModeDialog() async {
    final String? mode = await showCalculatorModeDialog(
      context: context,
      currentMode: _selectedMode,
    );
    if (mode == null || !mounted || mode == _selectedMode) return;

    setState(() {
      _selectedMode = mode;
    });
    await _saveStartupMode(mode);

    if (mode == kModeExchange) {
      await _rates.refresh();
    }
  }

  Future<void> _openHistory() async {
    final selected = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Velo detrás del sheet, para que el vidrio tenga algo que oscurecer.
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext ctx) => const HistorySheet(),
    );

    if (!mounted) return;

    if (selected is HistoryEntry) {
      setState(() {
        _expression = selected.expression;
        _result = selected.result;
        _justEvaluated = true;
      });
    }
  }

  Future<void> _shareCalculatorDisplay() async {
    try {
      final boundary =
          _displayKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image captured = await boundary.toImage(pixelRatio: 3.0);
      final ui.Image image = await _composeOnOpaqueBackground(captured);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/calculator_display.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(filePath)], text: 'Calculadora de cambio');
    } catch (_) {
      // Si algo falla al capturar/compartir, simplemente no hace nada.
    }
  }

  /// Hands out the store link so someone else can install the app. Separate
  /// from [_shareCalculatorDisplay], which shares a screenshot of the result.
  Future<void> _shareApp() async {
    try {
      await Share.share(
        AppLinks.shareMessage,
        subject: 'Calculadora de cambio',
      );
    } catch (e) {
      debugPrint('Error sharing app link: $e');
      if (!mounted) return;
      AppToast.show(
        context,
        'No se pudo abrir el menú de compartir',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  /// The display is a translucent panel, and a [BackdropFilter] cannot sample
  /// anything outside its own repaint boundary — so a raw capture comes out as
  /// a semi-transparent ghost. Paint it over the brand background first.
  Future<ui.Image> _composeOnOpaqueBackground(ui.Image source) async {
    final GlassTokens glass = context.glass;
    const double margin = 56.0;

    final double width = source.width + margin * 2;
    final double height = source.height + margin * 2;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, height), <Color>[
          glass.backgroundTop,
          glass.backgroundBottom,
        ]),
    );
    canvas.drawImage(source, const Offset(margin, margin), Paint());

    return recorder.endRecording().toImage(width.round(), height.round());
  }

  bool _isOperator(String buttonText) {
    return buttonText == '+' ||
        buttonText == '−' ||
        buttonText == '×' ||
        buttonText == '÷';
  }

  double _getConvertedAmount() {
    if (_result.isEmpty) {
      return 0.0;
    }

    final double? baseResult = double.tryParse(_result.replaceAll(',', '.'));
    if (baseResult == null) {
      return 0.0;
    }

    final double fromValue = _rates.valueOf(_fromExchangeType);
    final double toValue = _rates.valueOf(_toExchangeType);

    if (fromValue == 0.0 || toValue == 0.0) {
      return 0.0;
    }

    return baseResult * fromValue / toValue;
  }

  Future<void> _showSimpleCurrencyDialog({required bool isLeft}) async {
    final String? picked = await showCurrencyPickerDialog(
      context: context,
      options: _rates.currencies,
      selectedCode: isLeft ? _fromExchangeType : _toExchangeType,
    );
    if (picked == null || !mounted) return;

    await _applyCurrency(picked, isLeft: isLeft);
  }

  /// Applies a currency choice. Picking the currency already in use on the
  /// other side swaps the pair instead of leaving a same-to-same conversion.
  Future<void> _applyCurrency(String code, {required bool isLeft}) async {
    setState(() {
      if (isLeft) {
        if (code == _toExchangeType) {
          _toExchangeType = _fromExchangeType;
        }
        _fromExchangeType = code;
      } else {
        if (code == _fromExchangeType) {
          _fromExchangeType = _toExchangeType;
        }
        _toExchangeType = code;
      }
    });
    await _saveCurrencySelection();
  }

  void _swapExchangeTypes() {
    setState(() {
      final temp = _fromExchangeType;
      _fromExchangeType = _toExchangeType;
      _toExchangeType = temp;
    });
    _saveCurrencySelection();
  }

  Future<void> _saveCurrencySelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFromCurrencyKey, _fromExchangeType);
    await prefs.setString(_kToCurrencyKey, _toExchangeType);
  }

  void _buttonPressed(String buttonText) {
    // Feedback háptico en cada pulsación de botón
    HapticFeedback.lightImpact();

    setState(() {
      if (buttonText == 'C') {
        _expression = '';
        _result = '';
        _justEvaluated = false;
        // Borrar última operación persistida
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove(_kLastExpressionKey);
          prefs.remove(_kLastResultKey);
        });
      } else if (buttonText == '%') {
        // Comportamiento CORRECTO de calculadoras estándar:
        // El botón % solo agrega el símbolo '%' a la expresión
        // NO calcula nada hasta que se presione '='

        if (_expression.isEmpty) {
          return;
        }

        // No permitir % después de un operador o si ya hay un % al final
        if (_expression.isNotEmpty) {
          final lastChar = _expression[_expression.length - 1];
          if (_isOperator(lastChar) || lastChar == '%') {
            return;
          }
        }

        // Simplemente agregar el símbolo % al final de la expresión
        _expression += '%';
        _justEvaluated = false;
      } else if (buttonText == 'DEL') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        _justEvaluated = false;
      } else if (buttonText == '=') {
        // Si no hay expresión (por ejemplo, la borraste toda con DEL),
        // comportarse como 'C' para evitar mostrar Error innecesario.
        if (_expression.trim().isEmpty) {
          _expression = '';
          _result = '';
          _justEvaluated = false;
          return;
        }

        try {
          // Eliminar operadores sobrantes al final (por ejemplo: 85-15+)
          String finalExpression = _expression.trim();
          while (finalExpression.isNotEmpty &&
              _isOperator(finalExpression[finalExpression.length - 1])) {
            finalExpression = finalExpression.substring(
              0,
              finalExpression.length - 1,
            );
          }

          // Si después de limpiar ya no queda una expresión válida, no evaluar
          if (finalExpression.isEmpty) {
            _justEvaluated = false;
            return;
          }

          // Manejar porcentajes con lógica correcta según el operador
          // Buscar patrones como "A + B%" o "A - B%" o "A × B%" o "A ÷ B%"
          finalExpression = finalExpression.replaceAllMapped(
            RegExp(r'(\d+(?:\.\d+)?)\s*([+\-×÷−])\s*(\d+(?:\.\d+)?)%'),
            (match) {
              final firstNum = match.group(1)!;
              final operator = match.group(2)!;
              final secondNum = match.group(3)!;

              // Para suma y resta: A + B% = A + (A × B/100)
              if (operator == '+' || operator == '−' || operator == '-') {
                return '$firstNum$operator($firstNum*$secondNum/100)';
              } else {
                // Para multiplicación y división: A × B% = A × (B/100)
                return '$firstNum$operator($secondNum/100)';
              }
            },
          );

          // Manejar porcentajes simples como "45%" que no tienen operador antes
          finalExpression = finalExpression.replaceAllMapped(
            RegExp(r'^(\d+(?:\.\d+)?)%$'),
            (match) => '(${match.group(1)}/100)',
          );

          finalExpression = finalExpression.replaceAll('×', '*');
          finalExpression = finalExpression.replaceAll('÷', '/');
          finalExpression = finalExpression.replaceAll('−', '-');

          Parser p = Parser();
          Expression exp = p.parse(finalExpression);
          ContextModel cm = ContextModel();
          double eval = exp.evaluate(EvaluationType.REAL, cm);

          // Detectar división por cero (resultado infinito o NaN)
          if (eval.isInfinite || eval.isNaN) {
            _result = 'División por cero';
            _justEvaluated = true;
            return;
          }

          _result = eval.toString();
          if (_result.endsWith('.0')) {
            _result = _result.substring(0, _result.length - 2);
          }

          // Guardar en historial si el resultado es válido
          if (_result.isNotEmpty &&
              _result != 'Error' &&
              _result != 'División por cero') {
            final String opType = _inferOperationType(_expression);
            HistoryService.addEntry(
              expression: _expression,
              result: _result,
              operationType: opType,
            );

            // Persistir última operación para restaurarla al abrir la app
            _saveLastOperation();
          }

          _justEvaluated = true;
        } catch (e) {
          _result = 'Error';
          _justEvaluated = true;
        }
      } else {
        // Gestión especial cuando venimos de un '='
        if (_justEvaluated) {
          if (_isOperator(buttonText) &&
              _result.isNotEmpty &&
              _result != 'Error' &&
              _result != 'División por cero') {
            // Continuar desde el resultado anterior: resultado + operador
            _expression = _result;
            // seguimos abajo para agregar el operador
          } else {
            // Si es un número o punto, empezar una nueva operación
            _expression = '';
            _result = '';
          }
          _justEvaluated = false;
        }

        // No permitir que la expresión comience con un operador
        if (_expression.isEmpty && _isOperator(buttonText)) {
          return;
        }

        // Si se presiona un operador y el último carácter ya es un operador,
        // reemplazar el operador anterior por el nuevo
        if (_isOperator(buttonText) && _expression.isNotEmpty) {
          final lastChar = _expression[_expression.length - 1];
          if (_isOperator(lastChar)) {
            _expression =
                _expression.substring(0, _expression.length - 1) + buttonText;
            return;
          }
        }

        if (buttonText == '.') {
          final currentNumber = _getCurrentNumber(_expression);

          // Si no hay número actual (por ejemplo, comenzando con '.'), usar '0.'
          if (currentNumber.isEmpty) {
            _expression += '0.';
            return;
          }

          // Evitar múltiples puntos en el mismo número
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

  Future<void> _saveLastOperation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastExpressionKey, _expression);
    await prefs.setString(_kLastResultKey, _result);
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

  bool _isExpressionValid() {
    if (_expression.isEmpty) return true;

    // Verificar si termina con un operador (excepto %)
    final lastChar = _expression[_expression.length - 1];
    if (_isOperator(lastChar)) {
      return false;
    }

    // Verificar múltiples puntos decimales en un número
    final currentNumber = _getCurrentNumber(_expression);
    final dotCount = currentNumber.split('.').length - 1;
    if (dotCount > 1) {
      return false;
    }

    // Verificar operadores consecutivos
    for (int i = 0; i < _expression.length - 1; i++) {
      if (_isOperator(_expression[i]) && _isOperator(_expression[i + 1])) {
        return false;
      }
    }

    return true;
  }

  Future<void> _copyToClipboard(String value, String message) async {
    if (value.isEmpty || value == 'Error' || value == 'División por cero') {
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;

    AppToast.show(context, message, icon: Icons.copy_rounded);
  }

  String _formatNumberForDisplay(String value) => NumberFormatter.amount(value);

  String _formatExpressionForDisplay(String expression) =>
      NumberFormatter.expression(expression);

  Future<void> _switchToExchangeMode() async {
    setState(() {
      _selectedMode = kModeExchange;
    });
    await _saveStartupMode(kModeExchange);
    await _rates.refresh();
  }

  Future<void> _openSettings() async {
    // Ajustes comparte el mismo RatesController, así que cualquier cambio de
    // montos ya está aplicado al volver: solo hay que releer las preferencias
    // de apariencia y modo de inicio.
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(
          rates: _rates,
          showMonetarySection: _selectedMode == kModeExchange,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (!mounted) return;
    await _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final bool isExchangeMode = _selectedMode == kModeExchange;
    final double bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BackgroundLayer(
        imagePath: _backgroundImagePath,
        child: SafeArea(
          bottom: false,
          // Only the vertical insets are shared. The horizontal margin belongs
          // to each child, so the rate strip can run edge to edge while
          // everything else keeps the 16pt gutter.
          child: Padding(
            padding: EdgeInsets.only(top: 4.0, bottom: 12.0 + bottomInset),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: _kGutter,
                  child: CalculatorHeader(
                    title: isExchangeMode ? 'Cambio monetario' : 'Calculadora',
                    onOpenHistory: _openHistory,
                    onShare: _shareCalculatorDisplay,
                    onOpenModeDialog: _showModeDialog,
                    onOpenSettings: _openSettings,
                    onShareApp: _shareApp,
                  ),
                ),
                const SizedBox(height: 2),
                if (isExchangeMode)
                  RatesStrip(
                    currencies: _rates.quotableCurrencies,
                    updatedAt: _rates.lastUpdate,
                    status: _rateStatus,
                    style: _ratesStripStyle,
                    onRefresh: _rates.refresh,
                    onSelect: (String code) =>
                        _applyCurrency(code, isLeft: true),
                    horizontalPadding: _kGutter.horizontal / 2,
                  )
                else
                  Padding(
                    padding: _kGutter,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ModeChip(onTap: _switchToExchangeMode),
                    ),
                  ),
                const SizedBox(height: 14),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: _kGutter,
                    child: RepaintBoundary(
                      key: _displayKey,
                      child: CalculatorDisplay(
                        isExchangeMode: isExchangeMode,
                        expression: _formatExpressionForDisplay(_expression),
                        result: _formatNumberForDisplay(_result),
                        isExpressionValid: _isExpressionValid(),
                        from: _rates.option(_fromExchangeType),
                        to: _rates.option(_toExchangeType),
                        convertedAmount: _formatNumberForDisplay(
                          _getConvertedAmount().toStringAsFixed(2),
                        ),
                        onPickFrom: () =>
                            _showSimpleCurrencyDialog(isLeft: true),
                        onPickTo: () =>
                            _showSimpleCurrencyDialog(isLeft: false),
                        onSwap: _swapExchangeTypes,
                        onCopyResult: () => _copyToClipboard(
                          _result,
                          'Resultado copiado al portapapeles',
                        ),
                        onCopyConverted: () => _copyToClipboard(
                          _getConvertedAmount().toStringAsFixed(2),
                          'Monto convertido copiado',
                        ),
                        onShowCurrencyInfo: () =>
                            _showCurrencyInfoDialog(_toExchangeType),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  // Plain calculator mode has less to show, so the panel gets a
                  // smaller share and the keys grow instead of leaving a void.
                  flex: isExchangeMode ? 3 : 4,
                  child: Padding(
                    padding: _kGutter,
                    child: CalculatorKeypad(
                      onKeyPressed: _buttonPressed,
                      translucent: _isButtonTransparent,
                    ),
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
