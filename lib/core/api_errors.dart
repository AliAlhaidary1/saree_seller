import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum ApiRequestKind { public, private, mutation }

class ApiErrorPolicy {
  const ApiErrorPolicy({required this.release});

  final bool release;

  static ApiErrorPolicy current = ApiErrorPolicy(
    release: const bool.fromEnvironment('dart.vm.product'),
  );
}

class ClassifiedApiError {
  const ClassifiedApiError({
    required this.code,
    required this.publicCode,
    required this.originalMessage,
    required this.userMessage,
    required this.release,
    this.httpStatus,
    this.cause,
    this.details,
  });

  final String code;
  final String publicCode;
  final String originalMessage;
  final String userMessage;
  final bool release;
  final int? httpStatus;
  final String? cause;
  final Object? details;

  Map<String, dynamic> toResultMap() {
    if (!release) {
      return {
        'status': 0,
        'message': originalMessage,
        'error': {
          'code': code,
          'httpStatus': httpStatus,
          'cause': cause,
          'details': details,
        },
      };
    }
    return {
      'status': 0,
      'message': userMessage,
      'error': {'code': publicCode},
    };
  }
}

final _sensitive = RegExp(
  r'(sqlstate|stack trace|Bearer\s+\S+|access_token|mysql_|postgres|Illuminate\\|PDOException|/var/www|/home/|APP_KEY|localhost:\d+|127\.0\.0\.1)',
  caseSensitive: false,
);

const _userMessages = <String, String>{
  'ECONNREFUSED': 'تعذر الاتصال بالخادم. حاول لاحقاً.',
  'TIMEOUT': 'انتهت مهلة الطلب. حاول مرة أخرى.',
  'HTTP_500': 'حدث خطأ في الخادم. حاول لاحقاً.',
  'HTTP_422': 'تحقق من البيانات المدخلة وحاول مرة أخرى.',
  'HTTP_401': 'انتهت الجلسة. سجّل الدخول مجدداً.',
  'HTTP_403': 'ليست لديك صلاحية لهذا الإجراء.',
  'HTTP_404': 'العنصر المطلوب غير موجود.',
  'MALFORMED_RESPONSE': 'استجابة غير متوقعة من الخادم.',
  'AUTH_ERROR': 'فشل التحقق من الهوية. حاول مرة أخرى.',
  'LARAVEL_EXCEPTION': 'حدث خطأ في الخادم. حاول لاحقاً.',
  'NETWORK': 'تعذر الاتصال بالخادم. تحقق من الإنترنت.',
  'UNKNOWN': 'حدث خطأ ما. حاول مرة أخرى.',
};

const _publicCodes = <String, String>{
  'ECONNREFUSED': 'UNAVAILABLE',
  'TIMEOUT': 'TIMEOUT',
  'HTTP_500': 'UNAVAILABLE',
  'HTTP_422': 'VALIDATION',
  'HTTP_401': 'AUTH',
  'HTTP_403': 'FORBIDDEN',
  'HTTP_404': 'NOT_FOUND',
  'MALFORMED_RESPONSE': 'UNAVAILABLE',
  'AUTH_ERROR': 'AUTH',
  'LARAVEL_EXCEPTION': 'UNAVAILABLE',
  'NETWORK': 'UNAVAILABLE',
  'UNKNOWN': 'UNAVAILABLE',
};

bool containsSensitive(String? value) {
  if (value == null || value.isEmpty) return false;
  return _sensitive.hasMatch(value);
}

bool looksLikeLaravelException(dynamic data) {
  if (data is! Map) return false;
  return data.containsKey('exception') ||
      data.containsKey('trace') ||
      (data.containsKey('file') && data.containsKey('line'));
}

ApiRequestKind inferRequestKind(String path, {String method = 'GET'}) {
  final value = path.toLowerCase();
  if (RegExp(
    r'place_order|add_transaction|initiate_transaction|update_status|update_order_status|akhdimni/place|payment|/save|/update|/delete|/add|/attach|/detach|/fulfillment|/cancel|/reject-item|/apply-template|/publish|/appearance',
  ).hasMatch(value)) {
    return ApiRequestKind.mutation;
  }
  if (method.toUpperCase() != 'GET') return ApiRequestKind.mutation;
  if (value.contains('login') ||
      value.contains('register') ||
      value.contains('brand') ||
      value.contains('privacy') ||
      value.contains('terms')) {
    return ApiRequestKind.public;
  }
  return ApiRequestKind.private;
}

bool shouldRetryApi({
  required ClassifiedApiError error,
  required int attempt,
  required ApiRequestKind kind,
  required bool release,
}) {
  if (attempt >= 1) return false;
  if (kind == ApiRequestKind.mutation) return false;
  // GET فقط (عام أو خاص): إعادة واحدة لأخطاء الشبكة/المهلة في الإنتاج والتطوير
  void unusedRelease() => release;
  unusedRelease();
  return error.code == 'ECONNREFUSED' ||
      error.code == 'TIMEOUT' ||
      error.code == 'NETWORK' ||
      error.code == 'MALFORMED_RESPONSE';
}

void logApiFailure(ClassifiedApiError error, {String? path}) {
  debugPrint(
    '[backend] code=${error.code} status=${error.httpStatus} path=$path message=${error.originalMessage}',
  );
}

ClassifiedApiError classifyDio(DioException error, {required bool release}) {
  final status = error.response?.statusCode;
  final data = error.response?.data;
  final message = error.message ?? error.toString();
  final type = error.type;
  final osCode = error.error?.toString() ?? '';

  if (type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.sendTimeout ||
      type == DioExceptionType.receiveTimeout) {
    return _build('TIMEOUT', message, release, httpStatus: 504, cause: type.name);
  }

  if (type == DioExceptionType.connectionError ||
      osCode.contains('ECONNREFUSED') ||
      message.contains('ECONNREFUSED') ||
      osCode.contains('Connection refused')) {
    final code = (osCode.contains('ECONNREFUSED') ||
            message.contains('ECONNREFUSED') ||
            osCode.contains('Connection refused'))
        ? 'ECONNREFUSED'
        : 'NETWORK';
    return _build(code, message, release, httpStatus: 502, cause: osCode);
  }

  if (status == 422) {
    return _build(
      'HTTP_422',
      _messageFromBody(data, 'HTTP 422'),
      release,
      httpStatus: 422,
      details: data,
    );
  }

  if (status == 401 || status == 403) {
    return _build(
      status == 401 ? 'HTTP_401' : 'HTTP_403',
      _messageFromBody(data, 'HTTP $status'),
      release,
      httpStatus: status,
      details: data,
    );
  }

  if (looksLikeLaravelException(data) || containsSensitive('$data')) {
    return _build(
      'LARAVEL_EXCEPTION',
      _messageFromBody(data, message),
      release,
      httpStatus: status ?? 500,
      details: data,
    );
  }

  if (status != null && status >= 500) {
    final malformed = data is! Map;
    return _build(
      malformed ? 'MALFORMED_RESPONSE' : 'HTTP_500',
      _messageFromBody(data, 'HTTP $status'),
      release,
      httpStatus: status,
      details: data,
    );
  }

  if (type == DioExceptionType.badResponse) {
    return _build(
      'HTTP_500',
      _messageFromBody(data, message),
      release,
      httpStatus: status ?? 500,
      details: data,
    );
  }

  return _build('UNKNOWN', message, release, cause: type.name, details: data);
}

ClassifiedApiError classifyUnknown(Object error, {required bool release}) {
  final message = '$error';
  if (message.contains('ECONNREFUSED') || message.contains('Connection refused')) {
    return _build('ECONNREFUSED', message, release, httpStatus: 502);
  }
  if (message.toLowerCase().contains('timeout')) {
    return _build('TIMEOUT', message, release, httpStatus: 504);
  }
  return _build('UNKNOWN', message, release);
}

ClassifiedApiError _build(
  String code,
  String original,
  bool release, {
  int? httpStatus,
  String? cause,
  Object? details,
}) {
  var userMessage = _userMessages[code] ?? _userMessages['UNKNOWN']!;
  if (code == 'HTTP_422' && !containsSensitive(original)) {
    userMessage = original;
  }
  return ClassifiedApiError(
    code: code,
    publicCode: _publicCodes[code] ?? 'UNAVAILABLE',
    originalMessage: original,
    userMessage: userMessage,
    release: release,
    httpStatus: httpStatus,
    cause: cause,
    details: release ? _sanitizeDetails(details) : details,
  );
}

Object? _sanitizeDetails(Object? details) {
  if (details is Map) {
    final out = <String, dynamic>{};
    details.forEach((key, value) {
      final name = '$key'.toLowerCase();
      if (name.contains('token') ||
          name.contains('exception') ||
          name.contains('trace') ||
          name.contains('sql') ||
          name == 'file' ||
          name == 'line') {
        return;
      }
      out['$key'] = value;
    });
    return out;
  }
  if (details is String && containsSensitive(details)) return '[redacted]';
  return null;
}

String _messageFromBody(dynamic data, String fallback) {
  if (data is Map) {
    final message = data['message'] ?? data['msg'] ?? data['error'];
    if (message is String && message.trim().isNotEmpty) return message;
  }
  if (data is String && data.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(data);
      return _messageFromBody(parsed, fallback);
    } catch (_) {
      return data.length > 300 ? fallback : data;
    }
  }
  return fallback;
}