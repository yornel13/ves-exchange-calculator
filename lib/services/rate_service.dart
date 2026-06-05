import 'dart:convert';

import 'package:http/http.dart' as http;

class ExchangeRates {
  final double usdVes;
  final double eurVes;
  final double usdtVes;

  ExchangeRates({
    required this.usdVes,
    required this.eurVes,
    required this.usdtVes,
  });
}

class RateService {
  // ============================================================
  // CONFIGURACIÓN DE URLs DEL BACKEND
  // ============================================================
  // Descomentar la línea correspondiente según el entorno:
  // - LOCAL: Para desarrollo y pruebas locales
  // - PRODUCCIÓN: Para la app en producción
  //
  // NOTA: En emulador Android, "localhost" es el emulador;
  //       para llegar a tu PC usa 10.0.2.2
  // ============================================================

  // -------------------- URLs LOCALES (desarrollo) — ACTIVE --------------------
  // Standalone backend (smart_calculator_backend) on port 3002.
  // No '/api/calculator' prefix: there is no Gateway anymore, routes are at root.
  // Desktop / iOS simulator / Flutter Web use 'localhost'.
  // Android emulator must use '10.0.2.2' to reach the host machine.
  static const _bcvBackendUrl =
      'http://localhost:3002/bcv/rates';
  static const _usdtBackendUrl =
      'http://localhost:3002/binance/usdt-p2p?asset=USDT&fiat=VES';

  // Android emulator alternative:
  // static const _bcvBackendUrl =
  //     'http://10.0.2.2:3002/bcv/rates';
  // static const _usdtBackendUrl =
  //     'http://10.0.2.2:3002/binance/usdt-p2p?asset=USDT&fiat=VES';

  // -------------------- URLs PRODUCCIÓN (legacy multi-backend) --------------------
  // TODO: replace with the new standalone backend URL once deployed.
  // static const _bcvBackendUrl =
  //     'https://multi-backend-5bta.onrender.com/api/calculator/bcv/rates';
  // static const _usdtBackendUrl =
  //     'https://multi-backend-5bta.onrender.com/api/calculator/binance/usdt-p2p?asset=USDT&fiat=VES';

  Future<ExchangeRates> fetchRates() async {
    final usdVes = await _fetchSingleFiat('USD');
    final eurVes = await _fetchSingleFiat('EUR');
    double usdtVes = await _fetchUsdtVesFromBackend();

    // Si Binance P2P falla o no devuelve ofertas válidas, usar USD/VES
    // como aproximación para USDT (USDT ≈ 1 USD)
    if (usdtVes <= 0 && usdVes > 0) {
      usdtVes = usdVes;
    }

    // Logs simples para depurar en consola
    // (puedes comentarlos si no los necesitas)
    // ignore: avoid_print
    print(
        'Rates fetched -> USD/VES: $usdVes, EUR/VES: $eurVes, USDT/VES (Binance P2P): $usdtVes');

    return ExchangeRates(
      usdVes: usdVes,
      eurVes: eurVes,
      usdtVes: usdtVes,
    );
  }

  Future<double> _fetchSingleFiat(String base) async {
    final uri = Uri.parse(_bcvBackendUrl);

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // ignore: avoid_print
          print('BCV backend request timeout after 10 seconds');
          throw Exception('Request timeout');
        },
      );
      // ignore: avoid_print
      print('BCV backend request -> URL: $uri, status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (base == 'USD' && data['usd'] is num) {
          return (data['usd'] as num).toDouble();
        }
        if (base == 'EUR' && data['eur'] is num) {
          return (data['eur'] as num).toDouble();
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching $base rate: $e');
    }

    return 0.0;
  }

  Future<double> _fetchUsdtVesFromBackend() async {
    final uri = Uri.parse(_usdtBackendUrl);

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // ignore: avoid_print
          print('USDT backend request timeout after 10 seconds');
          throw Exception('Request timeout');
        },
      );
      // ignore: avoid_print
      print('USDT backend request -> URL: $uri, status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final dynamic raw = data['price'];
        if (raw is num) {
          return raw.toDouble();
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching USDT rate: $e');
    }

    return 0.0;
  }
}
