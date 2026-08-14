import 'dart:io' show Platform;

/// Where the app lives on each store, and the message that carries the link.
///
/// Centralised so the share sheet, the rating row and anything added later (an
/// "about" section, a QR code) never disagree about the URL.
class AppLinks {
  const AppLinks._();

  /// Matches `applicationId` in `android/app/build.gradle.kts`.
  static const String androidPackage =
      'com.personal.yornel.vesexchange.calculator';

  /// Numeric App Store id, once the app is published there. While it is null
  /// there is no iOS listing to open, and [hasStoreListing] is false.
  static const String? appStoreId = null;

  static const String playStore =
      'https://play.google.com/store/apps/details?id=$androidPackage';

  /// Opens the Play Store app directly instead of the browser. Only resolvable
  /// on a device with the Play Store installed — always pair it with
  /// [playStore] as the fallback.
  static const String playStoreApp = 'market://details?id=$androidPackage';

  /// The listing to hand out when sharing. Android is the only published
  /// platform, so it is the link everyone gets.
  static const String download = playStore;

  /// Text for the share sheet. The link goes last: chat apps that build a
  /// preview card use the trailing URL.
  static const String shareMessage =
      'Calculadora de cambio: tasas del BCV y Binance al día, y una calculadora '
      'normal cuando la necesitas.\n\n$download';

  /// Whether the current platform has a store listing to open at all. False on
  /// iOS until [appStoreId] is filled in, and on desktop.
  static bool get hasStoreListing =>
      Platform.isAndroid || (Platform.isIOS && appStoreId != null);

  /// Store URLs to try, in order, when the user asks to rate the app. The first
  /// is the native store app; the second is the web fallback.
  static List<String> get reviewUrls {
    if (Platform.isAndroid) {
      return <String>[playStoreApp, playStore];
    }
    if (Platform.isIOS && appStoreId != null) {
      return <String>[
        'itms-apps://itunes.apple.com/app/id$appStoreId?action=write-review',
        'https://apps.apple.com/app/id$appStoreId?action=write-review',
      ];
    }
    return const <String>[];
  }
}
