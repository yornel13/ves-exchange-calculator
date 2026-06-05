import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ves_exchange_calculator/services/rate_service.dart';

class SettingsScreen extends StatefulWidget {
  final double initialUsdRate;
  final double initialEurRate;
  final double initialUsdtRate;
  final bool showMonetarySection;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.initialUsdRate,
    required this.initialEurRate,
    required this.initialUsdtRate,
    this.showMonetarySection = true,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _backgroundImagePath;
  bool _isButtonTransparent = false;
  late ThemeMode _selectedThemeMode;

  // FocusNode fantasma para quitar foco de los TextField tras ciertas acciones
  final FocusNode _unfocusNode = FocusNode();

  // Últimos montos oficiales conocidos (para comparación en UI)
  double? _officialUsd;
  double? _officialEur;
  double? _officialUsdt;

  static const _kUsdOverrideKey = 'usd_override';
  static const _kEurOverrideKey = 'eur_override';
  static const _kUsdtOverrideKey = 'usdt_override';
  static const _kOverridesTimestampKey = 'ratesOverrideTimestampMs';
  static const _kLastOfficialUsdKey = 'last_official_usd_ves';
  static const _kLastOfficialEurKey = 'last_official_eur_ves';
  static const _kLastOfficialUsdtKey = 'last_official_usdt_ves';
  static const _kLastRatesUpdateTimestampKey = 'lastRatesUpdateTimestampMs';
  static const _kStartupModeKey = 'startupMode';

  final TextEditingController _usdController = TextEditingController();
  final TextEditingController _eurController = TextEditingController();
  final TextEditingController _usdtController = TextEditingController();

  DateTime? _lastRatesUpdate;

  // Control para actualización automática silenciosa cada hora
  Timer? _autoRefreshTimer;
  Duration _timeToNextRefresh = Duration.zero;
  bool _isAutoUpdating = false; // Evitar múltiples actualizaciones simultáneas

  String _startupMode = 'Calculadora';

  @override
  void initState() {
    super.initState();
    _usdController.addListener(_onRateTextChanged);
    _eurController.addListener(_onRateTextChanged);
    _usdtController.addListener(_onRateTextChanged);
    _loadBackgroundImage();
    _loadButtonTransparency();
    _loadMonetaryValues();
    _selectedThemeMode = widget.themeMode;
    _checkForNewOfficialRates();
    _loadStartupMode();

    // Iniciar control de actualización automática de tasas
    _scheduleAutoRefreshTimer();
  }

  void _scheduleAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();

    void tick() {
      if (!mounted) return;
      final current = DateTime.now();

      // Si no hay última actualización registrada, mostrar 00:00:00
      // y esperar a que se cargue desde SharedPreferences
      if (_lastRatesUpdate == null) {
        setState(() {
          _timeToNextRefresh = Duration.zero;
        });
        return;
      }

      // Próxima actualización = última actualización + 1 hora
      final nextUpdate = _lastRatesUpdate!.add(const Duration(hours: 1));
      final diff = nextUpdate.difference(current);

      setState(() {
        _timeToNextRefresh = diff.isNegative ? Duration.zero : diff;
      });

      // Si ya pasó el tiempo (diff <= 0), disparar actualización automática
      if (diff.inSeconds <= 0 && !_isAutoUpdating) {
        _isAutoUpdating = true;
        _performAutoUpdate();
      }
    }

    // Hacer un primer tick inmediato para tener el valor inicial
    tick();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tick();
    });
  }

  Future<void> _performAutoUpdate() async {
    try {
      // Recargar valores y última actualización
      await _loadMonetaryValues();
      await _checkForNewOfficialRates();

      // Si después de cargar aún no hay _lastRatesUpdate o ya pasó 1 hora,
      // consultar tasas oficiales del servidor
      if (_lastRatesUpdate == null ||
          DateTime.now().difference(_lastRatesUpdate!).inMinutes >= 60) {
        await _silentRefreshRates();
      }
    } finally {
      _isAutoUpdating = false;
    }
  }

  Future<void> _silentRefreshRates() async {
    try {
      final service = RateService();
      final rates = await service.fetchRates();
      final prefs = await SharedPreferences.getInstance();

      bool hasChanges = false;

      if (rates.usdVes > 0) {
        await prefs.setDouble(_kLastOfficialUsdKey, rates.usdVes);
        hasChanges = true;
      }
      if (rates.eurVes > 0) {
        await prefs.setDouble(_kLastOfficialEurKey, rates.eurVes);
        hasChanges = true;
      }
      if (rates.usdtVes > 0) {
        await prefs.setDouble(_kLastOfficialUsdtKey, rates.usdtVes);
        hasChanges = true;
      }

      if (hasChanges) {
        // Actualizar timestamp de última actualización
        await prefs.setInt(
          _kLastRatesUpdateTimestampKey,
          DateTime.now().millisecondsSinceEpoch,
        );

        // Marcar que hay nuevas tasas disponibles
        await prefs.setBool('hasNewOfficialRates', true);

        if (mounted) {
          setState(() {
            _lastRatesUpdate = DateTime.now();
            _officialUsd = rates.usdVes > 0 ? rates.usdVes : _officialUsd;
            _officialEur = rates.eurVes > 0 ? rates.eurVes : _officialEur;
            _officialUsdt = rates.usdtVes > 0 ? rates.usdtVes : _officialUsdt;
          });
        }
      }
    } catch (_) {
      // Silenciar errores en actualización automática
    }
  }

  Future<void> _loadStartupMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? mode = prefs.getString(_kStartupModeKey);

    setState(() {
      if (mode == 'Cambio Monetario') {
        _startupMode = 'Cambio Monetario';
      } else {
        _startupMode = 'Calculadora';
      }
    });
  }

  Future<void> _saveStartupMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStartupModeKey, mode);
    setState(() {
      _startupMode = mode;
    });
  }

  Future<void> _loadBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundImagePath = prefs.getString('backgroundImage');
    });
  }

  Future<void> _saveBackgroundImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backgroundImage', path);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      await _saveBackgroundImage(pickedFile.path);
      _loadBackgroundImage();
    }
  }

  Future<void> _removeBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('backgroundImage');
    _loadBackgroundImage();
  }

  Future<void> _loadButtonTransparency() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isButtonTransparent = prefs.getBool('buttonTransparency') ?? false;
    });
  }

  Future<void> _saveButtonTransparency(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('buttonTransparency', value);
    setState(() {
      _isButtonTransparent = value;
    });
  }

  void _onRateTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool _allFieldsMatchOfficial() {
    // Si aún no tenemos montos oficiales cargados, consideramos que no coinciden
    if (_officialUsd == null || _officialEur == null || _officialUsdt == null) {
      return false;
    }

    String _normalized(TextEditingController c) =>
        c.text.trim().replaceAll(',', '.');

    final usdText = _normalized(_usdController);
    final eurText = _normalized(_eurController);
    final usdtText = _normalized(_usdtController);

    final usdOfficial = _officialUsd!.toStringAsFixed(2);
    final eurOfficial = _officialEur!.toStringAsFixed(2);
    final usdtOfficial = _officialUsdt!.toStringAsFixed(2);

    return usdText == usdOfficial &&
        eurText == eurOfficial &&
        usdtText == usdtOfficial;
  }

  // Siempre parte de los valores que recibe desde CalculatorScreen,
  // pero también sincroniza los últimos montos oficiales guardados.
  Future<void> _loadMonetaryValues() async {
    final prefs = await SharedPreferences.getInstance();

    // Valores oficiales base (última consulta conocida si existe).
    // Si aún no hay consulta oficial, usamos los initial* solo para mostrar
    // algo en la UI, pero **no** los escribimos como "última consulta" en prefs.
    final double? storedOfficialUsd =
        prefs.getDouble(_kLastOfficialUsdKey);
    final double? storedOfficialEur =
        prefs.getDouble(_kLastOfficialEurKey);
    final double? storedOfficialUsdt =
        prefs.getDouble(_kLastOfficialUsdtKey);

    final double officialUsd =
        storedOfficialUsd ?? widget.initialUsdRate;
    final double officialEur =
        storedOfficialEur ?? widget.initialEurRate;
    final double officialUsdt =
        storedOfficialUsdt ?? widget.initialUsdtRate;

    // Overrides guardados (si existen)
    final double? overrideUsd = prefs.getDouble(_kUsdOverrideKey);
    final double? overrideEur = prefs.getDouble(_kEurOverrideKey);
    final double? overrideUsdt = prefs.getDouble(_kUsdtOverrideKey);

    // Leer timestamp de última actualización de montos oficiales (si existe)
    final int? lastUpdateMs =
        prefs.getInt(_kLastRatesUpdateTimestampKey);

    if (!mounted) return;

    setState(() {
      // Siempre mantener los oficiales para comparaciones de botones
      _officialUsd = officialUsd;
      _officialEur = officialEur;
      _officialUsdt = officialUsdt;

      // Guardar última actualización si había timestamp
      if (lastUpdateMs != null && lastUpdateMs > 0) {
        _lastRatesUpdate =
            DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
      } else {
        _lastRatesUpdate = null;
      }

      // Mostrar overrides si existen y son válidos; si no, los oficiales
      final double usdToShow =
          (overrideUsd != null && overrideUsd > 0) ? overrideUsd : officialUsd;
      final double eurToShow =
          (overrideEur != null && overrideEur > 0) ? overrideEur : officialEur;
      final double usdtToShow = (overrideUsdt != null && overrideUsdt > 0)
          ? overrideUsdt
          : officialUsdt;

      _usdController.text = usdToShow.toStringAsFixed(2);
      _eurController.text = eurToShow.toStringAsFixed(2);
      _usdtController.text = usdtToShow.toStringAsFixed(2);
    });
  }

  Future<void> _checkForNewOfficialRates() async {
    final prefs = await SharedPreferences.getInstance();
    final hasNew = prefs.getBool('hasNewOfficialRates') ?? false;
    if (!hasNew || !mounted) return;

    // Actualizar flag y recargar montos oficiales y última actualización
    await prefs.setBool('hasNewOfficialRates', false);

    final double? usd = prefs.getDouble(_kLastOfficialUsdKey);
    final double? eur = prefs.getDouble(_kLastOfficialEurKey);
    final double? usdt = prefs.getDouble(_kLastOfficialUsdtKey);
    final int? lastUpdateMs =
        prefs.getInt(_kLastRatesUpdateTimestampKey);

    // Leer overrides actuales para verificar si el usuario personalizó
    final double? overrideUsd = prefs.getDouble(_kUsdOverrideKey);
    final double? overrideEur = prefs.getDouble(_kEurOverrideKey);
    final double? overrideUsdt = prefs.getDouble(_kUsdtOverrideKey);

    // Verificar si el usuario personalizó (override diferente al oficial anterior)
    final bool hasCustomUsd = overrideUsd != null &&
        overrideUsd > 0 &&
        _officialUsd != null &&
        overrideUsd != _officialUsd;
    final bool hasCustomEur = overrideEur != null &&
        overrideEur > 0 &&
        _officialEur != null &&
        overrideEur != _officialEur;
    final bool hasCustomUsdt = overrideUsdt != null &&
        overrideUsdt > 0 &&
        _officialUsdt != null &&
        overrideUsdt != _officialUsdt;

    setState(() {
      // Actualizar montos oficiales en memoria
      _officialUsd = usd ?? _officialUsd;
      _officialEur = eur ?? _officialEur;
      _officialUsdt = usdt ?? _officialUsdt;

      // Actualizar fecha de última actualización si existe
      if (lastUpdateMs != null && lastUpdateMs > 0) {
        _lastRatesUpdate =
            DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
      }

      // Actualizar TextFields solo si no hay valores personalizados
      if (!hasCustomUsd && usd != null && usd > 0) {
        _usdController.text = usd.toStringAsFixed(2);
      }
      if (!hasCustomEur && eur != null && eur > 0) {
        _eurController.text = eur.toStringAsFixed(2);
      }
      if (!hasCustomUsdt && usdt != null && usdt > 0) {
        _usdtController.text = usdt.toStringAsFixed(2);
      }
    });
  }

  Future<void> _saveSingleRate({
    required TextEditingController controller,
    required String overrideKey,
    required String currencyLabel,
  }) async {
    final String text = controller.text.trim();
    final double? value = double.tryParse(text.replaceAll(',', '.'));

    final bool invalid = text.isEmpty || value == null || value <= 0;

    final colorScheme = Theme.of(context).colorScheme;

    if (invalid) {
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
              Flexible(
                child: Text(
                  'Introduce un valor numérico mayor que 0 para $currencyLabel.',
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
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(overrideKey, value);
    await prefs.setInt(
      _kOverridesTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    FocusScope.of(context).unfocus();

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
            Flexible(
              child: Text(
                'Valor de $currencyLabel guardado.',
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

  Future<void> _restoreOfficialRates() async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUsdOverrideKey);
      await prefs.remove(_kEurOverrideKey);
      await prefs.remove(_kUsdtOverrideKey);
      await prefs.remove(_kOverridesTimestampKey);

      // Leer los últimos valores oficiales guardados previamente en prefs
      final double? lastUsd = prefs.getDouble(_kLastOfficialUsdKey);
      final double? lastEur = prefs.getDouble(_kLastOfficialEurKey);
      final double? lastUsdt = prefs.getDouble(_kLastOfficialUsdtKey);

      if (!mounted) return;

      setState(() {
        if (lastUsd != null && lastUsd > 0) {
          _usdController.text = lastUsd.toStringAsFixed(2);
        }
        if (lastEur != null && lastEur > 0) {
          _eurController.text = lastEur.toStringAsFixed(2);
        }
        if (lastUsdt != null && lastUsdt > 0) {
          _usdtController.text = lastUsdt.toStringAsFixed(2);
        }
      });

      // Quitar foco de los TextField y moverlo al nodo neutro
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_unfocusNode);
      });

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
                  'Valores oficiales reestablecidos.',
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudieron actualizar los valores.'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _consultOfficialRates() async {
    final colorScheme = Theme.of(context).colorScheme;

    // Mostrar un pequeño loading mientras se consulta al backend
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final service = RateService();
      final rates = await service.fetchRates();

      final prefs = await SharedPreferences.getInstance();

      final double? lastUsd = prefs.getDouble(_kLastOfficialUsdKey);
      final double? lastEur = prefs.getDouble(_kLastOfficialEurKey);
      final double? lastUsdt = prefs.getDouble(_kLastOfficialUsdtKey);

      // Leer overrides actuales para verificar si el usuario personalizó
      final double? currentOverrideUsd = prefs.getDouble(_kUsdOverrideKey);
      final double? currentOverrideEur = prefs.getDouble(_kEurOverrideKey);
      final double? currentOverrideUsdt = prefs.getDouble(_kUsdtOverrideKey);

      // Verificar si el usuario personalizó (override diferente al oficial anterior)
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

      bool hasChanges = false;

      if (rates.usdVes > 0 && (lastUsd == null || lastUsd != rates.usdVes)) {
        await prefs.setDouble(_kLastOfficialUsdKey, rates.usdVes);
        hasChanges = true;
      }
      if (rates.eurVes > 0 && (lastEur == null || lastEur != rates.eurVes)) {
        await prefs.setDouble(_kLastOfficialEurKey, rates.eurVes);
        hasChanges = true;
      }
      if (rates.usdtVes > 0 && (lastUsdt == null || lastUsdt != rates.usdtVes)) {
        await prefs.setDouble(_kLastOfficialUsdtKey, rates.usdtVes);
        hasChanges = true;
      }

      // Si el usuario NO personalizó, actualizar overrides y TextFields
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

      // Registrar momento de esta actualización de montos oficiales
      await prefs.setInt(
        _kLastRatesUpdateTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (!mounted) return;

      setState(() {
        _officialUsd = rates.usdVes > 0 ? rates.usdVes : _officialUsd;
        _officialEur = rates.eurVes > 0 ? rates.eurVes : _officialEur;
        _officialUsdt = rates.usdtVes > 0 ? rates.usdtVes : _officialUsdt;
        _lastRatesUpdate = DateTime.now();

        // Actualizar TextFields solo si no hay valores personalizados
        if (!hasCustomUsd && rates.usdVes > 0) {
          _usdController.text = rates.usdVes.toStringAsFixed(2);
        }
        if (!hasCustomEur && rates.eurVes > 0) {
          _eurController.text = rates.eurVes.toStringAsFixed(2);
        }
        if (!hasCustomUsdt && rates.usdtVes > 0) {
          _usdtController.text = rates.usdtVes.toStringAsFixed(2);
        }
      });

      // Determinar mensaje según si hubo cambios y si se aplicaron
      final bool anyAutoUpdated = (!hasCustomUsd && rates.usdVes > 0) ||
          (!hasCustomEur && rates.eurVes > 0) ||
          (!hasCustomUsdt && rates.usdtVes > 0);
      final bool anyCustom = hasCustomUsd || hasCustomEur || hasCustomUsdt;

      String message;
      if (hasChanges && anyCustom && !anyAutoUpdated) {
        message = 'Hay nuevos valores monetarios disponibles';
      } else if (hasChanges && anyAutoUpdated) {
        message = 'Valores monetarios actualizados.';
      } else {
        message = 'Valores monetarios actualizados.';
      }

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
              Flexible(
                child: Text(
                  message,
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
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo consultar los montos oficiales.'),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _restoreSingleToOfficial({
    required TextEditingController controller,
    required double? officialValue,
    required String overrideKey,
    required String currencyLabel,
  }) async {
    if (officialValue == null || officialValue <= 0) return;

    final prefs = await SharedPreferences.getInstance();

    setState(() {
      controller.text = officialValue.toStringAsFixed(2);
    });

    await prefs.setDouble(overrideKey, officialValue);
    await prefs.setInt(
      _kOverridesTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    FocusScope.of(context).unfocus();

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
            Flexible(
              child: Text(
                'Valor de la moneda $currencyLabel ha sido restablecido a su valor oficial.',
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

  Future<void> _saveAllRates() async {
    final colorScheme = Theme.of(context).colorScheme;

    double? _parseValue(TextEditingController c) {
      final text = c.text.trim();
      if (text.isEmpty) return null;
      final v = double.tryParse(text.replaceAll(',', '.'));
      if (v == null || v <= 0) return null;
      return v;
    }

    final usd = _parseValue(_usdController);
    final eur = _parseValue(_eurController);
    final usdt = _parseValue(_usdtController);

    if (usd == null || eur == null || usdt == null) {
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
                  'Introduce valores numéricos mayores que 0 en todos los campos.',
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
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kUsdOverrideKey, usd);
    await prefs.setDouble(_kEurOverrideKey, eur);
    await prefs.setDouble(_kUsdtOverrideKey, usdt);
    await prefs.setInt(
      _kOverridesTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    FocusScope.of(context).unfocus();

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
                'Cambios guardados.',
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

  @override
  void dispose() {
    _usdController.dispose();
    _eurController.dispose();
    _usdtController.dispose();
    _unfocusNode.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Input formatter para máximo 2 decimales
  final List<TextInputFormatter> _twoDecimalInputFormatters =
  <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'^\d*(\.\d{0,2})?')),
  ];

  Widget _buildThemePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    Color background =
    isSelected ? colorScheme.primary : colorScheme.surfaceVariant;
    Color borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withOpacity(0.12);
    Color textColor =
    isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    // Ajuste específico: en modo oscuro, cuando ciertas opciones están
    // seleccionadas, usar un morado más intenso con texto blanco.
    if (brightness == Brightness.dark &&
        isSelected &&
        (label == 'Oscuro' ||
            label == 'Calculadora' ||
            label == 'Cambio monetario')) {
      background = const Color(0xFF5B3F9A); // morado oscuro
      borderColor = background;
      textColor = Colors.white;
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 8.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuraciones Generales'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: 24.0 + MediaQuery.of(context).viewPadding.bottom,
        ),
        children: [
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: Text(
                      'Configuración de inicio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
                    child: Text(
                      'Tipo de Calculadora',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildThemePill(
                            label: 'Calculadora',
                            isSelected: _startupMode == 'Calculadora',
                            onTap: () => _saveStartupMode('Calculadora'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildThemePill(
                            label: 'Cambio monetario',
                            isSelected: _startupMode == 'Cambio Monetario',
                            onTap: () => _saveStartupMode('Cambio Monetario'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: Text(
                      'Apariencia',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Establecer imagen de fondo'),
                    leading: const Icon(Icons.image),
                    onTap: _pickImage,
                  ),
                  ListTile(
                    title: const Text('Quitar imagen de fondo'),
                    leading: const Icon(Icons.hide_image),
                    enabled: _backgroundImagePath != null,
                    onTap:
                    _backgroundImagePath != null ? _removeBackgroundImage : null,
                  ),
                  const Divider(),
                  ListTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedThemeMode == ThemeMode.light
                                  ? Icons.wb_sunny
                                  : _selectedThemeMode == ThemeMode.dark
                                  ? Icons.dark_mode
                                  : Icons.brightness_6,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Seleccionar tema',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildThemePill(
                                label: 'Claro',
                                isSelected:
                                _selectedThemeMode == ThemeMode.light,
                                onTap: () {
                                  setState(() {
                                    _selectedThemeMode = ThemeMode.light;
                                  });
                                  widget.onThemeModeChanged(ThemeMode.light);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildThemePill(
                                label: 'Oscuro',
                                isSelected:
                                _selectedThemeMode == ThemeMode.dark,
                                onTap: () {
                                  setState(() {
                                    _selectedThemeMode = ThemeMode.dark;
                                  });
                                  widget.onThemeModeChanged(ThemeMode.dark);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildThemePill(
                                label: 'Automático',
                                isSelected:
                                _selectedThemeMode == ThemeMode.system,
                                onTap: () {
                                  setState(() {
                                    _selectedThemeMode = ThemeMode.system;
                                  });
                                  widget.onThemeModeChanged(ThemeMode.system);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Transparencia en botones'),
                    value: _isButtonTransparent,
                    onChanged: _saveButtonTransparency,
                    secondary: const Icon(Icons.opacity),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            if (widget.showMonetarySection)
              Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Padding(
                  padding:
                  const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Personalizar Montos (VES)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 48,
                            width: 48,
                            child: Builder(
                              builder: (context) {
                                final scheme =
                                    Theme.of(context).colorScheme;
                                final isDark =
                                    Theme.of(context).brightness ==
                                        Brightness.dark;
                                final Color bg = isDark
                                    ? scheme.primaryContainer
                                    : scheme.primary;
                                final Color iconColor = isDark
                                    ? scheme.onPrimaryContainer
                                    : scheme.onPrimary;

                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: bg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10.0),
                                    ),
                                  ),
                                  onPressed: _allFieldsMatchOfficial()
                                      ? null
                                      : _restoreOfficialRates,
                                  child: Icon(
                                    Icons.autorenew_rounded,
                                    size: 24,
                                    color: iconColor,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      // USD a VES
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'USD a VES',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(Oficial: ${_officialUsd?.toStringAsFixed(2) ?? '--'} Bs)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _usdController,
                                  keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: _twoDecimalInputFormatters,
                                  decoration: const InputDecoration(
                                    labelText: 'Personalizado',
                                    prefixText: 'USD: ',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              SizedBox(
                                height: 48,
                                width: 48,
                                child: Builder(
                                  builder: (context) {
                                    final scheme =
                                        Theme.of(context).colorScheme;
                                    final isDark =
                                        Theme.of(context).brightness ==
                                            Brightness.dark;
                                    final Color bg = isDark
                                        ? scheme.primaryContainer
                                        : scheme.primary;
                                    final Color iconColor = isDark
                                        ? scheme.onPrimaryContainer
                                        : scheme.onPrimary;

                                    bool isSameAsOfficial = false;
                                    if (_officialUsd != null) {
                                      final currentText =
                                      _usdController.text
                                          .trim()
                                          .replaceAll(',', '.');
                                      final officialText =
                                      _officialUsd!.toStringAsFixed(2);
                                      isSameAsOfficial =
                                          currentText == officialText;
                                    }

                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        backgroundColor: bg,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(10.0),
                                        ),
                                      ),
                                      onPressed:
                                      isSameAsOfficial || _officialUsd == null
                                          ? null
                                          : () {
                                        _restoreSingleToOfficial(
                                          controller: _usdController,
                                          officialValue: _officialUsd,
                                          overrideKey: _kUsdOverrideKey,
                                          currencyLabel: 'USD',
                                        );
                                      },
                                      child: Icon(
                                        Icons.refresh_rounded,
                                        size: 28,
                                        color: iconColor,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      // EUR a VES
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'EUR a VES',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(Oficial: ${_officialEur?.toStringAsFixed(2) ?? '--'} Bs)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _eurController,
                                  keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: _twoDecimalInputFormatters,
                                  decoration: const InputDecoration(
                                    labelText: 'Personalizado',
                                    prefixText: 'EUR: ',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              SizedBox(
                                height: 48,
                                width: 48,
                                child: Builder(
                                  builder: (context) {
                                    final scheme =
                                        Theme.of(context).colorScheme;
                                    final isDark =
                                        Theme.of(context).brightness ==
                                            Brightness.dark;
                                    final Color bg = isDark
                                        ? scheme.primaryContainer
                                        : scheme.primary;
                                    final Color iconColor = isDark
                                        ? scheme.onPrimaryContainer
                                        : scheme.onPrimary;

                                    bool isSameAsOfficial = false;
                                    if (_officialEur != null) {
                                      final currentText =
                                      _eurController.text
                                          .trim()
                                          .replaceAll(',', '.');
                                      final officialText =
                                      _officialEur!.toStringAsFixed(2);
                                      isSameAsOfficial =
                                          currentText == officialText;
                                    }

                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        backgroundColor: bg,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(10.0),
                                        ),
                                      ),
                                      onPressed:
                                      isSameAsOfficial || _officialEur == null
                                          ? null
                                          : () {
                                        _restoreSingleToOfficial(
                                          controller: _eurController,
                                          officialValue: _officialEur,
                                          overrideKey: _kEurOverrideKey,
                                          currencyLabel: 'EUR',
                                        );
                                      },
                                      child: Icon(
                                        Icons.refresh_rounded,
                                        size: 28,
                                        color: iconColor,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      // USDT a VES
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'USDT a VES',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${_officialUsdt?.toStringAsFixed(2) ?? '--'} Bs)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _usdtController,
                                  keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: _twoDecimalInputFormatters,
                                  decoration: const InputDecoration(
                                    labelText: 'Personalizado',
                                    prefixText: 'USDT: ',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              SizedBox(
                                height: 48,
                                width: 48,
                                child: Builder(
                                  builder: (context) {
                                    final scheme =
                                        Theme.of(context).colorScheme;
                                    final isDark =
                                        Theme.of(context).brightness ==
                                            Brightness.dark;
                                    final Color bg = isDark
                                        ? scheme.primaryContainer
                                        : scheme.primary;
                                    final Color iconColor = isDark
                                        ? scheme.onPrimaryContainer
                                        : scheme.onPrimary;

                                    bool isSameAsOfficial = false;
                                    if (_officialUsdt != null) {
                                      final currentText = _usdtController.text
                                          .trim()
                                          .replaceAll(',', '.');
                                      final officialText =
                                      _officialUsdt!.toStringAsFixed(2);
                                      isSameAsOfficial =
                                          currentText == officialText;
                                    }

                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        backgroundColor: bg,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(10.0),
                                        ),
                                      ),
                                      onPressed:
                                      isSameAsOfficial || _officialUsdt == null
                                          ? null
                                          : () {
                                        _restoreSingleToOfficial(
                                          controller: _usdtController,
                                          officialValue: _officialUsdt,
                                          overrideKey: _kUsdtOverrideKey,
                                          currencyLabel: 'USDT',
                                        );
                                      },
                                      child: Icon(
                                        Icons.refresh_rounded,
                                        size: 28,
                                        color: iconColor,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _saveAllRates,
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          child: const Text('Guardar cambios'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.showMonetarySection)
              const SizedBox(height: 12.0),
            if (widget.showMonetarySection)
              Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Última actualización',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _consultOfficialRates,
                            icon: const Icon(Icons.sync),
                            tooltip: 'Consultar montos oficiales',
                          ),
                        ],
                      ),
                      Text(
                        _lastRatesUpdate != null
                            ? '${_lastRatesUpdate!.day.toString().padLeft(2, '0')}/${_lastRatesUpdate!.month.toString().padLeft(2, '0')}/${_lastRatesUpdate!.year} ${_lastRatesUpdate!.hour.toString().padLeft(2, '0')}:${_lastRatesUpdate!.minute.toString().padLeft(2, '0')}'
                            : 'No hay registros',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_lastRatesUpdate != null)
                        const SizedBox(height: 4.0),
                      if (_lastRatesUpdate != null)
                        Text(
                          () {
                            final totalSeconds = _timeToNextRefresh.inSeconds;
                            if (totalSeconds <= 0) {
                              return 'Próxima actualización en 00:00:00';
                            }

                            final hours = (totalSeconds ~/ 3600)
                                .toString()
                                .padLeft(2, '0');
                            final minutes =
                                ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
                            final seconds = (totalSeconds % 60)
                                .toString()
                                .padLeft(2, '0');
                            return 'Próxima actualización en $hours:$minutes:$seconds';
                          }(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
    );
  }
}