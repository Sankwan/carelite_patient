import 'package:url_launcher/url_launcher.dart';

/// Hands off to other apps on the phone: maps for directions, the dialler
/// for a call. Behind an interface so widgets can be tested without a
/// platform channel.
abstract class ExternalLauncher {
  /// Opens turn-by-turn directions from wherever the patient is now.
  /// Returns false if nothing on the device could open it.
  Future<bool> openDirections({
    required double latitude,
    required double longitude,
  });

  /// Opens the dialler with [phone] filled in. The patient still presses
  /// call, so no CALL_PHONE permission is needed.
  Future<bool> dial(String phone);

  /// Opens a video room in a browser view inside the app (Chrome Custom
  /// Tabs / Safari View Controller), which supports camera and microphone.
  Future<bool> openVideoRoom(String url);
}

class UrlExternalLauncher implements ExternalLauncher {
  const UrlExternalLauncher();

  @override
  Future<bool> openDirections({
    required double latitude,
    required double longitude,
  }) {
    return _launch(directionsUri(latitude: latitude, longitude: longitude));
  }

  @override
  Future<bool> dial(String phone) => _launch(dialUri(phone));

  @override
  Future<bool> openVideoRoom(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      return false;
    }
  }

  /// Google's universal maps link: opens the Maps app when installed and
  /// the browser otherwise, on both Android and iOS, with the origin left
  /// to the device's live location.
  static Uri directionsUri({
    required double latitude,
    required double longitude,
  }) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });
  }

  /// Keeps digits and a leading `+` only — "+233 (0)20 123-4567" must not
  /// reach the dialler with spaces or brackets in it.
  static Uri dialUri(String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return Uri(scheme: 'tel', path: trimmed.startsWith('+') ? '+$digits' : digits);
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
