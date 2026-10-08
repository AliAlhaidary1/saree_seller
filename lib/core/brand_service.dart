import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'brand_config.dart';

class BrandService {
  static const _cacheKey = 'platform_brand_v1';

  Future<BrandConfig> load(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    BrandConfig cached = BrandConfig.defaults;
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      try {
        cached = BrandConfig.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
      } catch (_) {}
    }

    try {
      var root = baseUrl.trim();
      if (root.endsWith('/')) root = root.substring(0, root.length - 1);
      final dio = Dio(BaseOptions(
        baseUrl: '$root/customer',
        headers: {'x-access-key': '903361'},
      ));
      final res = await dio.get('/brand');
      final data = res.data is Map ? (res.data['data'] ?? res.data) : null;
      if (data is Map) {
        final brand = BrandConfig.fromJson(Map<String, dynamic>.from(data));
        await prefs.setString(_cacheKey, jsonEncode({
          'version': brand.version,
          'identity': brand.identity,
          'colors': brand.colors,
          'assets': brand.assets,
        }));
        return brand;
      }
    } catch (_) {}

    return cached;
  }
}