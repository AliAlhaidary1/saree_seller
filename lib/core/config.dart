class AppConfig {
  static const defaultApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://admin.sreamart.com',
  );

  static const apiSubUrl = '/api';
  static const loginType = 3;
  static const countryDialCode = '967';
  static const appVersion = '1.0.3';
  static const brand = 0xFF0A2540;
  static const accent = 0xFFFF6B00;

  static bool isUnreachableOnDevice(String url) {
    final value = url.toLowerCase();
    return value.contains('10.0.2.2') ||
        value.contains('127.0.0.1') ||
        value.contains('localhost');
  }

  static String fileUrl(String apiUrl, dynamic path) {
    final value = '$path';
    if (value.isEmpty || value == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final root = apiUrl.endsWith('/')
        ? apiUrl.substring(0, apiUrl.length - 1)
        : apiUrl;
    final rel = value.startsWith('/') ? value : '/storage/$value';
    return '$root$rel';
  }
}