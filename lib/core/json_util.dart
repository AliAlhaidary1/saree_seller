import 'dart:convert';

class J {
  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> maps(dynamic value) {
    if (value is! List) return const [];
    return value.map(map).toList();
  }

  static String str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = '$value';
    return text == 'null' ? fallback : text;
  }

  static int i(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }

  static double d(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  static bool flag(dynamic value) {
    return value == true || value == 1 || value == '1';
  }

  static String html(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || text == 'null' || text == '[]' || text == '{}') {
        return '';
      }
      if ((text.startsWith('{') && text.endsWith('}')) ||
          (text.startsWith('[') && text.endsWith(']'))) {
        try {
          return html(jsonDecode(text));
        } catch (_) {}
      }
      return value;
    }
    if (value is Map) {
      return html(
        value['html'] ??
            value['content'] ??
            value['data'] ??
            value['ar'] ??
            value['en'] ??
            value['privacy_policy_seller'] ??
            value['terms_conditions_seller'] ??
            value['privacy_policy'] ??
            value['terms_conditions'],
      );
    }
    if (value is List && value.isNotEmpty) return html(value.first);
    return '';
  }

  static String plain(dynamic value, [String fallback = '']) {
    if (value is Map || value is List) {
      value = html(value);
    }
    var text = html(value);
    if (text.isEmpty) {
      text = value is String ? str(value) : '';
    }
    text = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
    if (text.isEmpty) return fallback;
    if (text.startsWith('{') ||
        text.startsWith('[') ||
        text.startsWith('logo:') ||
        RegExp(r'^https?://\S+\.(png|jpe?g|webp|svg|gif)', caseSensitive: false)
            .hasMatch(text)) {
      return fallback;
    }
    return text;
  }
}

class ApiResult {
  ApiResult(this.raw);
  final Map<String, dynamic> raw;
  int get status => J.i(raw['status']);
  bool get ok => status == 1;
  String get message => J.str(raw['message'] ?? raw['msg']);
  String get failMessage =>
      message.isEmpty ? 'تعذر التحميل. تحقق من الإنترنت.' : message;
  dynamic get data => raw['data'];
  Map<String, dynamic> get dataMap => J.map(raw['data']);
  List<Map<String, dynamic>> get dataMaps {
    final value = raw['data'];
    if (value is List) return J.maps(value);
    for (final key in [
      'orders',
      'data',
      'products',
      'get_products',
      'items',
      'salesReports',
      'invoices',
      'daily',
      'media',
      'transactions',
    ]) {
      final nested = dataMap[key];
      if (nested is List) return J.maps(nested);
    }
    return const [];
  }

  List<Map<String, dynamic>> list(String key) =>
      J.maps(dataMap[key] ?? raw[key]);

  String? get token {
    final value =
        dataMap['access_token'] ?? raw['access_token'] ?? dataMap['token'];
    final text = value?.toString();
    return (text == null || text.isEmpty) ? null : text;
  }

  Map<String, dynamic> get user => J.map(dataMap['user'] ?? raw['user']);
}
