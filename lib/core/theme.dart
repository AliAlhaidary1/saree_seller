import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'brand_config.dart';

/// Saree Market Vendor brand palette.
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

  static Color statusNew = orange;
  static Color statusPreparing = navy;
  static const statusDispatched = success;
}

ThemeData buildSellerTheme([BrandConfig? brand]) {
  final b = brand ?? BrandConfig.defaults;
  AppColors.navy = b.navy;
  AppColors.orange = b.orange;
  AppColors.white = b.white;
  AppColors.greyBg = b.greyBg;

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
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.orange.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.orange : AppColors.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.orange : AppColors.textSecondary,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.orange,
      foregroundColor: AppColors.white,
      elevation: 4,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.orange,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
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
      fg: AppColors.orange,
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