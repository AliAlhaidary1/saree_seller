import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sareemart_seller/core/api_errors.dart';

void main() {
  test('release logging excludes exception bodies and request paths', () {
    final messages = <String?>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = previous);
    logApiFailure(
      classifyUnknown(
        'SQLSTATE Bearer secret-token /var/www/private',
        release: true,
      ),
      path: '/orders/customer@example.com?access_token=secret-token',
    );
    expect(messages, ['[backend] code=UNAVAILABLE status=null']);
  });

  test('development logging preserves diagnostic details', () {
    final messages = <String?>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = previous);
    logApiFailure(
      classifyUnknown('diagnostic detail', release: false),
      path: '/orders',
    );
    expect(messages.single, contains('diagnostic detail'));
    expect(messages.single, contains('path=/orders'));
  });
}
