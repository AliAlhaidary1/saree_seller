import 'package:dio/dio.dart';

import 'config.dart';
import 'json_util.dart';

class PanelApi {
  PanelApi({required String baseUrl, String? token}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _normalize(baseUrl),
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 40),
        headers: const {
          'Accept': 'application/json',
          'platform': 'android',
        },
        validateStatus: (code) => code != null && code < 600,
      ),
    );
    setToken(token);
  }

  late final Dio _dio;
  void Function()? onUnauthorized;

  static String _normalize(String url) {
    var root = url.trim();
    if (root.endsWith('/')) root = root.substring(0, root.length - 1);
    return '$root${AppConfig.apiSubUrl}/';
  }

  void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  void setBaseUrl(String url) => _dio.options.baseUrl = _normalize(url);

  ApiResult _parse(Response response) {
    final data = response.data;
    if (data is Map) return ApiResult(J.map(data));
    return ApiResult({
      'status': 0,
      'message': 'invalid_response',
      'data': data,
    });
  }

  String _httpErrorMessage(Response? response, [String? fallback]) {
    if (response?.data is Map) {
      final msg = ApiResult(J.map(response!.data)).message;
      if (msg.isNotEmpty && msg != 'invalid_response') return msg;
    }
    final code = response?.statusCode;
    if (code != null && code >= 500) {
      return 'خطأ في الخادم ($code). حاول لاحقاً أو تواصل مع الدعم.';
    }
    return fallback ?? 'تعذر التحميل. تحقق من الإنترنت.';
  }

  Future<ApiResult> _guard(Future<Response> Function() request) async {
    try {
      final response = await request();
      if (response.statusCode == 401) {
        onUnauthorized?.call();
        return ApiResult({
          'status': 0,
          'message': 'انتهت الجلسة. سجّل الدخول مجدداً.',
        });
      }
      if (response.statusCode != null && response.statusCode! >= 500) {
        return ApiResult({
          'status': 0,
          'message': _httpErrorMessage(response),
        });
      }
      return _parse(response);
    } on DioException catch (error) {
      final offline =
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
      if (offline) {
        return ApiResult({
          'status': 0,
          'message': 'تعذر الاتصال بالخادم. تحقق من الإنترنت.',
        });
      }
      if (error.type == DioExceptionType.badResponse) {
        return ApiResult({
          'status': 0,
          'message': _httpErrorMessage(error.response, error.message),
        });
      }
      return ApiResult({
        'status': 0,
        'message': error.message ?? 'حدث خطأ ما',
      });
    } catch (error) {
      return ApiResult({'status': 0, 'message': '$error'});
    }
  }

  Future<ApiResult> get(String path, [Map<String, dynamic>? query]) {
    return _guard(() => _dio.get(path, queryParameters: query));
  }

  Future<ApiResult> post(String path, [Map<String, dynamic>? body]) {
    return _guard(() => _dio.post(path, data: body ?? {}));
  }

  Future<ApiResult> postForm(String path, FormData data) {
    return _guard(() => _dio.post(path, data: data));
  }

  Future<ApiResult> login(String email, String password) {
    return post('login', {
      'email': email,
      'password': password,
      'type': AppConfig.loginType,
      'platform': 'android',
    });
  }

  Future<ApiResult> forgotPasswordOtp(String mobile) {
    return post('forget-password-otp', {
      'mobile': mobile,
      'country_code': AppConfig.countryDialCode,
      'type': AppConfig.loginType,
    });
  }

  Future<ApiResult> resetPasswordOtp({
    required String mobile,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) {
    return post('reset-password-otp', {
      'mobile': mobile,
      'country_code': AppConfig.countryDialCode,
      'otp': otp,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'type': AppConfig.loginType,
    });
  }

  Future<ApiResult> dashboard() => get('seller/dashboard');
  Future<ApiResult> status() => get('seller/status');
  Future<ApiResult> orders({
    int limit = 30,
    int offset = 0,
    String search = '',
    int? statusId,
  }) {
    return get('seller/orders', {
      'limit': limit,
      'offset': offset,
      if (search.isNotEmpty) 'search': search,
      if (statusId != null && statusId > 0) 'status': statusId,
    });
  }

  Future<ApiResult> orderById(dynamic id) =>
      get('seller/order_by_id', {'id': id, 'order_id': id});
  Future<ApiResult> orderStatuses() => get('seller/order_statuses');
  Future<ApiResult> updateStatus({
    required dynamic orderId,
    required dynamic statusId,
    dynamic deliveryBoyId,
  }) {
    return post('seller/update_status', {
      'order_id': orderId,
      'status_id': statusId,
      if (deliveryBoyId != null) 'delivery_boy_id': deliveryBoyId,
    });
  }

  Future<ApiResult> assignDelivery({
    required dynamic orderId,
    required dynamic deliveryBoyId,
  }) {
    return post('seller/assign_delivery_boy', {
      'order_id': orderId,
      'delivery_boy_id': deliveryBoyId,
    });
  }

  Future<ApiResult> products({
    int limit = 50,
    int offset = 0,
    String search = '',
    dynamic sellerId,
  }) async {
    final query = {
      'limit': limit,
      'offset': offset,
      if (search.isNotEmpty) 'search': search,
      if (sellerId != null) 'seller_id': sellerId,
    };
    final result = await get('seller/get_products', query);
    if (result.ok) return result;
    final fallback = await get('seller/products', query);
    return fallback.ok ? fallback : result;
  }

  Future<ApiResult> productById(dynamic id) =>
      get('seller/products/product_by_id', {'id': id, 'product_id': id});
  Future<ApiResult> saveProductForm(FormData data) =>
      postForm('seller/products/save', data);
  Future<ApiResult> updateProductForm(FormData data) =>
      postForm('seller/products/update', data);
  Future<ApiResult> deleteProduct(dynamic id) =>
      post('seller/products/delete', {'id': id});
  Future<ApiResult> bulkUpload(FormData data) =>
      postForm('products/bulk_upload', data);
  Future<ApiResult> productRatings({dynamic productId}) {
    return get('seller/products/ratings_list', {
      'include_hidden': 1,
      'limit': 50,
      if (productId != null) 'product_id': productId,
    });
  }

  Future<ApiResult> updateRatingStatus({
    required dynamic id,
    required int status,
  }) {
    return post('seller/products/ratings/update-status', {
      'id': id,
      'status': status,
    });
  }

  Future<ApiResult> deleteRating(dynamic id) =>
      post('seller/products/ratings/delete', {'id': id});

  Future<ApiResult> categories() => get('seller/seller_categories');
  Future<ApiResult> sellerSections({bool activeOnly = true}) => get('seller/seller_sections', {
        if (activeOnly) 'active_only': 1,
      });
  Future<ApiResult> deliveryBoys() => get('seller/delivery_boys');
  Future<ApiResult> settings() => get('seller/settings');
  Future<ApiResult> privacyPolicy() => get('seller/privacy_policy');
  Future<ApiResult> saveSellerDetails(FormData data) =>
      postForm('seller/saveSellerDetails', data);
  Future<ApiResult> accounting({String startDate = '', String endDate = ''}) {
    return get('seller/accounting', {
      if (startDate.isNotEmpty) 'startDate': startDate,
      if (endDate.isNotEmpty) 'endDate': endDate,
    });
  }

  Future<ApiResult> wallet() => get('seller/seller_wallet_transactions');
  Future<ApiResult> withdrawals() => get('seller/withdrawal_requests');
  Future<ApiResult> salesReports({
    required String startDate,
    required String endDate,
    String category = '',
  }) {
    return get('seller/sales_reports', {
      'startDate': startDate,
      'endDate': endDate,
      if (category.isNotEmpty) 'category': category,
    });
  }

  Future<ApiResult> productSalesReports({
    required String startDate,
    required String endDate,
  }) {
    return get('seller/product_sales_reports', {
      'startDate': startDate,
      'endDate': endDate,
    });
  }

  Future<ApiResult> returnRequests() => get('seller/return_requests');
  Future<ApiResult> updateReturn({
    required dynamic id,
    required int status,
    String remark = '',
    dynamic deliveryBoyId,
  }) {
    return post('return_requests/update', {
      'id': id,
      'status': status,
      'remark': remark,
      if (deliveryBoyId != null) 'delivery_boy_id': deliveryBoyId,
    });
  }

  Future<ApiResult> units() => get('seller/units');
  Future<ApiResult> saveUnit(Map<String, dynamic> body) =>
      post('seller/units/save', body);
  Future<ApiResult> updateUnit(Map<String, dynamic> body) =>
      post('seller/units/update', body);
  Future<ApiResult> deleteUnit(dynamic id) =>
      post('seller/units/delete', {'id': id});

  Future<ApiResult> taxes() => get('seller/taxes');
  Future<ApiResult> saveTax(Map<String, dynamic> body) =>
      post('seller/taxes/save', body);
  Future<ApiResult> updateTax(Map<String, dynamic> body) =>
      post('seller/taxes/update', body);
  Future<ApiResult> deleteTax(dynamic id) =>
      post('seller/taxes/delete', {'id': id});

  Future<ApiResult> brands() => get('seller/brands');
  Future<ApiResult> saveBrand(FormData data) =>
      postForm('products/brands/save', data);
  Future<ApiResult> updateBrand(FormData data) =>
      postForm('products/brands/update', data);
  Future<ApiResult> deleteBrand(dynamic id) =>
      post('products/brands/delete', {'id': id});

  Future<ApiResult> media() => get('media');
  Future<ApiResult> saveMedia(FormData data) => postForm('media/save', data);
  Future<ApiResult> deleteMedia(dynamic id) =>
      post('media/delete', {'id': id});

  Future<ApiResult> weeklySales() => get('seller/orders/weekly_sales');
  Future<ApiResult> addWithdrawal({
    required String amount,
    String message = '',
  }) {
    return post('seller/withdrawal_requests/add', {
      'amount': amount,
      'message': message,
      'type': 'seller',
      'device_type': 'android',
    });
  }

  Future<ApiResult> promoCodes() => get('seller/promo_code', {'mine': 1});
  Future<ApiResult> savePromo(FormData data) =>
      postForm('seller/promo_code/save', data);
  Future<ApiResult> updatePromo(FormData data) =>
      postForm('seller/promo_code/update', data);
  Future<ApiResult> deletePromo(dynamic id) =>
      post('seller/promo_code/delete', {'id': id});

  Future<ApiResult> flashSales() => get('seller/flash_sales', {'mine': 1});
  Future<ApiResult> saveFlash(FormData data) =>
      postForm('seller/flash_sales/save', data);
  Future<ApiResult> updateFlash(FormData data) =>
      postForm('seller/flash_sales/update', data);
  Future<ApiResult> deleteFlash(dynamic id) =>
      post('seller/flash_sales/delete', {'id': id});

  Future<ApiResult> bxgyOffers() => get('seller/bxgy_offers', {'mine': 1});
  Future<ApiResult> saveBxgy(Map<String, dynamic> body) =>
      post('seller/bxgy_offers/save', body);
  Future<ApiResult> updateBxgy(Map<String, dynamic> body) =>
      post('seller/bxgy_offers/update', body);
  Future<ApiResult> deleteBxgy(dynamic id) =>
      post('seller/bxgy_offers/delete', {'id': id});

  Future<ApiResult> categoryDiscounts() =>
      get('seller/category_discounts', {'mine': 1});
  Future<ApiResult> saveCategoryDiscount(Map<String, dynamic> body) =>
      post('seller/category_discounts/save', body);
  Future<ApiResult> updateCategoryDiscount(Map<String, dynamic> body) =>
      post('seller/category_discounts/update', body);
  Future<ApiResult> deleteCategoryDiscount(dynamic id) =>
      post('seller/category_discounts/delete', {'id': id});

  Future<ApiResult> mailSettings() => get('seller/mail_settings');
  Future<ApiResult> saveMailSettings(Map<String, dynamic> body) =>
      post('seller/mail_settings/save', body);
  Future<ApiResult> deleteAccount() => get('seller/delete_seller_account');
  Future<ApiResult> cities() => get('seller/cities');
  Future<ApiResult> sellerCategoriesPublic() => get('seller/categories');
  Future<ApiResult> register(FormData data) => postForm('seller/register', data);
}
