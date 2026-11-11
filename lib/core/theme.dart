import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'brand_config.dart';

/// Sarea Mart Vendor brand palette.
abstract final class AppColors {
  static Color navy = BrandConfig.defaults.navy;
  static Color orange = BrandConfig.defaults.orange;
  static Color white = BrandConfig.defaults.white;
  static Color greyBg = BrandConfig.defaults.greyBg;
  static const border = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFDC2626);
  static const warningBg = Color(0xFFFFF4D6);
  static const errorBg = Color(0xFFFFEBEE);

  /// Accessible variant of the accent for text, filled buttons and chips.
  static Color orangeText = const Color(0xFFB54708);

  static Color statusNew = orange;
  static Color statusPreparing = navy;
  static const statusDispatched = success;
}

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

Color _readableOnWhite(Color color) {
  var result = color;
  for (var i = 0; i < 12 && _contrast(result, Colors.white) < 4.5; i++) {
    result = Color.lerp(result, Colors.black, 0.08)!;
  }
  return result;
}

ThemeData buildSellerTheme([BrandConfig? brand]) {
  final b = brand ?? BrandConfig.defaults;
  AppColors.navy = b.navy;
  AppColors.orange = b.orange;
  AppColors.orangeText = _readableOnWhite(b.orange);
  AppColors.white = b.white;
  AppColors.greyBg = b.greyBg;

  final baseText = ThemeData.light().textTheme.apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: b.navy,
    onPrimary: b.white,
    secondary: b.orange,
    onSecondary: b.white,
    surface: b.white,
    onSurface: b.textPrimary,
    error: b.error,
    onError: b.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.greyBg,
    textTheme: baseText.copyWith(
      titleLarge: baseText.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
      titleMedium: baseText.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      titleSmall: baseText.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 15, height: 1.5),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: baseText.bodySmall?.copyWith(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
      labelLarge: baseText.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.orange,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.orangeText : AppColors.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.navy : AppColors.textSecondary,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.orangeText,
      foregroundColor: AppColors.white,
      elevation: 4,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orangeText,
        foregroundColor: AppColors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: BorderSide(color: AppColors.border),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.orangeText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.orange, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.white,
      selectedColor: AppColors.navy,
      secondarySelectedColor: AppColors.navy,
      checkmarkColor: AppColors.white,
      labelStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        color: AppColors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.orange,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Maps order status text to brand badge colors.
OrderBadgeStyle orderBadgeStyle(String status) {
  final s = status.toLowerCase();
  if (s.contains('جديد') ||
      s.contains('new') ||
      s.contains('received') ||
      s.contains('استلام') ||
      s.contains('pending') ||
      s.contains('انتظار')) {
    return OrderBadgeStyle(
      bg: Color(0xFFFFF3E8),
      fg: AppColors.orangeText,
      label: 'جديد',
    );
  }
  if (s.contains('تحضير') ||
      s.contains('prepar') ||
      s.contains('process') ||
      s.contains('قيد')) {
    return OrderBadgeStyle(
      bg: Color(0xFFE8EEF4),
      fg: AppColors.navy,
      label: 'قيد التحضير',
    );
  }
  if (s.contains('dispatch') ||
      s.contains('deliver') ||
      s.contains('ship') ||
      s.contains('pickup') ||
      s.contains('جاهز') ||
      s.contains('توصيل') ||
      s.contains('مكتمل') ||
      s.contains('complete')) {
    return OrderBadgeStyle(
      bg: Color(0xFFDCFCE7),
      fg: AppColors.success,
      label: 'تم الإرسال',
    );
  }
  return OrderBadgeStyle(bg: AppColors.greyBg, fg: AppColors.textSecondary, label: status);
}

class OrderBadgeStyle {
  OrderBadgeStyle({required this.bg, required this.fg, required this.label});
  final Color bg;
  final Color fg;
  final String label;
}

/// Legacy alias — navy is now primary brand.
Color get brandColor => const Color(AppConfig.brand);
