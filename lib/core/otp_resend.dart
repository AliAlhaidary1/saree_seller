import 'dart:async';

import 'package:flutter/foundation.dart';

/// OTP resend classification + gate for the forgot-password flow.
///
/// All Arabic literals are inline on purpose: this app has no i18n.
enum OtpSendKind { hardLimit, cooldown, error }

final RegExp _hardReason = RegExp(
  r'rate.?limit|limit.?exceed|hourly|hour.?limit|quota|otp.?(block|banned|suspend)|send.?(block|banned|suspend)',
  caseSensitive: false,
);

final RegExp _hardMessage = RegExp(
  r'الساعي|اليومي|تجاوزت الحد|تجاوز.*الحد|exceed.*limit|limit.*exceed|hourly|daily limit|maximum.*(attempt|request|code)',
  caseSensitive: false,
);

final RegExp _coolReason = RegExp(
  r'rate.?limit|too.?many|throttl|cooldown|limit.?exceed|hourly|otp.?(limit|cooldown|block)|send.?(limit|cooldown|block)',
  caseSensitive: false,
);

final RegExp _coolMessage = RegExp(
  r'انتظر|ثوان|ثانية|دقيقة|الساعي|ساعة|متاح|لاحق|مؤقت|كثير|الحد|إعادة|wait|second|minute|hour|availab|later|temporar|many|limit|throttl|too many|try again|retry|cooldown|rate',
  caseSensitive: false,
);

final RegExp _dioGeneric = RegExp(
  r'request failed|dioexception|dio exception|xmlhttprequest',
  caseSensitive: false,
);

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

int _asRetryInt(dynamic value) {
  int? parsed;
  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else if (value is String) {
    parsed = int.tryParse(value.trim());
  }
  if (parsed != null && parsed > 0 && parsed <= 600) return parsed;
  return 0;
}

String _normalizeDigits(String input) {
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var out = input;
  for (var i = 0; i < arabic.length; i++) {
    out = out.replaceAll(arabic[i], '$i');
  }
  return out;
}

/// reason from raw['reason'] ?? raw['data']['reason'] ?? raw['error']['details']['reason'].
String extractOtpReason(Map raw) {
  final top = raw['reason'];
  if (top is String && top.trim().isNotEmpty) return top.trim();
  final data = raw['data'];
  if (data is Map) {
    final r = data['reason'];
    if (r is String && r.trim().isNotEmpty) return r.trim();
  }
  final err = raw['error'];
  if (err is Map) {
    final details = err['details'];
    if (details is Map) {
      final r = details['reason'];
      if (r is String && r.trim().isNotEmpty) return r.trim();
    }
  }
  return '';
}

/// message from raw['message'] ?? raw['msg'], skipping dio-generic texts.
String extractOtpMessage(Map raw) {
  dynamic m = raw['message'] ?? raw['msg'];
  if (m is! String) return '';
  var msg = m.trim();
  if (msg.isEmpty) return '';
  if (_dioGeneric.hasMatch(msg)) return '';
  return msg;
}

int extractOtpStatus(Map raw) {
  final v = raw['status'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

int? extractOtpHttpStatus(Map raw) {
  int? pick(dynamic v) {
    if (v is int && v >= 100 && v <= 599) return v;
    if (v is num && v >= 100 && v <= 599) return v.toInt();
    if (v is String) {
      final p = int.tryParse(v.trim());
      if (p != null && p >= 100 && p <= 599) return p;
    }
    return null;
  }

  final err = raw['error'];
  if (err is Map) {
    final m = _asMap(err);
    final direct =
        pick(m['httpStatus']) ??
        pick(m['http_status']) ??
        pick(m['statusCode']);
    if (direct != null) return direct;
    final details = m['details'];
    if (details is Map) {
      final dm = _asMap(details);
      final fromDetails =
          pick(dm['httpStatus']) ??
          pick(dm['http_status']) ??
          pick(dm['statusCode']);
      if (fromDetails != null) return fromDetails;
    }
  }
  final top =
      pick(raw['httpStatus']) ??
      pick(raw['http_status']) ??
      pick(raw['statusCode']);
  if (top != null) return top;
  return null;
}

/// retryAfter = first int>0 and ≤600 among the known keys, else digits parsed from message.
int extractOtpRetryAfter(Map raw, String message) {
  final candidates = <dynamic>[raw['retry_after'], raw['retryAfter']];
  final data = raw['data'];
  if (data is Map) candidates.add(data['retry_after']);
  final err = raw['error'];
  if (err is Map) {
    final details = err['details'];
    if (details is Map) {
      candidates.add(details['retry_after']);
    }
  }
  for (final c in candidates) {
    final v = _asRetryInt(c);
    if (v > 0) return v;
  }
  if (message.isNotEmpty) {
    final normalized = _normalizeDigits(message);
    final match = RegExp(r'\d+').firstMatch(normalized);
    if (match != null) {
      final v = int.tryParse(match.group(0) ?? '') ?? 0;
      if (v > 0 && v <= 600) return v;
    }
  }
  return 0;
}

/// Classify per agreed logic. Check hard_limit FIRST, with the
/// retry_after 1..300 exception (not hard in that case).
OtpSendKind classifyOtpSend({
  required String reason,
  required String message,
  required int retryAfter,
  int? httpStatus,
  int? status,
}) {
  final hasShortRetry = retryAfter >= 1 && retryAfter <= 300;
  if (!hasShortRetry) {
    if (_hardReason.hasMatch(reason)) return OtpSendKind.hardLimit;
    if (_hardMessage.hasMatch(message)) return OtpSendKind.hardLimit;
  }
  if (httpStatus == 429 || status == 429) return OtpSendKind.cooldown;
  if (retryAfter > 0) return OtpSendKind.cooldown;
  if (_coolReason.hasMatch(reason)) return OtpSendKind.cooldown;
  if (_coolMessage.hasMatch(message)) return OtpSendKind.cooldown;
  return OtpSendKind.error;
}

class OtpSendInfo {
  OtpSendInfo({
    required this.reason,
    required this.message,
    required this.retryAfter,
    required this.status,
    required this.httpStatus,
    required this.kind,
  });

  final String reason;
  final String message;
  final int retryAfter;
  final int status;
  final int? httpStatus;
  final OtpSendKind kind;
}

/// Full extraction + classification from [ApiResult.raw].
OtpSendInfo analyzeOtpSend(Map raw) {
  final reason = extractOtpReason(raw);
  final message = extractOtpMessage(raw);
  final status = extractOtpStatus(raw);
  final httpStatus = extractOtpHttpStatus(raw);
  final retryAfter = extractOtpRetryAfter(raw, message);
  final kind = classifyOtpSend(
    reason: reason,
    message: message,
    retryAfter: retryAfter,
    httpStatus: httpStatus,
    status: status,
  );
  return OtpSendInfo(
    reason: reason,
    message: message,
    retryAfter: retryAfter,
    status: status,
    httpStatus: httpStatus,
    kind: kind,
  );
}

/// Gate for the resend button + background auto-resend.
///
/// - [allowedAt] is the earliest time a manual resend may fire.
/// - [lock] sets `max(60, extra)` seconds and arms an unlock [Timer]
///   invoking [onUnlock] so the UI can rebuild (no countdown numbers shown).
/// - Background auto-resend is a real [Timer] capped at
///   [maxBackgroundTries]; it bypasses the 60s button gate because the
///   backend window already elapsed. Callers must guard with `mounted`
///   and use the CURRENT number at fire time.
class OtpResendGate {
  DateTime allowedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _unlockTimer;
  Timer? _backgroundTimer;
  int backgroundTries = 0;

  static const int maxBackgroundTries = 0;
  static const int minLockSeconds = 60;

  bool get canSend => !DateTime.now().isBefore(allowedAt);

  bool get canBackground => backgroundTries < maxBackgroundTries;

  bool get hasBackground => _backgroundTimer?.isActive ?? false;

  void lock([int extraSec = 0, VoidCallback? onUnlock]) {
    final secs = extraSec > minLockSeconds ? extraSec : minLockSeconds;
    allowedAt = DateTime.now().add(Duration(seconds: secs));
    _unlockTimer?.cancel();
    if (onUnlock != null) {
      _unlockTimer = Timer(Duration(seconds: secs), onUnlock);
    }
  }

  void scheduleBackground(Duration delay, void Function() task) {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer(delay, task);
  }

  void cancelBackground() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  void noteBackgroundTry() {
    backgroundTries += 1;
  }

  void resetBackground() {
    backgroundTries = 0;
    cancelBackground();
  }

  void dispose() {
    _unlockTimer?.cancel();
    _backgroundTimer?.cancel();
  }
}
