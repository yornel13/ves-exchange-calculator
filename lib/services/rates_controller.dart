import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ves_exchange_calculator/models/currency_option.dart';
import 'package:ves_exchange_calculator/services/rate_service.dart';

/// Things worth telling the user about. The controller never shows UI itself —
/// the screen decides how (or whether) to surface each event.
enum RatesEvent {
  fetchStarted,
  fetchFinished,
  ratesUpdated,
  newRatesAvailable,
}

/// Owns the exchange rates: what they are, when they were fetched, the user's
/// custom overrides, and the hourly refresh.
///
/// Extracted from the calculator screen, which mixed network calls, shared
/// preferences and snack bars in a single 2400-line widget.
class RatesController extends ChangeNotifier {
  RatesController({RateService? service})
      : _service = service ?? RateService();

  final RateService _service;

  static const String _kUsdOverrideKey = 'usd_override';
  static const String _kEurOverrideKey = 'eur_override';
  static const String _kUsdtOverrideKey = 'usdt_override';
  static const String _kOverridesTimestampKey = 'ratesOverrideTimestampMs';
  static const String _kLastOfficialUsdKey = 'last_official_usd_ves';
  static const String _kLastOfficialEurKey = 'last_official_eur_ves';
  static const String _kLastOfficialUsdtKey = 'last_official_usdt_ves';
  static const String _kHasNewOfficialRatesKey = 'hasNewOfficialRates';
  static const String _kLastRatesUpdateTimestampKey =
      'lastRatesUpdateTimestampMs';

  /// How long a manual override stays in effect before falling back to the
  /// official rate.
  static const Duration _overrideLifetime = Duration(days: 1);

  /// Available currencies. VES is the base, so every other value is in VES.
  final List<CurrencyOption> currencies = <CurrencyOption>[
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

  /// Preference keys per currency code, so the screens never spell them out.
  static const Map<String, String> _overrideKeys = <String, String>{
    'USD': _kUsdOverrideKey,
    'Euro': _kEurOverrideKey,
    'USDT': _kUsdtOverrideKey,
  };

  static const Map<String, String> _officialKeys = <String, String>{
    'USD': _kLastOfficialUsdKey,
    'Euro': _kLastOfficialEurKey,
    'USDT': _kLastOfficialUsdtKey,
  };

  /// Codes the user can customise. VES is the base and never has an override.
  static List<String> get customisableCodes => _overrideKeys.keys.toList();

  final Map<String, double> _official = <String, double>{};

  /// The last official rate fetched for [code], regardless of any override the
  /// user has on top of it.
  double? officialValueOf(String code) => _official[code];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  DateTime? _lastUpdate;

  /// When the rates currently held were fetched from the backend.
  DateTime? get lastUpdate => _lastUpdate;

  /// Set by the screen to receive [RatesEvent]s.
  void Function(RatesEvent event)? onEvent;

  Timer? _hourlyTimer;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _hourlyTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _emit(RatesEvent event) {
    if (_disposed) return;
    onEvent?.call(event);
  }

  double valueOf(String code) {
    for (final CurrencyOption c in currencies) {
      if (c.code == code) return c.value;
    }
    return 1.0;
  }

  /// Currencies that carry a rate, in the order the header shows them. VES is
  /// excluded: it is the base and always 1, so a chip for it says nothing.
  ///
  /// USDT leads because it is the rate that moves during the day; the two BCV
  /// rates only change once.
  List<CurrencyOption> get quotableCurrencies => <CurrencyOption>[
        option('USDT'),
        option('USD'),
        option('Euro'),
      ];

  CurrencyOption option(String code) {
    for (final CurrencyOption c in currencies) {
      if (c.code == code) return c;
    }
    return currencies.first;
  }

  void _setValue(String code, double value) {
    if (value <= 0) return;
    for (final CurrencyOption c in currencies) {
      if (c.code == code) {
        c.value = value;
        return;
      }
    }
  }

  /// Reads the cached timestamp and official rates so the UI can show them
  /// before any network call.
  Future<void> loadTimestamp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? ms = prefs.getInt(_kLastRatesUpdateTimestampKey);
    _lastUpdate = ms == null || ms <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms);

    _readOfficialRates(prefs);
    _notify();
  }

  void _readOfficialRates(SharedPreferences prefs) {
    for (final MapEntry<String, String> entry in _officialKeys.entries) {
      final double? value = prefs.getDouble(entry.value);
      if (value != null && value > 0) {
        _official[entry.key] = value;
      }
    }
  }

  /// Stores a custom rate for [code] and applies it immediately.
  Future<void> saveOverride(String code, double value) async {
    await saveOverrides(<String, double>{code: value});
  }

  /// Stores custom rates for several currencies in one go.
  Future<void> saveOverrides(Map<String, double> byCode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    for (final MapEntry<String, double> entry in byCode.entries) {
      final String? key = _overrideKeys[entry.key];
      if (key == null || entry.value <= 0) continue;
      await prefs.setDouble(key, entry.value);
      _setValue(entry.key, entry.value);
    }

    await prefs.setInt(
      _kOverridesTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    _notify();
  }

  /// Puts [code] back on its official rate, leaving the other currencies alone.
  Future<void> restoreOfficial(String code) async {
    final double? official = _official[code];
    if (official == null || official <= 0) return;
    await saveOverride(code, official);
  }

  /// True when the stored rates were fetched in a different clock hour than
  /// now, which is when the app considers them stale.
  Future<bool> _isStale() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? lastUpdateMs = prefs.getInt(_kLastRatesUpdateTimestampKey);

    if (lastUpdateMs == null || lastUpdateMs <= 0) {
      return true;
    }

    final DateTime last = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
    final DateTime now = DateTime.now();

    final bool sameHour = last.year == now.year &&
        last.month == now.month &&
        last.day == now.day &&
        last.hour == now.hour;

    return !sameHour;
  }

  /// Refreshes silently on every hour boundary, while [shouldRefresh] holds.
  void startHourlyScheduler({required bool Function() shouldRefresh}) {
    _hourlyTimer?.cancel();

    void scheduleNext() {
      if (_disposed) return;

      final DateTime now = DateTime.now();
      final DateTime next = DateTime(now.year, now.month, now.day, now.hour + 1);

      _hourlyTimer = Timer(next.difference(now), () async {
        if (_disposed) return;
        if (shouldRefresh()) {
          await refresh(announce: false);
        }
        scheduleNext();
      });
    }

    scheduleNext();
  }

  /// Loads whatever is on disk, then refreshes from the backend when stale.
  ///
  /// With nothing stored at all it goes straight to the network, since showing
  /// 1.0 rates would be worse than waiting.
  Future<void> loadStoredThenRefresh() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final double? lastUsd = prefs.getDouble(_kLastOfficialUsdKey);
    final double? lastEur = prefs.getDouble(_kLastOfficialEurKey);
    final double? lastUsdt = prefs.getDouble(_kLastOfficialUsdtKey);

    final bool hasAnyStored = (lastUsd != null && lastUsd > 0) ||
        (lastEur != null && lastEur > 0) ||
        (lastUsdt != null && lastUsdt > 0);

    if (!hasAnyStored) {
      await _refreshWithRetry();
      return;
    }

    final bool stale = await _isStale();
    if (_disposed) return;

    if (lastUsd != null) _setValue('USD', lastUsd);
    if (lastEur != null) _setValue('Euro', lastEur);
    if (lastUsdt != null) _setValue('USDT', lastUsdt);

    if (!stale) {
      _isLoading = false;
    }
    _notify();

    if (!stale) {
      _emit(RatesEvent.fetchFinished);
      // Still check in the background in case the backend changed within the
      // same hour.
      _refreshWithRetry(silent: true);
      return;
    }

    await _refreshWithRetry();
  }

  /// Fetches from the backend, retrying transient failures.
  Future<void> _refreshWithRetry({
    int maxAttempts = 3,
    bool silent = false,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await refresh(announce: !silent);
        return;
      } catch (e) {
        debugPrint('Rates fetch attempt $attempt/$maxAttempts failed: $e');
        if (attempt < maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    }

    debugPrint('Failed to fetch rates after $maxAttempts attempts');
    _isLoading = false;
    _notify();
    _emit(RatesEvent.fetchFinished);
  }

  /// Single network refresh. Persists the official values, keeps the user's
  /// custom overrides, and reports whether anything changed.
  Future<void> refresh({bool announce = true}) async {
    _isLoading = true;
    _notify();
    if (announce) _emit(RatesEvent.fetchStarted);

    final ExchangeRates rates = await _service.fetchRates();

    if (rates.usdVes <= 0 && rates.eurVes <= 0 && rates.usdtVes <= 0) {
      _isLoading = false;
      _notify();
      throw Exception('No valid rates received from service');
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final double? lastUsd = prefs.getDouble(_kLastOfficialUsdKey);
    final double? lastEur = prefs.getDouble(_kLastOfficialEurKey);
    final double? lastUsdt = prefs.getDouble(_kLastOfficialUsdtKey);

    final bool isFirstTime =
        lastUsd == null && lastEur == null && lastUsdt == null;

    final bool hasNew =
        (rates.usdVes > 0 && (lastUsd == null || lastUsd != rates.usdVes)) ||
            (rates.eurVes > 0 && (lastEur == null || lastEur != rates.eurVes)) ||
            (rates.usdtVes > 0 &&
                (lastUsdt == null || lastUsdt != rates.usdtVes));

    if (hasNew && !isFirstTime) {
      await prefs.setBool(_kHasNewOfficialRatesKey, true);
    }

    if (rates.usdVes > 0) {
      await prefs.setDouble(_kLastOfficialUsdKey, rates.usdVes);
      _official['USD'] = rates.usdVes;
    }
    if (rates.eurVes > 0) {
      await prefs.setDouble(_kLastOfficialEurKey, rates.eurVes);
      _official['Euro'] = rates.eurVes;
    }
    if (rates.usdtVes > 0) {
      await prefs.setDouble(_kLastOfficialUsdtKey, rates.usdtVes);
      _official['USDT'] = rates.usdtVes;
    }

    final DateTime fetchedAt = DateTime.now();
    await prefs.setInt(
      _kLastRatesUpdateTimestampKey,
      fetchedAt.millisecondsSinceEpoch,
    );
    _lastUpdate = fetchedAt;

    await _syncOverridesWithOfficialRates(
      prefs: prefs,
      rates: rates,
      previousUsd: lastUsd,
      previousEur: lastEur,
      previousUsdt: lastUsdt,
    );

    _setValue('USD', rates.usdVes);
    _setValue('Euro', rates.eurVes);
    _setValue('USDT', rates.usdtVes);

    await applyOverrides();

    _isLoading = false;
    _notify();

    // Order matters: the screen dismisses the loading message on
    // [fetchFinished], so the confirmation has to come after it.
    _emit(RatesEvent.fetchFinished);
    if (announce) _emit(RatesEvent.ratesUpdated);
  }

  /// An override the user did not personally set is just a cached copy of the
  /// official rate, so it follows the new official value. One the user did set
  /// is left alone until it expires.
  Future<void> _syncOverridesWithOfficialRates({
    required SharedPreferences prefs,
    required ExchangeRates rates,
    required double? previousUsd,
    required double? previousEur,
    required double? previousUsdt,
  }) async {
    bool isCustom(double? override, double? previousOfficial) =>
        override != null &&
        override > 0 &&
        previousOfficial != null &&
        override != previousOfficial;

    final bool customUsd =
        isCustom(prefs.getDouble(_kUsdOverrideKey), previousUsd);
    final bool customEur =
        isCustom(prefs.getDouble(_kEurOverrideKey), previousEur);
    final bool customUsdt =
        isCustom(prefs.getDouble(_kUsdtOverrideKey), previousUsdt);

    bool touched = false;

    if (!customUsd && rates.usdVes > 0) {
      await prefs.setDouble(_kUsdOverrideKey, rates.usdVes);
      touched = true;
    }
    if (!customEur && rates.eurVes > 0) {
      await prefs.setDouble(_kEurOverrideKey, rates.eurVes);
      touched = true;
    }
    if (!customUsdt && rates.usdtVes > 0) {
      await prefs.setDouble(_kUsdtOverrideKey, rates.usdtVes);
      touched = true;
    }

    if (touched) {
      await prefs.setInt(
        _kOverridesTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// Applies the user's custom rates on top of the official ones, dropping
  /// them once they are older than [_overrideLifetime].
  Future<void> applyOverrides() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int? ts = prefs.getInt(_kOverridesTimestampKey);
    if (ts != null) {
      final int age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _overrideLifetime.inMilliseconds) {
        await clearOverrides();
        return;
      }
    }

    final double? usd = prefs.getDouble(_kUsdOverrideKey);
    final double? eur = prefs.getDouble(_kEurOverrideKey);
    final double? usdt = prefs.getDouble(_kUsdtOverrideKey);

    if (usd != null) _setValue('USD', usd);
    if (eur != null) _setValue('Euro', eur);
    if (usdt != null) _setValue('USDT', usdt);

    _notify();
  }

  /// Drops the user's custom rates and falls back to the stored official ones.
  Future<void> clearOverrides() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsdOverrideKey);
    await prefs.remove(_kEurOverrideKey);
    await prefs.remove(_kUsdtOverrideKey);
    await prefs.remove(_kOverridesTimestampKey);

    _readOfficialRates(prefs);
    for (final MapEntry<String, double> entry in _official.entries) {
      _setValue(entry.key, entry.value);
    }

    _notify();
  }

  /// Reads and clears the "official rates changed" flag.
  Future<bool> consumeNewRatesFlag() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool hasNew = prefs.getBool(_kHasNewOfficialRatesKey) ?? false;
    if (hasNew) {
      await prefs.setBool(_kHasNewOfficialRatesKey, false);
    }
    return hasNew;
  }
}
