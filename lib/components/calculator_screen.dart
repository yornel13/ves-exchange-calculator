import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;
import 'package:ves_exchange_calculator/components/settings_screen.dart';
import 'package:ves_exchange_calculator/components/history_screen.dart';
import 'package:ves_exchange_calculator/services/rate_service.dart';
import 'package:ves_exchange_calculator/services/history_service.dart';
import 'package:path_provider/path_provider.dart';

class CurrencyOption {
  final String code;
  final String label;
  final String description;
  double value;
  final IconData icon;

  CurrencyOption({
    required this.code,
    required this.label,
    required this.description,
    required this.value,
    required this.icon,
  });
}

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
  bool _isLoadingRates = false;
  final GlobalKey _displayKey = GlobalKey();

  Timer? _globalRatesTimer;

  static const _kUsdOverrideKey = 'usd_override';
  static const _kEurOverrideKey = 'eur_override';
  static const _kUsdtOverrideKey = 'usdt_override';
  static const _kOverridesTimestampKey = 'ratesOverrideTimestampMs';
  static const _kLastOfficialUsdKey = 'last_official_usd_ves';
  static const _kLastOfficialEurKey = 'last_official_eur_ves';
  static const _kLastOfficialUsdtKey = 'last_official_usdt_ves';
  static const _kHasNewOfficialRatesKey = 'hasNewOfficialRates';
  static const _kLastRatesUpdateTimestampKey = 'lastRatesUpdateTimestampMs';
  static const _kStartupModeKey = 'startupMode';

  static const _kLastExpressionKey = 'last_calculator_expression';
  static const _kLastResultKey = 'last_calculator_result';
  static const _kFromCurrencyKey = 'from_exchange_type';
  static const _kToCurrencyKey = 'to_exchange_type';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cargar preferencias y luego inicializar tasas SIEMPRE (independiente del modo)
    _loadPreferences().then((_) {
      if (!mounted) return;
      _initRatesOnStartup();
    });
    _setupGlobalRatesScheduler();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _globalRatesTimer?.cancel();
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

      final String? startupMode = prefs.getString(_kStartupModeKey);
      if (startupMode == 'Calculadora' ||
          startupMode == 'Cambio Monetario') {
        _selectedMode = startupMode!;
      } else {
        _selectedMode = 'Calculadora';
      }

      // Restaurar última operación, si existe
      _expression = prefs.getString(_kLastExpressionKey) ?? '';
      _result = prefs.getString(_kLastResultKey) ?? '';

      // Restaurar selección de monedas en la fila superior
      _fromExchangeType = prefs.getString(_kFromCurrencyKey) ?? 'USD';
      _toExchangeType = prefs.getString(_kToCurrencyKey) ?? 'Euro';
    });
  }

  /// Verifica si debe actualizar las tasas comparando la hora actual
  /// con la hora de la última actualización guardada.
  /// Retorna true si la hora (truncada) es diferente.
  Future<bool> _shouldUpdateRates() async {
    final prefs = await SharedPreferences.getInstance();
    final int? lastUpdateMs = prefs.getInt(_kLastRatesUpdateTimestampKey);

    // Si nunca se ha actualizado, debe actualizar
    if (lastUpdateMs == null || lastUpdateMs <= 0) {
      return true;
    }

    final DateTime lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
    final DateTime now = DateTime.now();

    // Comparar año, mes, día y hora (ignorando minutos y segundos)
    // Si cualquiera es diferente, debe actualizar
    final bool sameHour = lastUpdate.year == now.year &&
        lastUpdate.month == now.month &&
        lastUpdate.day == now.day &&
        lastUpdate.hour == now.hour;

    return !sameHour;
  }

  void _setupGlobalRatesScheduler() {
    _globalRatesTimer?.cancel();

    // Programar actualizaciones silenciosas cada hora en punto, usando
    // la hora local del dispositivo (por ejemplo 06:00, 07:00, etc.).
    void scheduleNext() {
      final now = DateTime.now();
      final next = DateTime(now.year, now.month, now.day, now.hour + 1);
      final delay = next.difference(now);

      _globalRatesTimer = Timer(delay, () async {
        // Solo actualizar si estamos en modo Cambio Monetario
        if (_selectedMode == 'Cambio Monetario') {
          await _loadRates(showSnackBar: false);
        }
        scheduleNext();
      });
    }

    scheduleNext();
  }

  Future<void> _saveStartupMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStartupModeKey, mode);
  }

  Future<void> _initRatesOnStartup() async {
    try {
      final bool isMonetaryMode = _selectedMode == 'Cambio Monetario';

      setState(() {
        _isLoadingRates = true;
      });

      // Solo mostrar SnackBar de carga si estamos en modo Cambio Monetario
      if (mounted && isMonetaryMode) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colorScheme.onInverseSurface),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Consultando tasas monetarias...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: colorScheme.inverseSurface.withOpacity(0.95),
            behavior: SnackBarBehavior.floating,
            elevation: 4,
            duration: const Duration(seconds: 15),
            margin: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        );
      }

      // Ejecutar el servicio SIEMPRE (independiente del modo)
      await _loadRatesFromPrefs();

      if (!mounted) return;

      await _applyOverridesFromPrefs();

      // Verificar si hay nuevos valores y mostrar toast
      await _checkAndShowNewRatesToast();
    } catch (e) {
      // Manejo de errores: si algo falla, ocultar el loading y continuar
      // ignore: avoid_print
      print('Error initializing rates: $e');
    } finally {
      // Asegurarse de que siempre se oculte el loading
      if (mounted) {
        setState(() {
          _isLoadingRates = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  Future<void> _checkAndShowNewRatesToast() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasNew = prefs.getBool(_kHasNewOfficialRatesKey) ?? false;

    if (!hasNew || !mounted) return;

    // Resetear el flag
    await prefs.setBool(_kHasNewOfficialRatesKey, false);

    // Mostrar toast indicando que hay nuevos valores
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              size: 18,
              color: colorScheme.onInverseSurface,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Hay nuevos valores monetarios disponibles',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.inverseSurface.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 16.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
    );
  }

  Future<void> _initRatesIfMonetaryMode() async {
    if (_selectedMode != 'Cambio Monetario') {
      return;
    }

    try {
      setState(() {
        _isLoadingRates = true;
      });

      // Mostrar un SnackBar de carga no bloqueante mientras se consultan
      // las tasas. Se ocultará al finalizar en _loadRatesFromPrefs/_loadRates.
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colorScheme.onInverseSurface),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Consultando tasas monetarias...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: colorScheme.inverseSurface.withOpacity(0.95),
            behavior: SnackBarBehavior.floating,
            elevation: 4,
            duration: const Duration(seconds: 15),
            margin: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        );
      }

      await _loadRatesFromPrefs();

      if (!mounted) return;

      await _applyOverridesFromPrefs();
    } catch (e) {
      // Manejo de errores: si algo falla, ocultar el loading y continuar
      // ignore: avoid_print
      print('Error initializing rates: $e');
    } finally {
      // Asegurarse de que siempre se oculte el loading
      if (mounted) {
        setState(() {
          _isLoadingRates = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  Future<void> _loadRatesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final double? lastUsd = prefs.getDouble(_kLastOfficialUsdKey);
    final double? lastEur = prefs.getDouble(_kLastOfficialEurKey);
    final double? lastUsdt = prefs.getDouble(_kLastOfficialUsdtKey);

    // Si no hay ningún valor oficial previo guardado, hacer consulta
    // inicial al backend con reintentos para obtenerlos y guardarlos.
    final bool hasAnyStored = (lastUsd != null && lastUsd > 0) ||
        (lastEur != null && lastEur > 0) ||
        (lastUsdt != null && lastUsdt > 0);

    if (!hasAnyStored) {
      // No había montos oficiales guardados: consultar al backend con reintentos
      await _loadRatesWithRetry(maxAttempts: 3);
      return;
    }

    // Verificar si debe actualizar (hora diferente a la última actualización)
    final bool shouldUpdate = await _shouldUpdateRates();

    if (!mounted) return;

    // Cargar valores guardados temporalmente mientras se consulta al backend
    setState(() {
      for (final c in _currencyOptions) {
        if (c.code == 'USD' && lastUsd != null && lastUsd > 0) {
          c.value = lastUsd;
        } else if (c.code == 'Euro' && lastEur != null && lastEur > 0) {
          c.value = lastEur;
        } else if (c.code == 'USDT' && lastUsdt != null && lastUsdt > 0) {
          c.value = lastUsdt;
        }
      }

      // Si no debe actualizar, marcamos como completado
      if (!shouldUpdate) {
        _isLoadingRates = false;
      }
    });

    // Al terminar una carga rápida desde prefs, ocultar el SnackBar de loading
    // en caso de que estuviera visible (solo si no debe actualizar).
    if (mounted && !shouldUpdate) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (shouldUpdate) {
      // La hora es diferente: forzar actualización desde el backend
      // ignore: avoid_print
      print('Hour changed since last update - forcing refresh from backend');
      await _loadRatesWithRetry(maxAttempts: 3, silent: false);
    } else {
      // La hora es la misma: verificar en segundo plano si hay cambios
      _loadRatesWithRetry(maxAttempts: 3, silent: true);
    }
  }

  Future<void> _loadRatesWithRetry({
    int maxAttempts = 3,
    bool silent = false,
  }) async {
    int attempt = 0;
    bool success = false;

    while (attempt < maxAttempts && !success) {
      attempt++;
      // ignore: avoid_print
      print('Attempt $attempt of $maxAttempts to fetch rates...');

      try {
        await _loadRatesInternal(showSnackBar: !silent);
        success = true;
        // ignore: avoid_print
        print('Rates fetched successfully on attempt $attempt');
      } catch (e) {
        // ignore: avoid_print
        print('Attempt $attempt failed: $e');

        if (attempt < maxAttempts) {
          // Esperar un poco antes de reintentar (1 segundo)
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    if (!success) {
      // ignore: avoid_print
      print('Failed to fetch rates after $maxAttempts attempts');

      // Si no se pudo obtener datos y no hay valores guardados,
      // dejar los valores por defecto (1.0)
      if (mounted) {
        setState(() {
          _isLoadingRates = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  Future<void> _loadRates({bool showSnackBar = true}) async {
    await _loadRatesInternal(showSnackBar: showSnackBar);
  }

  Future<void> _loadRatesInternal({required bool showSnackBar}) async {
    final service = RateService();
    final rates = await service.fetchRates();

    // ignore: avoid_print
    print('Rates fetched: USD=${rates.usdVes}, EUR=${rates.eurVes}, USDT=${rates.usdtVes}');

    // Verificar que se obtuvieron valores válidos
    if (rates.usdVes <= 0 && rates.eurVes <= 0 && rates.usdtVes <= 0) {
      throw Exception('No valid rates received from service');
    }

    // Comparar con los últimos valores oficiales guardados para detectar cambios
    final prefs = await SharedPreferences.getInstance();
    final double? lastUsd = prefs.getDouble(_kLastOfficialUsdKey);
    final double? lastEur = prefs.getDouble(_kLastOfficialEurKey);
    final double? lastUsdt = prefs.getDouble(_kLastOfficialUsdtKey);

    bool hasNew = false;
    bool isFirstTime = (lastUsd == null && lastEur == null && lastUsdt == null);

    if (rates.usdVes > 0 && (lastUsd == null || lastUsd != rates.usdVes)) {
      hasNew = true;
    }
    if (rates.eurVes > 0 && (lastEur == null || lastEur != rates.eurVes)) {
      hasNew = true;
    }
    if (rates.usdtVes > 0 && (lastUsdt == null || lastUsdt != rates.usdtVes)) {
      hasNew = true;
    }

    // Solo marcar como "nuevos valores" si NO es la primera vez
    if (hasNew && !isFirstTime) {
      await prefs.setBool(_kHasNewOfficialRatesKey, true);
    }

    // Guardar SIEMPRE los valores oficiales cuando son válidos
    if (rates.usdVes > 0) {
      await prefs.setDouble(_kLastOfficialUsdKey, rates.usdVes);
    }
    if (rates.eurVes > 0) {
      await prefs.setDouble(_kLastOfficialEurKey, rates.eurVes);
    }
    if (rates.usdtVes > 0) {
      await prefs.setDouble(_kLastOfficialUsdtKey, rates.usdtVes);
    }

    // Registrar momento de esta actualización
    if (rates.usdVes > 0 || rates.eurVes > 0 || rates.usdtVes > 0) {
      await prefs.setInt(
        _kLastRatesUpdateTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    // Verificar si el usuario tiene overrides personalizados
    // Un override es "personalizado" si existe y es diferente al valor oficial anterior
    final double? currentOverrideUsd = prefs.getDouble(_kUsdOverrideKey);
    final double? currentOverrideEur = prefs.getDouble(_kEurOverrideKey);
    final double? currentOverrideUsdt = prefs.getDouble(_kUsdtOverrideKey);

    // Verificar si el usuario personalizó algún valor (override diferente al oficial anterior)
    final bool hasCustomUsd = currentOverrideUsd != null &&
        currentOverrideUsd > 0 &&
        lastUsd != null &&
        currentOverrideUsd != lastUsd;
    final bool hasCustomEur = currentOverrideEur != null &&
        currentOverrideEur > 0 &&
        lastEur != null &&
        currentOverrideEur != lastEur;
    final bool hasCustomUsdt = currentOverrideUsdt != null &&
        currentOverrideUsdt > 0 &&
        lastUsdt != null &&
        currentOverrideUsdt != lastUsdt;

    // Si el usuario NO personalizó, actualizar los overrides con los nuevos valores oficiales
    // para que se apliquen inmediatamente en la UI
    if (!hasCustomUsd && rates.usdVes > 0) {
      await prefs.setDouble(_kUsdOverrideKey, rates.usdVes);
    }
    if (!hasCustomEur && rates.eurVes > 0) {
      await prefs.setDouble(_kEurOverrideKey, rates.eurVes);
    }
    if (!hasCustomUsdt && rates.usdtVes > 0) {
      await prefs.setDouble(_kUsdtOverrideKey, rates.usdtVes);
    }

    // Actualizar timestamp de overrides si se actualizó alguno
    if ((!hasCustomUsd && rates.usdVes > 0) ||
        (!hasCustomEur && rates.eurVes > 0) ||
        (!hasCustomUsdt && rates.usdtVes > 0)) {
      await prefs.setInt(
        _kOverridesTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    // SIEMPRE setear los valores en las variables cuando el servicio retorna datos válidos
    if (mounted) {
      setState(() {
        for (final c in _currencyOptions) {
          if (c.code == 'USD' && rates.usdVes > 0) {
            c.value = rates.usdVes;
            // ignore: avoid_print
            print('USD rate set to: ${rates.usdVes}');
          } else if (c.code == 'Euro' && rates.eurVes > 0) {
            c.value = rates.eurVes;
            // ignore: avoid_print
            print('EUR rate set to: ${rates.eurVes}');
          } else if (c.code == 'USDT' && rates.usdtVes > 0) {
            c.value = rates.usdtVes;
            // ignore: avoid_print
            print('USDT rate set to: ${rates.usdtVes}');
          }
        }
      });

      await _applyOverridesFromPrefs();

      // Mostrar confirmación solo cuando hay valores válidos y se pide mostrar SnackBar
      if (showSnackBar && (rates.usdVes > 0 || rates.eurVes > 0 || rates.usdtVes > 0)) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: colorScheme.onInverseSurface,
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Tasas monetarias actualizadas',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: colorScheme.inverseSurface.withOpacity(0.95),
            behavior: SnackBarBehavior.floating,
            elevation: 4,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        );
      }

      // Resetear loading state
      setState(() {
        _isLoadingRates = false;
      });
    }
  }

  Future<void> _applyOverridesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final int? ts = prefs.getInt(_kOverridesTimestampKey);
    if (ts != null) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      const int oneDayMs = 24 * 60 * 60 * 1000;
      if (now - ts > oneDayMs) {
        await prefs.remove(_kUsdOverrideKey);
        await prefs.remove(_kEurOverrideKey);
        await prefs.remove(_kUsdtOverrideKey);
        await prefs.remove(_kOverridesTimestampKey);
        return;
      }
    }

    final double? usd = prefs.getDouble(_kUsdOverrideKey);
    final double? eur = prefs.getDouble(_kEurOverrideKey);
    final double? usdt = prefs.getDouble(_kUsdtOverrideKey);

    if (!mounted) return;

    setState(() {
      for (final c in _currencyOptions) {
        if (c.code == 'USD' && usd != null && usd > 0) {
          c.value = usd;
        } else if (c.code == 'Euro' && eur != null && eur > 0) {
          c.value = eur;
        } else if (c.code == 'USDT' && usdt != null && usdt > 0) {
          c.value = usdt;
        }
      }
    });
  }

  // Se aplican valores personalizados desde SettingsScreen al volver mediante Navigator.pop

  String _expression = '';
  String _result = '';

  String _selectedMode = 'Calculadora';
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

  // Lista única de monedas disponibles (sin "Personalizado"), ordenadas alfabéticamente
  // VES es la moneda base (antes BCV), los demás valores son respecto a VES
  final List<CurrencyOption> _currencyOptions = [
    CurrencyOption(
      code: 'VES',
      label: 'VES',
      description: 'VES es la moneda oficial del Banco Central de Venezuela.',
      value: 1.0,
      icon: Icons.monetization_on,
    ),
    CurrencyOption(
      code: 'USD',
      label: 'BCV',
      description:
          'Este es el valor del Dólar cotizado por la tasa oficial del Banco Central de Venezuela.',
      value: 1.0,
      icon: Icons.attach_money,
    ),
    CurrencyOption(
      code: 'Euro',
      label: 'BCV',
      description:
          'Este es el valor del Euro cotizado por la tasa oficial del Banco Central de Venezuela.',
      value: 1.0,
      icon: Icons.euro,
    ),
    CurrencyOption(
      code: 'USDT',
      label: 'USDT',
      description:
          'Este es el valor promedio de USDT cotizado por Binance y puede variar dependiendo del mercado en que se maneja esta moneda.',
      value: 1.0,
      icon: Icons.currency_bitcoin,
    ),
  ];

  String _getCurrencyLabel(String code) {
    for (final c in _currencyOptions) {
      if (c.code == code) return c.label;
    }
    return code;
  }

  String _getCurrencyDescription(String code) {
    for (final c in _currencyOptions) {
      if (c.code == code) return c.description;
    }
    return '';
  }

  void _showCurrencyInfoDialog(String code) {
    final label = _getCurrencyLabel(code);
    final value = _getCurrencyValue(code);
    final description = _getCurrencyDescription(code);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 220,
              maxWidth: 220,
              minHeight: 220,
              maxHeight: 220,
            ),
            child: Container(
              decoration: BoxDecoration(
                // Fondo blanco fijo para que se vea limpio en claro y oscuro
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 1, // 1/3 de la altura
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      decoration: const BoxDecoration(
                        // Header gris fijo (más claro que el negro anterior)
                        color: Color(0xFF3A3A3F),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12.0),
                          topRight: Radius.circular(12.0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCurrencyIcon(
                            code,
                            size: 26,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2, // 2/3 de la altura
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16.0,
                        16.0,
                        16.0,
                        12.0,
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: Text(
                                '1 $code = ${value.toStringAsFixed(2)} VES',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2B2738),
                                ),
                              ),
                            ),
                          ),
                          if (description.isNotEmpty)
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.3,
                                      color: Color(0xFF2B2738),
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Nota: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: description,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showModeDialog() {
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
                    'Tipo de Calculadora',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            // Seleccionado: píldora morada fija; no seleccionado: píldora clara
                            backgroundColor: _selectedMode == 'Calculadora'
                                ? const Color(0xFF5B3F9A)
                                : Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.25),
                            foregroundColor:
                                _selectedMode == 'Calculadora' ||
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                    ? Colors.white
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                            elevation: 0,
                          ),
                          onPressed: () async {
                            setState(() {
                              _selectedMode = 'Calculadora';
                            });
                            await _saveStartupMode('Calculadora');
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.calculate),
                          label: Text(
                            'Calculadora',
                            style: TextStyle(
                              fontWeight: _selectedMode == 'Calculadora'
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            side: BorderSide(
                              color: _selectedMode == 'Cambio Monetario'
                                  ? Colors.transparent
                                  : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.3),
                            ),
                            backgroundColor: _selectedMode == 'Cambio Monetario'
                                ? const Color(0xFF5B3F9A)
                                : Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.25),
                            foregroundColor:
                                _selectedMode == 'Cambio Monetario' ||
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                    ? Colors.white
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                          ),
                          onPressed: () async {
                            setState(() {
                              _selectedMode = 'Cambio Monetario';
                            });
                            await _saveStartupMode('Cambio Monetario');
                            Navigator.of(context).pop();
                            await _initRatesIfMonetaryMode();
                          },
                          icon: const Icon(Icons.currency_exchange),
                          label: Text(
                            'Cambio Monetario',
                            style: TextStyle(
                              fontWeight: _selectedMode == 'Cambio Monetario'
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openHistory() async {
    final selected = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Velo detrás del sheet: gris oscuro semi-transparente
      barrierColor: const Color(0xFF121212).withOpacity(0.55),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final height = MediaQuery.of(ctx).size.height * 0.8;

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              // Fondo del sheet: un poco más oscuro para que destaquen los ítems.
              // En claro: gris claro fijo; en oscuro: gris muy oscuro.
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF1C1C1F)
                  : const Color(0xFFE3E0EC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24.0),
              ),
            ),
            child: const HistoryScreen(),
          ),
        );
      },
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
          _displayKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/calculator_display.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Calculadora de cambio',
      );
    } catch (_) {
      // Si algo falla al capturar/compartir, simplemente no hace nada.
    }
  }

  bool _isOperator(String buttonText) {
    return buttonText == '+' ||
        buttonText == '−' ||
        buttonText == '×' ||
        buttonText == '÷';
  }

  double _getCurrencyValue(String code) {
    for (final c in _currencyOptions) {
      if (c.code == code) return c.value;
    }
    // Valor por defecto si no se encuentra
    return 1.0;
  }

  double _getConvertedAmount() {
    if (_result.isEmpty) {
      return 0.0;
    }

    final double? baseResult = double.tryParse(_result.replaceAll(',', '.'));
    if (baseResult == null) {
      return 0.0;
    }

    final double fromValue = _getCurrencyValue(_fromExchangeType);
    final double toValue = _getCurrencyValue(_toExchangeType);

    if (fromValue == 0.0 || toValue == 0.0) {
      return 0.0;
    }

    return baseResult * fromValue / toValue;
  }

  IconData _currencyIcon(String code) {
    for (final c in _currencyOptions) {
      if (c.code == code) return c.icon;
    }
    return Icons.monetization_on;
  }

  Widget _buildCurrencyIcon(
    String code, {
    double size = 20,
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final Color effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    if (code == 'VES') {
      return Container(
        width: size + 4,
        height: size + 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: effectiveColor, width: 2),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Bs',
            style: TextStyle(
              color: effectiveColor,
              fontSize: size * 0.45,
              fontWeight: fontWeight,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    return Icon(_currencyIcon(code), size: size, color: effectiveColor);
  }

  void _showSimpleCurrencyDialog({required bool isLeft}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
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
                      'Seleccione tipo de moneda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._currencyOptions.map((CurrencyOption currency) {
                      final String option = currency.code;
                      final bool isSelected = isLeft
                          ? _fromExchangeType == option
                          : _toExchangeType == option;

                      final Color selectedColor = const Color(0xFF5B3F9A);
                      final Color unselectedColor = Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withOpacity(0.6);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16.0),
                          onTap: () {
                            setState(() {
                              if (isLeft) {
                                // Lista izquierda
                                final prevFrom = _fromExchangeType;
                                final prevTo = _toExchangeType;

                                // Si selecciona la misma moneda que está en la derecha,
                                // mover la moneda anterior de la izquierda a la derecha.
                                if (option == _toExchangeType) {
                                  _toExchangeType = prevFrom;
                                }

                                _fromExchangeType = option;
                              } else {
                                // Lista derecha
                                final prevFrom = _fromExchangeType;
                                final prevTo = _toExchangeType;

                                if (option == _fromExchangeType) {
                                  _fromExchangeType = prevTo;
                                }

                                _toExchangeType = option;
                              }
                            });
                            _saveCurrencySelection();
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 10.0,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? selectedColor
                                  : unselectedColor,
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCurrencyIcon(
                                  option,
                                  size: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getCurrencyLabel(option),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
            finalExpression =
                finalExpression.substring(0, finalExpression.length - 1);
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
          if (_result.isNotEmpty && _result != 'Error' && _result != 'División por cero') {
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
    if (value.isEmpty || value == 'Error' || value == 'División por cero') return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              size: 18,
              color: colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        backgroundColor: colorScheme.primary.withOpacity(0.95),
      ),
    );
  }

  String _formatNumberForDisplay(String value) {
    if (value.isEmpty || value == 'Error') return value;

    String v = value.trim();
    bool isNegative = v.startsWith('-');
    if (isNegative) {
      v = v.substring(1);
    }

    // Separar parte entera y decimal usando el punto como separador interno
    String integerPart = v;
    String decimalPart = '';
    final dotIndex = v.indexOf('.');
    if (dotIndex != -1) {
      integerPart = v.substring(0, dotIndex);
      decimalPart = v.substring(dotIndex + 1);
    }

    // Insertar puntos cada 3 dígitos en la parte entera, desde la derecha
    final StringBuffer sb = StringBuffer();
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      sb.write(integerPart[i]);
      count++;
      if (count == 3 && i != 0) {
        sb.write('.');
        count = 0;
      }
    }
    final String formattedInt = sb.toString().split('').reversed.join();

    String result = formattedInt;
    if (decimalPart.isNotEmpty) {
      result += ',$decimalPart';
    }

    if (isNegative) {
      result = '-$result';
    }

    return result;
  }

  String _formatExpressionForDisplay(String expression) {
    if (expression.isEmpty) return '';

    final StringBuffer out = StringBuffer();
    final StringBuffer currentNumber = StringBuffer();

    bool _isNumberChar(String ch) {
      return RegExp(r'[0-9.]').hasMatch(ch);
    }

    void flushNumber() {
      if (currentNumber.isEmpty) return;
      out.write(_formatNumberForDisplay(currentNumber.toString()));
      currentNumber.clear();
    }

    for (int i = 0; i < expression.length; i++) {
      final ch = expression[i];
      if (_isNumberChar(ch)) {
        currentNumber.write(ch);
      } else {
        flushNumber();
        out.write(ch);
      }
    }

    flushNumber();
    return out.toString();
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
              elevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: () {
                final theme = Theme.of(context);
                final cs = theme.colorScheme;

                // Color base según transparencia
                Color base = _isButtonTransparent
                    ? cs.surfaceVariant.withOpacity(0.4)
                    : cs.surfaceVariant;

                final bool isOpButton = buttonText == 'C' ||
                    buttonText == '%' ||
                    buttonText == 'DEL' ||
                    buttonText == '÷' ||
                    buttonText == '×' ||
                    buttonText == '−' ||
                    buttonText == '+';

                // En modo oscuro, hacer más oscuros (y opcionalmente más translúcidos)
                // los botones de control y operadores
                if (theme.brightness == Brightness.dark && isOpButton) {
                  const Color darkOpColor = Color(0xFF3A3348);
                  return _isButtonTransparent
                      ? darkOpColor.withOpacity(0.6)
                      : darkOpColor;
                }

                // En modo claro, hacerlos un poco más oscuros que el resto
                if (theme.brightness == Brightness.light && isOpButton) {
                  // Partir de surfaceVariant y acercarse ligeramente a onSurfaceVariant
                  // para obtener un tono un poco más oscuro.
                  Color lightOpColor =
                      Color.lerp(cs.surfaceVariant, cs.onSurfaceVariant, 0.22)!;

                  if (_isButtonTransparent) {
                    // Base transparente: usar más opacidad que el resto (0.4)
                    // para que se sigan viendo bien.
                    lightOpColor = lightOpColor.withOpacity(0.6);
                  }

                  return lightOpColor;
                }

                return base;
              }(),
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
            _buildButton("%"),
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
                  // Doble de ancho que un botón normal, pero misma altura (2/0.85)
                  aspectRatio: 2 / 0.85,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      backgroundColor: _isButtonTransparent
                          ? const Color(0xFF5B3F9A).withOpacity(0.7)
                          : const Color(0xFF5B3F9A),
                      foregroundColor: Colors.white,
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
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        titleSpacing: 16.0,
        title: Text(
          _selectedMode,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.history),
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  tooltip: 'Historial',
                  onPressed: _openHistory,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  onPressed: _shareCalculatorDisplay,
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surfaceVariant
                          : null,
                    ),
                  ),
                  child: PopupMenuButton<int>(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    icon: const Icon(Icons.more_vert),
                    // Desplazamos el popup hacia abajo usando la altura estándar del AppBar,
                    // y lo acercamos ~6px al AppBar en total
                    offset: const Offset(0, kToolbarHeight - 10),
                    onSelected: (value) async {
                      if (value == 0) {
                        // Tipo de Calculadora
                        _showModeDialog();
                      } else if (value == 1) {
                        // Ajustes
                        Navigator.of(context)
                            .push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation,
                                        secondaryAnimation) =>
                                    SettingsScreen(
                                  initialUsdRate: _getCurrencyValue('USD'),
                                  initialEurRate: _getCurrencyValue('Euro'),
                                  initialUsdtRate: _getCurrencyValue('USDT'),
                                  showMonetarySection:
                                      _selectedMode == 'Cambio Monetario',
                                  themeMode: widget.themeMode,
                                  onThemeModeChanged:
                                      widget.onThemeModeChanged,
                                ),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                              ),
                            )
                            .then((result) async {
                          await _loadPreferences();
                          if (!mounted) return;

                          if (result is Map<String, dynamic>) {
                            final bool restore =
                                (result['restoreRates'] as bool?) ?? false;

                            if (restore) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.remove(_kUsdOverrideKey);
                              await prefs.remove(_kEurOverrideKey);
                              await prefs.remove(_kUsdtOverrideKey);
                              await prefs.remove(_kOverridesTimestampKey);

                              // Solo recargar desde valores guardados, sin llamar a la red
                              await _loadRatesFromPrefs();
                              await _applyOverridesFromPrefs();
                              return;
                            }
                          }

                          await _applyOverridesFromPrefs();
                        });
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<int>(
                        value: 0,
                        child: Row(
                          children: [
                            Icon(Icons.calculate, size: 20),
                            SizedBox(width: 8),
                            Text('Tipo de Calculadora'),
                          ],
                        ),
                      ),
                      PopupMenuItem<int>(
                        value: 1,
                        child: Row(
                          children: [
                            Icon(Icons.settings, size: 20),
                            SizedBox(width: 8),
                            Text('Ajustes'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: _backgroundImagePath != null &&
                  File(_backgroundImagePath!).existsSync()
              ? DecorationImage(
                  image: FileImage(File(_backgroundImagePath!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 12.0 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 16.0),
              Expanded(
                flex: 2,
                child: RepaintBoundary(
                  key: _displayKey,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceVariant,
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
                                  Align(
                                    alignment: Alignment.center,
                                    child: _selectedMode == 'Cambio Monetario'
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        20.0,
                                                      ),
                                                      onTap: () =>
                                                          _showSimpleCurrencyDialog(
                                                        isLeft: true,
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                          horizontal: 12.0,
                                                          vertical: 6.0,
                                                        ),
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize.min,
                                                            children: [
                                                              _buildCurrencyIcon(
                                                                _fromExchangeType,
                                                                size: 20,
                                                                color: Theme.of(
                                                                  context,
                                                                )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Text(
                                                                _getCurrencyLabel(
                                                                  _fromExchangeType,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  color: Theme.of(
                                                                    context,
                                                                  )
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Icon(
                                                                Icons
                                                                    .arrow_drop_down,
                                                                size: 18,
                                                                color: Theme.of(
                                                                  context,
                                                                )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 32),
                                              SizedBox(
                                                width: 40,
                                                height: 32,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      8.0,
                                                    ),
                                                    onTap: _swapExchangeTypes,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.10),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                          8.0,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.compare_arrows,
                                                          size: 18,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 32),
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        20.0,
                                                      ),
                                                      onTap: () =>
                                                          _showSimpleCurrencyDialog(
                                                        isLeft: false,
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                          horizontal: 12.0,
                                                          vertical: 6.0,
                                                        ),
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize.min,
                                                            children: [
                                                              _buildCurrencyIcon(
                                                                _toExchangeType,
                                                                size: 20,
                                                                color: Theme.of(
                                                                  context,
                                                                )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Text(
                                                                _getCurrencyLabel(
                                                                  _toExchangeType,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  color: Theme.of(
                                                                    context,
                                                                  )
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Icon(
                                                                Icons
                                                                    .arrow_drop_down,
                                                                size: 18,
                                                                color: Theme.of(
                                                                  context,
                                                                )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15.0,
                            ),
                            child: _selectedMode == 'Cambio Monetario'
                                ? Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.15),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatExpressionForDisplay(_expression),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                    color: _isExpressionValid()
                                        ? null // Color por defecto del tema
                                        : Colors.orange.withOpacity(0.8), // Color de advertencia
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8.0),
                              onTap: () => _copyToClipboard(
                                _result,
                                'Resultado copiado al portapapeles',
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatNumberForDisplay(_result),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15.0,
                            ),
                            child: _selectedMode == 'Cambio Monetario'
                                ? Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.08),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              alignment: Alignment.center,
                              child: _selectedMode == 'Cambio Monetario'
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton(
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                foregroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                              onPressed: () =>
                                                  _showCurrencyInfoDialog(
                                                _toExchangeType,
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  _buildCurrencyIcon(
                                                    _toExchangeType,
                                                    size: 22,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _getCurrencyLabel(
                                                      _toExchangeType,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            onTap: () => _copyToClipboard(
                                              _getConvertedAmount()
                                                  .toStringAsFixed(2),
                                              'Monto convertido copiado',
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  _formatNumberForDisplay(
                                                    _getConvertedAmount()
                                                        .toStringAsFixed(2),
                                                  ),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
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
    );
  }
}
