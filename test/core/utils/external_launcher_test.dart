import 'package:carelite_app/core/utils/external_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('directions link targets the facility and leaves the origin to the '
      'phone', () {
    final uri = UrlExternalLauncher.directionsUri(
      latitude: 5.5717,
      longitude: -0.2107,
    );

    expect(uri.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=5.5717%2C-0.2107');
    expect(uri.queryParameters.containsKey('origin'), isFalse);
  });

  test('dial link strips spaces, brackets and dashes but keeps the +', () {
    expect(
      UrlExternalLauncher.dialUri('+233 (0)20 123-4567').toString(),
      'tel:+2330201234567',
    );
    expect(UrlExternalLauncher.dialUri('020 123 4567').toString(),
        'tel:0201234567');
  });
}
