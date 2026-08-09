/// WordPress API connection settings for Access Law Office.
///
/// Override at build/run time:
/// ```
/// flutter run --dart-define=WP_BASE_URL=https://accesslawoffice.com
/// ```
library;

class WpConfig {
  const WpConfig._();

  /// Site origin only (no trailing slash). Empty = WordPress backend disabled.
  static const String baseUrl = String.fromEnvironment(
    'WP_BASE_URL',
    defaultValue: 'https://accesslawoffice.com',
  );

  static String get apiRoot {
    final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$root/wp-json/alf/v1';
  }

  /// True when a non-placeholder WordPress URL is configured.
  static bool get isConfigured =>
      baseUrl.isNotEmpty &&
      !baseUrl.contains('REPLACE_ME') &&
      baseUrl.startsWith('http');
}
