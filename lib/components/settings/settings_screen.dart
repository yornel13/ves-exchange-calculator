import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ves_exchange_calculator/components/calculator/calculator_dialogs.dart';
import 'package:ves_exchange_calculator/components/calculator/rates_strip.dart';
import 'package:ves_exchange_calculator/components/settings/custom_rates_section.dart';
import 'package:ves_exchange_calculator/components/settings/rates_status_section.dart';
import 'package:ves_exchange_calculator/components/settings/segmented_pills.dart';
import 'package:ves_exchange_calculator/components/settings/settings_section.dart';
import 'package:ves_exchange_calculator/services/rates_controller.dart';
import 'package:ves_exchange_calculator/services/store_launcher.dart';
import 'package:ves_exchange_calculator/utils/app_links.dart';
import 'package:ves_exchange_calculator/theme/app_typography.dart';
import 'package:ves_exchange_calculator/theme/glass_tokens.dart';
import 'package:ves_exchange_calculator/widgets/app_toast.dart';
import 'package:ves_exchange_calculator/widgets/background_layer.dart';

/// App settings.
///
/// Takes the calculator's [RatesController] instead of raw rate values: the old
/// version re-implemented the fetch, the override bookkeeping and the hourly
/// refresh on its own, so the two screens could disagree about the same numbers.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.rates,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.showMonetarySection = true,
  });

  final RatesController rates;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool showMonetarySection;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _kStartupModeKey = 'startupMode';
  static const String _kBackgroundImageKey = 'backgroundImage';
  static const String _kButtonTransparencyKey = 'buttonTransparency';

  String? _backgroundImagePath;
  bool _isButtonTransparent = false;
  late ThemeMode _selectedThemeMode = widget.themeMode;
  String _startupMode = kDefaultMode;
  RatesStripStyle _ratesStripStyle = RatesStripStyle.labeled;

  /// Read from the platform bundle, not from a constant: a hardcoded string
  /// silently lies the first time someone bumps the version in pubspec.
  String? _appVersion;

  late final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
    for (final String code in RatesController.customisableCodes)
      code: TextEditingController(),
  };

  /// Ticks the "next refresh" countdown.
  Timer? _countdownTimer;
  Duration _timeToNextRefresh = Duration.zero;

  /// Last fetch we already mirrored into the text fields.
  DateTime? _syncedStamp;

  @override
  void initState() {
    super.initState();

    widget.rates.addListener(_onRatesChanged);
    for (final TextEditingController c in _controllers.values) {
      c.addListener(_onFieldChanged);
    }

    _syncedStamp = widget.rates.lastUpdate;
    _syncFieldsFromController();
    _loadPreferences();
    _loadAppVersion();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    widget.rates.removeListener(_onRatesChanged);
    for (final TextEditingController c in _controllers.values) {
      c
        ..removeListener(_onFieldChanged)
        ..dispose();
    }
    super.dispose();
  }

  /// The restore buttons enable and disable as the text changes.
  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _onRatesChanged() {
    if (!mounted) return;

    final DateTime? stamp = widget.rates.lastUpdate;
    final bool fetched = stamp != null && stamp != _syncedStamp;

    setState(() {
      if (fetched) {
        _syncedStamp = stamp;
        // Mirror what the app is actually using. The controller already keeps
        // the user's custom rates, so this never clobbers them.
        _syncFieldsFromController();
      }
    });
  }

  /// Fields show the Venezuelan decimal comma; [_parse] accepts either.
  static String _forField(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  void _syncFieldsFromController() {
    for (final MapEntry<String, TextEditingController> entry
        in _controllers.entries) {
      entry.value.text = _forField(widget.rates.valueOf(entry.key));
    }
  }

  Future<void> _loadPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _backgroundImagePath = prefs.getString(_kBackgroundImageKey);
      _isButtonTransparent = prefs.getBool(_kButtonTransparencyKey) ?? false;
      _startupMode = modeFromStorage(prefs.getString(_kStartupModeKey));
      _ratesStripStyle = RatesStripStyle.fromStorage(
        prefs.getString(RatesStripStyle.prefsKey),
      );
    });
  }

  Future<void> _loadAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = '${info.version} (${info.buildNumber})');
  }

  Future<void> _saveRatesStripStyle(RatesStripStyle style) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(RatesStripStyle.prefsKey, style.storageKey);
    if (!mounted) return;
    setState(() => _ratesStripStyle = style);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    void tick() {
      if (!mounted) return;

      final DateTime? last = widget.rates.lastUpdate;
      if (last == null) {
        setState(() => _timeToNextRefresh = Duration.zero);
        return;
      }

      final Duration remaining =
          last.add(const Duration(hours: 1)).difference(DateTime.now());
      setState(() {
        _timeToNextRefresh = remaining.isNegative ? Duration.zero : remaining;
      });
    }

    tick();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _saveStartupMode(String mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStartupModeKey, mode);
    if (!mounted) return;
    setState(() => _startupMode = mode);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _selectedThemeMode = mode);
    widget.onThemeModeChanged(mode);
  }

  Future<void> _pickBackgroundImage() async {
    final XFile? picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackgroundImageKey, picked.path);
    if (!mounted) return;

    setState(() => _backgroundImagePath = picked.path);
    AppToast.show(context, 'Fondo actualizado');
  }

  Future<void> _removeBackgroundImage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBackgroundImageKey);
    if (!mounted) return;

    setState(() => _backgroundImagePath = null);
    AppToast.show(context, 'Fondo quitado');
  }

  Future<void> _setButtonTransparency(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kButtonTransparencyKey, value);
    if (!mounted) return;
    setState(() => _isButtonTransparent = value);
  }

  double? _parse(String text) {
    final double? value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _saveAllRates() async {
    final Map<String, double> parsed = <String, double>{};

    for (final MapEntry<String, TextEditingController> entry
        in _controllers.entries) {
      final double? value = _parse(entry.value.text);
      if (value == null) {
        AppToast.show(
          context,
          'Escribe un monto mayor que 0 en ${entry.key}',
          icon: Icons.error_outline_rounded,
        );
        return;
      }
      parsed[entry.key] = value;
    }

    await widget.rates.saveOverrides(parsed);
    if (!mounted) return;

    FocusScope.of(context).unfocus();
    AppToast.show(context, 'Montos guardados');
  }

  Future<void> _restoreOne(String code) async {
    await widget.rates.restoreOfficial(code);
    if (!mounted) return;

    setState(() {
      _controllers[code]?.text = _forField(widget.rates.valueOf(code));
    });

    FocusScope.of(context).unfocus();
    AppToast.show(context, '$code volvió a su valor oficial');
  }

  Future<void> _restoreAll() async {
    await widget.rates.clearOverrides();
    if (!mounted) return;

    setState(_syncFieldsFromController);
    FocusScope.of(context).unfocus();
    AppToast.show(context, 'Montos oficiales restablecidos');
  }

  Future<void> _rateApp() async {
    final bool opened = await StoreLauncher.openReview();
    if (opened || !mounted) return;

    AppToast.show(
      context,
      'No se pudo abrir la tienda',
      icon: Icons.error_outline_rounded,
    );
  }

  Future<void> _refreshRates() async {
    try {
      await widget.rates.refresh(announce: false);
      if (!mounted) return;
      AppToast.show(context, 'Tasas actualizadas');
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        'No se pudo consultar las tasas',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Scaffold(
      body: BackgroundLayer(
        imagePath: _backgroundImagePath,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _Header(title: 'Ajustes'),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 8.0,
                    bottom: 24.0 + MediaQuery.of(context).viewPadding.bottom,
                  ),
                  children: <Widget>[
                    SettingsSection(
                      title: 'Al abrir la app',
                      children: <Widget>[
                        SegmentedPills<String>(
                          options: const <PillOption<String>>[
                            PillOption<String>(
                              value: kModeCalculator,
                              label: 'Calculadora',
                            ),
                            PillOption<String>(
                              value: kModeExchange,
                              label: 'Cambio monetario',
                            ),
                          ],
                          selected: _startupMode,
                          onChanged: _saveStartupMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SettingsSection(
                      title: 'Apariencia',
                      children: <Widget>[
                        SegmentedPills<ThemeMode>(
                          options: const <PillOption<ThemeMode>>[
                            PillOption<ThemeMode>(
                              value: ThemeMode.light,
                              label: 'Claro',
                            ),
                            PillOption<ThemeMode>(
                              value: ThemeMode.dark,
                              label: 'Oscuro',
                            ),
                            PillOption<ThemeMode>(
                              value: ThemeMode.system,
                              label: 'Automático',
                            ),
                          ],
                          selected: _selectedThemeMode,
                          onChanged: _setThemeMode,
                        ),
                        const SizedBox(height: 6),
                        const SettingsDivider(),
                        SettingsRow(
                          icon: Icons.image_outlined,
                          label: 'Imagen de fondo',
                          subtitle: _backgroundImagePath == null
                              ? 'Usando el fondo de la app'
                              : 'Imagen propia activa',
                          onTap: _pickBackgroundImage,
                        ),
                        if (_backgroundImagePath != null) ...<Widget>[
                          const SettingsDivider(),
                          SettingsRow(
                            icon: Icons.hide_image_outlined,
                            label: 'Quitar imagen de fondo',
                            onTap: _removeBackgroundImage,
                          ),
                        ],
                        const SettingsDivider(),
                        SettingsRow(
                          icon: Icons.opacity_rounded,
                          label: 'Teclas más translúcidas',
                          trailing: Switch(
                            value: _isButtonTransparent,
                            onChanged: _setButtonTransparency,
                            activeThumbColor: glass.accent,
                          ),
                        ),
                      ],
                    ),
                    if (widget.showMonetarySection) ...<Widget>[
                      const SizedBox(height: 14),
                      SettingsSection(
                        title: 'Tasas en el encabezado',
                        children: <Widget>[
                          SegmentedPills<RatesStripStyle>(
                            options: const <PillOption<RatesStripStyle>>[
                              PillOption<RatesStripStyle>(
                                value: RatesStripStyle.labeled,
                                label: 'Con nombre',
                              ),
                              PillOption<RatesStripStyle>(
                                value: RatesStripStyle.compact,
                                label: 'Compacto',
                              ),
                            ],
                            selected: _ratesStripStyle,
                            onChanged: _saveRatesStripStyle,
                          ),
                          const SizedBox(height: 8),
                          SettingsHint(
                            text: _ratesStripStyle == RatesStripStyle.labeled
                                ? 'Muestra el nombre de cada moneda. Desliza los chips para ver la última actualización.'
                                : 'Solo el símbolo y el monto: las cuatro pastillas caben sin deslizar.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CustomRatesSection(
                        fields: <RateFieldData>[
                          for (final String code
                              in RatesController.customisableCodes)
                            RateFieldData(
                              code: code,
                              controller: _controllers[code]!,
                              official: widget.rates.officialValueOf(code),
                            ),
                        ],
                        onSaveAll: _saveAllRates,
                        onRestoreOne: _restoreOne,
                        onRestoreAll: _restoreAll,
                      ),
                      const SizedBox(height: 14),
                      RatesStatusSection(
                        lastUpdate: widget.rates.lastUpdate,
                        timeToNextRefresh: _timeToNextRefresh,
                        isRefreshing: widget.rates.isLoading,
                        onRefresh: _refreshRates,
                      ),
                    ],
                    const SizedBox(height: 14),
                    SettingsSection(
                      title: 'Acerca de',
                      children: <Widget>[
                        // The rating row is hidden where there is nothing to
                        // open: tapping through to a dead link is worse than
                        // not offering the row at all.
                        if (AppLinks.hasStoreListing) ...<Widget>[
                          SettingsRow(
                            icon: Icons.star_outline_rounded,
                            label: 'Calificar la app',
                            subtitle: 'Abre la ficha en la tienda',
                            onTap: _rateApp,
                          ),
                          const SettingsDivider(),
                        ],
                        SettingsRow(
                          icon: Icons.info_outline_rounded,
                          label: 'Versión',
                          trailing: Text(
                            _appVersion ?? '—',
                            style: AppTypography.chip.copyWith(
                              color: glass.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final GlassTokens glass = context.glass;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 4.0, 16.0, 4.0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Volver',
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: glass.textPrimary,
            ),
          ),
          Text(
            title,
            style: AppTypography.headerTitle.copyWith(
              color: glass.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
