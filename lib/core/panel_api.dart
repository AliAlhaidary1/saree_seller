import 'package:dio/dio.dart';

import 'config.dart';
import 'json_util.dart';
import 'api_errors.dart';

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

  Future<ApiResult> _guard(
    Future<Response> Function() request, {
    String path = '',
    String method = 'GET',
  }) async {
    final release = ApiErrorPolicy.current.release;
    final kind = inferRequestKind(path, method: method);
    var attempt = 0;
    while (true) {
      try {
        final response = await request();
        if (response.statusCode == 401) {
          onUnauthorized?.call();
        }
        if (response.statusCode == 401 ||
            (response.statusCode != null && response.statusCode! >= 500) ||
            looksLikeLaravelException(response.data)) {
          final classified = classifyDio(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
            ),
            release: release,
          );
          logApiFailure(classified, path: path);
          return ApiResult(classified.toResultMap());
        }
        return _parse(response);
      } on DioException catch (error) {
        final classified = classifyDio(error, release: release);
        logApiFailure(classified, path: path);
        if (shouldRetryApi(
          error: classified,
          attempt: attempt,
          kind: kind,
          release: release,
        )) {
          attempt += 1;
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
        return ApiResult(classified.toResultMap());
      } catch (error) {
        final classified = classifyUnknown(error, release: release);
        logApiFailure(classified, path: path);
        return ApiResult(classified.toResultMap());
      }
    }
  }

  Future<ApiResult> get(String path, [Map<String, dynamic>? query]) {
    return _guard(() => _dio.get(path, queryParameters: query), path: path, method: 'GET');
  }

  Future<ApiResult> post(String path, [Map<String, dynamic>? body]) {
    return _guard(() => _dio.post(path, data: body ?? {}), path: path, method: 'POST');
  }

  Future<ApiResult> postForm(String path, FormData data) {
    return _guard(() => _dio.post(path, data: data), path: path, method: 'POST');
  }

  // الباكند (AdminAuth@login) يخزّن fcm_token في UserToken{type: Seller}
  // ليصل إشعار الطلب للجهاز حتى والتطبيق مغلق.
  Future<ApiResult> login(String email, String password, {String? fcmToken}) {
    return post('login', {
      'email': email,
      'password': password,
      'type': AppConfig.loginType,
      'platform': 'android',
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
    });
  }

  // تحديث توكن الدفع بعد تجدده أو عند الإقلاع.
  // المسار الأساسي seller/save_fcm_token يخزّن في UserToken{type:Seller}
  // (الذي يقرأ منه الباكند عند إشعار الطلبات) — والقديم احتياطي.
  Future<ApiResult> saveFcmToken(String token) =>
      post('save_fcm_token', {'token': token});

  Future<ApiResult> saveSellerFcmToken(String token) => post(
        'seller/save_fcm_token',
        {'token': token, 'fcm_token': token, 'platform': 'android'},
      );

  Future<ApiResult> forgotPasswordOtp(String mobile) {
    return post('forget-password-otp', {
      'mobile': mobile,
      'country_code': AppConfig.countryDialCode,
      'type': AppConfig.loginType,
    });
  }

  // مطابق OtpApiController: إرسال/تحقق OTP للتسجيل (purpose=register, type=3)
  Future<ApiResult> sendRegisterOtp(String mobile) {
    return post('otp/send', {
      'mobile': mobile,
      'country_code': AppConfig.countryDialCode,
      'purpose': 'register',
      'type': AppConfig.loginType,
    });
  }

  Future<ApiResult> verifyOtp(String mobile, String otp) {
    return post('otp/verify', {
      'mobile': mobile,
      'otp': otp,
      'country_code': AppConfig.countryDialCode,
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
  // مطابق SellerController@getOrders: كل فلاتر الباكند
  Future<ApiResult> orders({
    int limit = 30,
    int offset = 0,
    String search = '',
    int? statusId,
    String startDate = '',
    String endDate = '',
    String startDeliveryDate = '',
    String endDeliveryDate = '',
    int itemLimit = 0,
    int itemOffset = 0,
  }) {
    return get('seller/orders', {
      'limit': limit,
      'offset': offset,
      if (search.isNotEmpty) 'search': search,
      if (statusId != null && statusId > 0) 'status': statusId,
      if (startDate.isNotEmpty) 'startDate': startDate,
      if (endDate.isNotEmpty) 'endDate': endDate,
      if (startDeliveryDate.isNotEmpty) 'startDeliveryDate': startDeliveryDate,
      if (endDeliveryDate.isNotEmpty) 'endDeliveryDate': endDeliveryDate,
      if (itemLimit > 0) 'item_limit': itemLimit,
      if (itemOffset > 0) 'item_offset': itemOffset,
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

  // ملاحظة باكند: لا يوجد مسار seller لتعيين المندوب إطلاقاً، ومسار الإدارة
  // orders/assign_delivery_boy إداري فقط (CommerceAuthorizationService).
  // تعيين المندوب يتم من الإدارة — الواجهة تعرض المناديب للاطلاع فقط.
  Future<ApiResult> deliveryBoys({int limit = 100, int offset = 0}) =>
      get('seller/delivery_boys', {'limit': limit, 'offset': offset});

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
  // Web parity (ProductInfo.vue): toggle availability from stock alerts
  Future<ApiResult> changeProductStatus(dynamic id) =>
      post('products/change', {'id': id});
  Future<ApiResult> bulkUpload(FormData data) async {
    final r = await postForm('seller/products/simple_bulk_upload', data);
    if (r.ok) return r;
    return postForm('products/bulk_upload', data);
  }
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
  Future<ApiResult> saveCategory(FormData data) =>
      postForm('categories/save', data);
  Future<ApiResult> updateCategory(FormData data) =>
      postForm('categories/update', data);
  Future<ApiResult> deleteCategory(dynamic id) =>
      _guard(() => _dio.delete('categories/$id'), path: 'categories/$id', method: 'DELETE');
  Future<ApiResult> sellerSections({bool activeOnly = true}) => get('seller/seller_sections', {
        if (activeOnly) 'active_only': 1,
      });
  Future<ApiResult> settings() => get('seller/settings');
  Future<ApiResult> privacyPolicy() => get('seller/privacy_policy');
  Future<ApiResult> saveSellerDetails(FormData data) =>
      postForm('seller/saveSellerDetails', data);
  // مطابق SellerAccountingApiController: period=today|week|month|custom
  Future<ApiResult> accounting({String startDate = '', String endDate = '', String period = ''}) {
    return get('seller/accounting', {
      if (period.isNotEmpty) 'period': period,
      if (startDate.isNotEmpty) 'startDate': startDate,
      if (endDate.isNotEmpty) 'endDate': endDate,
    });
  }

  // مطابق SellerWalletTransactionsApiController: limit/offset/search
  Future<ApiResult> wallet({int limit = 12, int offset = 0, String search = ''}) => get('seller/seller_wallet_transactions', {
        'limit': limit,
        'offset': offset,
        if (search.isNotEmpty) 'search': search,
      });
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
  Future<ApiResult> businessHours() => get('seller/business_hours');
  Future<ApiResult> saveBusinessHours({required String openingTime, required String closingTime}) =>
      post('seller/business_hours', {
        'opening_time': openingTime,
        'closing_time': closingTime,
      });
  Future<ApiResult> changePassword(Map<String, dynamic> body) =>
      post('system_users/change_password', body);
  Future<ApiResult> deleteAccount({
    required String password,
    String confirmation = 'DELETE',
  }) =>
      post('seller/delete_seller_account', {
        'confirmation': confirmation,
        'password': password,
      });
  Future<ApiResult> cities() => get('seller/cities');
  Future<ApiResult> city(dynamic id) => get('seller/city', {'id': id});
  Future<ApiResult> countries() => get('seller/countries');
  Future<ApiResult> mainCategories({dynamic categoryId, String search = ''}) => get('seller/main_categories', {
        if (categoryId != null) 'category_id': categoryId,
        if (search.isNotEmpty) 'search': search,
      });
  Future<ApiResult> categoriesProductCount() =>
      get('seller/categories/product_count');
  // مطابق SellerController@getProducts: type=sold_out|low_stock|packet_products|loose_products
  Future<ApiResult> productInfo({String type = '', int limit = 20, int offset = 0}) => get('seller/products/product_info', {
        if (type.isNotEmpty) 'type': type,
        'limit': limit,
        'offset': offset,
      });
  Future<ApiResult> sellerCategoriesPublic() => get('seller/categories');
  Future<ApiResult> register(FormData data) => postForm('seller/register', data);
  Future<ApiResult> checkStoreName(String name) =>
      get('seller/check-store-name', {'store_name': name});
  Future<ApiResult> checkName(String name) =>
      get('seller/check-name', {'name': name});

  // --- Products extras matching routes/api.php seller/products ---
  Future<ApiResult> productsOffers() => get('seller/products/offers');
  Future<ApiResult> activeProducts() => get('seller/products/active');
  Future<ApiResult> productEdit(dynamic id) => get('seller/products/edit/$id');
  Future<ApiResult> productTags(String q) =>
      get('seller/products/tags', {'q': q, 'search': q});
  Future<ApiResult> productBrandsIndex() => get('seller/products/brands');
  Future<ApiResult> productTaxesIndex() => get('seller/products/taxes');
  Future<ApiResult> deleteProductsBulk(List<dynamic> ids) =>
      post('seller/products/multiple_delete', {'ids': ids});
  Future<ApiResult> simpleBulkUpload(FormData data) =>
      postForm('seller/products/simple_bulk_upload', data);

  // --- SellerOrders new commerce system (مطابق seller/orders/page.jsx) ---
  // الباكند: fulfillment_status (أو status)، delivery_status، has_return،
  // search، sort (followup/newest/oldest)، startDate/endDate (+Delivery)؛ ترقيم ثابت 20 + ?page
  Future<ApiResult> sellerOrders({
    String? fulfillmentStatus,
    String? status,
    String? deliveryStatus,
    String? search,
    String sort = '',
    bool hasReturn = false,
    String startDate = '',
    String endDate = '',
    String startDeliveryDate = '',
    String endDeliveryDate = '',
    int page = 1,
  }) =>
      get('seller/seller_orders', {
        if (fulfillmentStatus != null && fulfillmentStatus.isNotEmpty)
          'fulfillment_status': fulfillmentStatus,
        if (status != null && status.isNotEmpty) 'status': status,
        if (deliveryStatus != null && deliveryStatus.isNotEmpty)
          'delivery_status': deliveryStatus,
        if (search != null && search.isNotEmpty) 'search': search,
        if (sort.isNotEmpty) 'sort': sort,
        if (hasReturn) 'has_return': 1,
        if (startDate.isNotEmpty) 'startDate': startDate,
        if (endDate.isNotEmpty) 'endDate': endDate,
        if (startDeliveryDate.isNotEmpty) 'startDeliveryDate': startDeliveryDate,
        if (endDeliveryDate.isNotEmpty) 'endDeliveryDate': endDeliveryDate,
        if (page > 1) 'page': page,
      });
  Future<ApiResult> sellerOrderById(dynamic id) =>
      get('seller/seller_orders/$id');
  Future<ApiResult> sellerOrderFulfillment({
    required dynamic id,
    required String status,
  }) =>
      post('seller/seller_orders/$id/fulfillment', {'status': status});
  Future<ApiResult> sellerOrderCancel({
    required dynamic id,
    String? reason,
  }) =>
      post('seller/seller_orders/$id/cancel', {
        if (reason != null) 'reason': reason,
      });
  // رفض صنف: POST seller/seller_orders/{id}/reject-item {order_item_id*, reason?}
  Future<ApiResult> sellerOrderRejectItem({
    required dynamic id,
    required dynamic orderItemId,
    String? reason,
  }) =>
      post('seller/seller_orders/$id/reject-item', {
        'order_item_id': orderItemId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  // --- Accounting exports ---
  Future<ApiResult> accountingExportExcel(
          {String startDate = '', String endDate = ''}) =>
      get('seller/accounting/export_excel', {
        if (startDate.isNotEmpty) 'startDate': startDate,
        if (endDate.isNotEmpty) 'endDate': endDate,
      });
  Future<ApiResult> accountingExportInvoices(
          {String startDate = '', String endDate = ''}) =>
      get('seller/accounting/export_invoices', {
        if (startDate.isNotEmpty) 'startDate': startDate,
        if (endDate.isNotEmpty) 'endDate': endDate,
      });

  // --- Withdrawals extras ---
  Future<ApiResult> getWithdrawals() => get('seller/withdrawal_requests/get');
  Future<ApiResult> getWithdrawalBalance() =>
      get('seller/withdrawal_requests/get_balance');
  Future<ApiResult> updateWithdrawal(
          {required dynamic id, required dynamic status}) =>
      post('seller/withdrawal_requests/update',
          {'id': id, 'status': status});
  Future<ApiResult> deleteWithdrawal(dynamic id) =>
      post('seller/withdrawal_requests/delete', {'id': id});

  // --- Campaigns (seller/campaigns) ---
  // الباكند: index يدعم status فقط (لا search) + نطاق البائع تلقائي.
  Future<ApiResult> campaignsMeta() => get('seller/campaigns/meta');
  Future<ApiResult> campaigns({String status = ''}) =>
      get('seller/campaigns', {if (status.isNotEmpty) 'status': status});
  Future<ApiResult> campaignShow(dynamic id) =>
      get('seller/campaigns/show/$id');
  Future<ApiResult> campaignAnalytics(dynamic id) =>
      get('seller/campaigns/analytics/$id');
  Future<ApiResult> saveCampaign(Map<String, dynamic> body) =>
      post('seller/campaigns/save', body);
  Future<ApiResult> updateCampaign(Map<String, dynamic> body) =>
      post('seller/campaigns/update', body);
  Future<ApiResult> deleteCampaign(dynamic id) =>
      post('seller/campaigns/delete', {'id': id});
  Future<ApiResult> duplicateCampaign(dynamic id) =>
      post('seller/campaigns/duplicate', {'id': id});
  // set_status يقبل نصوص STATUSES فقط (draft/scheduled/active/paused/expired/archived).
  Future<ApiResult> setCampaignStatus(
          {required dynamic id, required String status}) =>
      post('seller/campaigns/set_status', {'id': id, 'status': status});
  // attach/detach يتطلبان type (من ATTACHMENT_MAP) + id — لا product_id/category_id.
  Future<ApiResult> attachCampaign({
    required dynamic campaignId,
    required String type,
    required dynamic id,
    int? sortOrder,
  }) =>
      post('seller/campaigns/attach', {
        'campaign_id': campaignId,
        'type': type,
        'id': id,
        if (sortOrder != null) 'sort_order': sortOrder,
      });
  Future<ApiResult> detachCampaign({
    required dynamic campaignId,
    required String type,
    required dynamic id,
  }) =>
      post('seller/campaigns/detach', {
        'campaign_id': campaignId,
        'type': type,
        'id': id,
      });

  // --- Storefront (seller/storefront) ---
  Future<ApiResult> storefrontTemplates() => get('seller/storefront/templates');
  Future<ApiResult> myStorefront() => get('seller/storefront/me');
  Future<ApiResult> applyStorefrontTemplate(dynamic templateId) =>
      post('seller/storefront/apply-template', {'template_id': templateId});
  Future<ApiResult> saveStorefrontPage(Map<String, dynamic> body) =>
      post('seller/storefront/page/save', body);
  Future<ApiResult> saveStorefrontAppearance(Map<String, dynamic> body) =>
      post('seller/storefront/appearance', {'settings': body});
  // مطابق publishStorefront: is_published + subdomain_enabled
  Future<ApiResult> publishStorefront({bool isPublished = true, bool? subdomainEnabled}) => post('seller/storefront/publish', {
        'is_published': isPublished ? 1 : 0,
        if (subdomainEnabled != null) 'subdomain_enabled': subdomainEnabled ? 1 : 0,
      });
  Future<ApiResult> saveCustomDomain(String domain) =>
      post('seller/storefront/custom-domain', {'custom_domain': domain});
  Future<ApiResult> saveLinkSettings(Map<String, dynamic> body) =>
      post('seller/storefront/link-settings', body);

  // --- Media extras ---
  // الباكند multipleDelete يقرأ ids كنص مفصول بفواصل (explode) — لا مصفوفة.
  Future<ApiResult> deleteMediaBulk(List<dynamic> ids) =>
      post('media/multiple_delete', {'ids': ids.join(',')});

  // --- Seller sections CRUD (مطابق SellerSectionApiController) ---
  Future<ApiResult> saveSellerSection(Map<String, dynamic> body) =>
      post('seller/seller_sections/save', body);
  Future<ApiResult> updateSellerSection(Map<String, dynamic> body) =>
      post('seller/seller_sections/update', body);
  Future<ApiResult> deleteSellerSection(dynamic id) =>
      post('seller/seller_sections/delete', {'id': id});

  // --- Seller commission / wallet helpers ---
  Future<ApiResult> sellerCommission() => get('seller/seller_commission');
  Future<ApiResult> termsConditions() => get('seller-terms-conditions');
  Future<ApiResult> sellerPrivacyPolicy() => get('seller-privacy-policy');
}