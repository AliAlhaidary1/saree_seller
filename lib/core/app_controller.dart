import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'json_util.dart';
import 'panel_api.dart';

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

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  Map<String, dynamic> get seller => J.map(user?['seller']);
  int get sellerStatus => J.i(seller['status']);
  bool get isPending => sellerStatus == 0;
  bool get isRejected => sellerStatus == 2;
  bool get isDeactivated => sellerStatus == 3;
  bool get canWrite => sellerStatus == 1;
  bool get canAssignDelivery =>
      J.flag(seller['assign_delivery_boy'] ?? settings['assign_delivery_boy']);
  Color get brand => const Color(AppConfig.brand);
  Color get accent => const Color(AppConfig.accent);
  String get storeName =>
      J.str(seller['store_name'] ?? user?['store_name'] ?? user?['name'], 'متجري');
  dynamic get sellerId => seller['id'] ?? user?['seller_id'];
  String get supportPhone => J.str(settings['support_number']);
  String get supportEmail => J.str(settings['support_email']);
  bool dashboardFailed = false;

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    apiUrl = AppConfig.defaultApiUrl;
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
    if (isLoggedIn) {
      try {
        await refreshSession();
      } catch (_) {}
    }
    bootstrapped = true;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    final result = await api.login(email.trim(), password);
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
    await refreshSession();
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
