import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'brand_config.dart';
import 'brand_service.dart';
import 'json_util.dart';
import 'panel_api.dart';
import 'push_service.dart';

class AppController extends ChangeNotifier {
  late SharedPreferences _prefs;
  late PanelApi api;

  String apiUrl = AppConfig.defaultApiUrl;
  String? token;
  Map<String, dynamic>? user;
  Map<String, dynamic> dashboard = {};
  Map<String, dynamic> settings = {};
  bool bootstrapped = false;
  String? error;
  BrandConfig brand = BrandConfig.defaults;

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  Map<String, dynamic> get seller => J.map(user?['seller']);
  int get sellerStatus => J.i(seller['status']);
  bool get isPending => sellerStatus == 0;
  bool get isRejected => sellerStatus == 2;
  // Web parity (SellerPendingStatus.vue): pending/rejected/no-store accounts
  // stay on the status screen until approved (status == 1).
  bool get needsPendingScreen =>
      seller.isEmpty || sellerStatus == 0 || sellerStatus == 2;  bool get isDeactivated => sellerStatus == 3;
  bool get isRemoved => sellerStatus == 7;
  bool get canWrite => sellerStatus == 1;
  // مطابق للخلفية: CheckSellerStatus + SellerController.getSettings
  bool get canViewCustomerDetail =>
      J.flag(seller['customer_privacy'] ?? settings['view_customer_detail'] ?? settings['customer_privacy'] ?? 1);
  bool get canViewOrderOtp =>
      J.flag(seller['view_order_otp'] ?? settings['view_order_otp'] ?? 0);
  bool get canAssignDelivery =>
      J.flag(seller['assign_delivery_boy'] ?? settings['assign_delivery_boy']);
  bool get canChangeOrderStatusDelivered => J.flag(
      seller['change_order_status_delivered'] ?? settings['change_order_status_delivered'] ?? 0);
  bool get requireProductsApproval => J.flag(
      seller['require_products_approval'] ?? settings['require_products_approval'] ?? 0);
  bool get isHomeSeller => J.flag(seller['is_home_seller']);
  // Web parity: CAMPAIGNS_FEATURE_ENABLED=false hides campaigns everywhere.
  bool get campaignsEnabled => J.flag(settings['campaigns_feature_enabled']);
  String get effectiveCommission =>
      J.str(seller['effective_commission'] ?? seller['commission'] ?? settings['seller_commission'] ?? '');
  Color get brandColor => brand.navy;
  Color get accentColor => brand.orange;
  String get storeName =>
      J.str(seller['store_name'] ?? user?['store_name'] ?? user?['name'], 'متجري');
  dynamic get sellerId => seller['id'] ?? user?['seller_id'];
  String get supportPhone => J.str(settings['support_number']);
  String get supportEmail => J.str(settings['support_email']);

  /// Platform open/closed from admin store settings (informational for sellers).
  bool get platformOpen {
    final o = J.str(settings['platform_opening_time']);
    final c = J.str(settings['platform_closing_time']);
    if (o.isEmpty && c.isEmpty) return true;
    if (o.isEmpty || c.isEmpty) return true;
    if (o == c) return false;
    int toMin(String t) {
      final p = t.split(':');
      if (p.length < 2) return -1;
      final h = int.tryParse(p[0]) ?? -1;
      final m = int.tryParse(p[1]) ?? -1;
      if (h < 0 || h > 23 || m < 0 || m > 59) return -1;
      return h * 60 + m;
    }
    final om = toMin(o);
    final cm = toMin(c);
    if (om < 0 || cm < 0) return true;
    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    if (om < cm) return cur >= om && cur < cm;
    return cur >= om || cur < cm;
  }
  bool dashboardFailed = false;

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    // الحفاظ على api_url المحفوظ — لا نعيد الكتابة بالافتراضي (مطابق setApiUrl).
    final savedUrl = _prefs.getString('api_url');
    apiUrl = (savedUrl != null && savedUrl.trim().isNotEmpty)
        ? savedUrl.trim()
        : AppConfig.defaultApiUrl;
    await _prefs.setString('api_url', apiUrl);
    token = _prefs.getString('token');
    final storedUser = _prefs.getString('user_json');
    if (storedUser != null) {
      try {
        user = J.map(jsonDecode(storedUser));
      } catch (_) {}
    }
    api = PanelApi(baseUrl: apiUrl, token: token);
    api.onUnauthorized = () {
      if (isLoggedIn) logout();
    };
    try {
      brand = await BrandService().load(apiUrl);
    } catch (_) {}
    if (isLoggedIn) {
      try {
        await refreshSession();
      } catch (_) {}
      // تفعيل FCM (قد تتوفر الشبكة الآن) ثم رفع توكن الدفع المخزّن
      // (يغطي حالة تجدده أثناء الخروج) — يصل حتى والتطبيق مغلق.
      try {
        await PushService.ensureFcm();
      } catch (_) {}
      PushService.onTokenChanged = _uploadPushToken;
      try {
        await _uploadPushToken(await PushService.getStoredToken());
      } catch (_) {}
    }
    bootstrapped = true;
    notifyListeners();
  }

  /// يرفع توكن FCM للسيرفر ليستمر وصول الإشعارات للجهاز والتطبيق مغلق.
  /// المسار الأساسي seller/save_fcm_token (UserToken type=Seller — الذي
  /// يقرأ منه مرسل إشعارات الطلبات)، مع fallback للمسار القديم.
  Future<void> _uploadPushToken(String? token) async {
    if (token == null || token.isEmpty || !isLoggedIn) return;
    try {
      final r = await api.saveSellerFcmToken(token);
      if (!r.ok) await api.saveFcmToken(token);
    } catch (_) {
      try {
        await api.saveFcmToken(token);
      } catch (_) {}
    }
  }

  Future<String?> login(String email, String password) async {
    String? fcmToken;
    try {
      fcmToken = await PushService.getStoredToken();
    } catch (_) {}
    final result = await api.login(email.trim(), password, fcmToken: fcmToken);
    if (!result.ok) {
      return result.message.isEmpty
          ? 'بيانات الدخول غير صحيحة'
          : result.message;
    }
    token = result.token;
    if (token == null || token!.isEmpty) {
      return 'تعذر إكمال تسجيل الدخول';
    }
    user = result.user.isNotEmpty ? result.user : result.dataMap;
    api.setToken(token);
    await _prefs.setString('token', token ?? '');
    await _prefs.setString('user_json', jsonEncode(user));
    // الرفع الفوري + عند أي تجدد لاحق — يضمن وصول الإشعارات والتطبيق مغلق.
    PushService.onTokenChanged = _uploadPushToken;
    try {
      await PushService.ensureFcm();
    } catch (_) {}
    await refreshSession();
    try {
      await _uploadPushToken(await PushService.getStoredToken());
    } catch (_) {}
    notifyListeners();
    return null;
  }

  Future<void> refreshSession() async {
    final status = await api.status();
    if (status.ok && status.dataMap.isNotEmpty) {
      final current = Map<String, dynamic>.from(user ?? {});
      current['seller'] = {...J.map(current['seller']), ...status.dataMap};
      user = current;
      await _prefs.setString('user_json', jsonEncode(user));
    }
    final set = await api.settings();
    if (set.ok) settings = set.dataMap;
    await refreshDashboard();
  }

  Future<void> logout() async {
    token = null;
    user = null;
    dashboard = {};
    settings = {};
    api.setToken(null);
    await _prefs.remove('token');
    await _prefs.remove('user_json');
    notifyListeners();
  }

  Future<void> setApiUrl(String url) async {
    final value = url.trim();
    apiUrl = value.isEmpty ? AppConfig.defaultApiUrl : value;
    await _prefs.setString('api_url', apiUrl);
    api.setBaseUrl(apiUrl);
    notifyListeners();
  }

  Future<void> persistUser() async {
    if (user != null) {
      await _prefs.setString('user_json', jsonEncode(user));
    }
    notifyListeners();
  }

  Future<void> refreshDashboard() async {
    final result = await api.dashboard();
    dashboardFailed = !result.ok;
    if (result.ok) dashboard = result.dataMap;
    notifyListeners();
  }
}

final app = AppController();