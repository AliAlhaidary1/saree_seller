import 'app_controller.dart';

/// Central Arabic labels and value formatting.
/// Keep API values untouched; only presentation is translated here.
abstract final class Fmt {
  static const _status = <String, String>{
    'pending': 'بانتظار التجهيز',
    'new': 'جديد',
    'received': 'مستلم',
    'preparing': 'قيد التجهيز',
    'processing': 'قيد المعالجة',
    'ready': 'جاهز',
    'assigned': 'معيّن للمندوب',
    'accepted': 'مقبول',
    'picking_up': 'جارٍ الاستلام',
    'picked_up': 'تم الاستلام',
    'out_for_delivery': 'قيد التوصيل',
    'delivered': 'تم التسليم',
    'completed': 'مكتمل',
    'failed': 'فشل التوصيل',
    'cancelled': 'ملغي',
    'canceled': 'ملغي',
    'returned': 'مرتجع',
    'unassigned': 'غير معيّن',
    'refunded': 'مسترجع',
    'rejected': 'مرفوض',
    'active': 'نشط',
    'inactive': 'غير نشط',
    'paid': 'مدفوع',
    'unpaid': 'غير مدفوع',
    'cod': 'الدفع عند الاستلام',
    'cash': 'نقداً',
    'card': 'بطاقة',
    'wallet': 'المحفظة',
    'online': 'دفع إلكتروني',
    'bank_transfer': 'تحويل بنكي',
    'percentage': 'نسبة مئوية',
    'percent': 'نسبة مئوية',
    'fixed': 'مبلغ ثابت',
    'amount': 'مبلغ ثابت',
  };

  static String status(dynamic value) => _label(value);

  static String fulfillment(dynamic value) => _label(value);

  static String delivery(dynamic value) => _label(value);

  static String payment(dynamic value) => _label(value);

  static String paymentMethod(dynamic value) => _label(value);

  static String discountType(dynamic value) => _label(value);

  static String active(dynamic value) {
    if (value == true || value == 1 || '$value' == '1') return 'نشط';
    if (value == false || value == 0 || '$value' == '0') return 'غير نشط';
    return _label(value);
  }

  static String _label(dynamic value) {
    final raw = '$value'.trim();
    if (raw.isEmpty || raw == 'null') return '';
    return _status[raw.toLowerCase()] ?? raw;
  }

  static String date(dynamic value, {bool withTime = false}) {
    final d = _parse(value);
    if (d == null) return '$value'.trim();
    final date = '${d.day}/${d.month}/${d.year}';
    if (!withTime) return date;
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute ${d.hour < 12 ? 'ص' : 'م'}';
  }

  static String dateRange(dynamic start, dynamic end) {
    final a = date(start);
    final b = date(end);
    if (a.isEmpty && b.isEmpty) return '';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a - $b';
  }

  static String money(dynamic value, {String? currency}) {
    final n = _number(value);
    if (n == null) return '$value'.trim();
    final fixed = n.abs() < 0.005 ? 0 : n;
    final text = _group(fixed.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), ''));
    final symbol = currency?.trim().isNotEmpty == true ? currency!.trim() : app.currencySymbol;
    return symbol.isEmpty ? text : '$text $symbol';
  }

  static String number(dynamic value) {
    final n = _number(value);
    if (n == null) return '$value'.trim();
    return _group(n == n.roundToDouble() ? n.toInt().toString() : n.toString());
  }

  static String _group(String value) {
    final negative = value.startsWith('-');
    final body = negative ? value.substring(1) : value;
    final parts = body.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final left = digits.length - i;
      buffer.write(digits[i]);
      if (left > 1 && left % 3 == 1) buffer.write(',');
    }
    final result = parts.length > 1 ? '$buffer.${parts.last}' : '$buffer';
    return negative ? '-$result' : result;
  }

  static DateTime? _parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    final text = '$value'.trim().replaceAll(',', '');
    if (text.isEmpty || text == 'null') return null;
    return double.tryParse(text);
  }
}
