import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ves_exchange_calculator/utils/app_links.dart';

/// Opens the app's store listing.
///
/// Kept out of the settings widget so the screen never has to know about
/// platform schemes or launch fallbacks.
class StoreLauncher {
  const StoreLauncher._();

  /// Sends the user to the store's review form. Returns false when no listing
  /// could be opened — the caller decides what to tell the user.
  ///
  /// The first candidate is the native store app and may not resolve (no Play
  /// Store on the device, a simulator), so every candidate is tried in turn
  /// before giving up.
  static Future<bool> openReview() async {
    for (final String url in AppLinks.reviewUrls) {
      final Uri uri = Uri.parse(url);

      if (await _tryLaunch(uri, LaunchMode.externalApplication)) return true;

      // Web fallbacks also work in an in-app browser (Custom Tabs, SFSafari),
      // which is reachable on devices with no browser marked as external.
      if (uri.scheme == 'https' &&
          await _tryLaunch(uri, LaunchMode.platformDefault)) {
        return true;
      }
    }
    return false;
  }

  static Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (e) {
      debugPrint('Could not open $uri with $mode: $e');
      return false;
    }
  }
}
