import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config.dart';

/// خدمة الإشعارات الفورية للتاجر — تصل حتى والتطبيق مغلق تماماً.
///
/// كيف تصل والجهاز/التطبيق مغلق؟
/// 1) الباكند يرسل عبر FCM v1 رسالة فيها `notification` + `data` بأولوية
///    HIGH — نظام أندرويد يعرضها في الدرج تلقائياً حتى لو التطبيق مقتول.
/// 2) رسائل `data-only` يستقبلها [pushBackgroundHandler] في عزلة خلفية
///    (يُعيد تهيئة Firebase من الإعدادات المخزّنة) ويعرضها محلياً.
/// 3) الضغط على أي إشعار يفتح التطبيق ويوجّه لطلبات التجارة أو تفاصيل
///    الطلب حسب `id` في الحمولة.
///
/// تسجيل التوكن في السيرفر:
/// - عند تسجيل الدخول يُرسل `fcm_token` في `POST login` فيخزّنه السيرفر في
///   `UserToken{type: Seller}` (AdminAuthController@login).
/// - عند تجدد التوكن يُرفع فوراً عبر `POST seller/save_fcm_token`.
/// - عند كل إقلاع يُعاد رفع التوكن المخزّن (يغطي تجدده أثناء الخروج).
///
/// بدون [FirebaseConfig.androidAppId] تبقى الخدمة معطّلة بأمان والتطبيق
/// يعمل طبيعياً (إشعارات محلية للتنبيهات الداخلية فقط).
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  try {
    final ok = await PushService.ensureInitialized();
    if (!ok) return;
    // رسائل الباكند تحمل notification + data معاً: النظام يعرض الدرج
    // تلقائياً، فنتخطى العرض المحلي هنا لمنع إشعار مكرر.
    // رسائل data-only تُعرض محلياً (مهمة والتطبيق مقتول).
    if (message.notification != null) return;
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: android));
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(PushService.channel);
    await PushService.showLocal(plugin, message);
  } catch (_) {}
}

class PushService {
  static const channel = AndroidNotificationChannel(
    'sreamart_seller_orders',
    'طلبات المتجر',
    description: 'إشعارات طلبات التاجر الجديدة',
    importance: Importance.max,
  );

  static const _optionsCacheKey = 'sreamart_seller_firebase_options';
  static const _tokenKey = 'fcm_token';

  static final FlutterLocalNotificationsPlugin local =
      FlutterLocalNotificationsPlugin();

  /// هل الإشعارات الفورية مفعّلة (Firebase مهيأ + إذن الجهاز ممنوح).
  static bool supported = false;
  static bool permissionGranted = false;
  static String? fcmToken;

  static GoRouter? _router;
  static String? _pendingLocation;
  static bool _listenersAttached = false;

  /// يُستدعى عند تجدد توكن FCM — يربطه الكنترولر لرفعه للسيرفر فوراً.
  static void Function(String token)? onTokenChanged;

  /// تهيئة Firebase من أي مصدر متاح: ملفات المشروع الأصلية، ثم إعدادات
  /// التطبيق، ثم نسخة مخزّنة محلياً (مهمة لعزلة الخلفية). آمنة دائماً.
  static Future<bool> ensureInitialized() async {
    try {
      if (Firebase.apps.isNotEmpty) return true;
      // 1) ملفات google-services الأصلية إن وُجدت.
      try {
        await Firebase.initializeApp();
        await _cacheOptions(FirebaseConfig.toCacheMap());
        return true;
      } catch (_) {}
      // 2) إعدادات التطبيق الصريحة.
      if (FirebaseConfig.isConfigured) {
        try {
          await Firebase.initializeApp(options: FirebaseConfig.options);
          await _cacheOptions(FirebaseConfig.toCacheMap());
          return true;
        } catch (_) {}
      }
      // 3) نسخة مخزّنة من تهيئة سابقة ناجحة (عزلة الخلفية).
      final cached = await _cachedOptions();
      if (cached != null) {
        try {
          await Firebase.initializeApp(options: cached);
          return true;
        } catch (_) {}
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _cacheOptions(Map<String, String> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_optionsCacheKey, jsonEncode(map));
    } catch (_) {}
  }

  static Future<FirebaseOptions?> _cachedOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_optionsCacheKey);
      if (raw == null || raw.isEmpty) return null;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      String pick(String k) {
        final v = map[k];
        return (v == null || '$v'.isEmpty || '$v' == 'null') ? '' : '$v';
      }

      final apiKey = pick('apiKey');
      final appId = pick('appId');
      final senderId = pick('messagingSenderId');
      final projectId = pick('projectId');
      if (apiKey.isEmpty ||
          appId.isEmpty ||
          senderId.isEmpty ||
          projectId.isEmpty) {
        return null;
      }
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        storageBucket: pick('storageBucket').isNotEmpty
            ? pick('storageBucket')
            : null,
        authDomain:
            pick('authDomain').isNotEmpty ? pick('authDomain') : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// يُستدعى من main() قبل runApp — آمن دائماً ولا يرمي استثناء.
  /// يهيئ الإشعارات المحلية والقناة دائماً، وFCM عند توفر الإعداد.
  static Future<void> preInit() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await local.initialize(
        const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (resp) =>
            _onTapPayload(resp.payload),
      );
      final androidImpl = local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(channel);
      // إذن نظام أندرويد 13+ (POST_NOTIFICATIONS) — بدونه لا يظهر شيء.
      try {
        final granted =
            await androidImpl?.requestNotificationsPermission() ?? false;
        if (granted) permissionGranted = true;
      } catch (_) {}
    } catch (_) {
      // الإشعارات المحلية غير حرجة — نتابع بدونها
    }

    // تسجيل معالج الخلفية مبكراً دائماً (يعمل عند توفر الإعداد فقط).
    try {
      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
    } catch (_) {}

    await ensureFcm();
  }

  /// تهيئة FCM كاملة: تهيئة + إذن + توكن + مستمعون. تُستدعى من preInit
  /// وتُعاد بعد تسجيل الدخول (قد تتوفر الشبكة/الإعداد حينها).
  /// ترجع true عند تفعيل الإشعارات الفورية فعلاً.
  static Future<bool> ensureFcm() async {
    final ok = await ensureInitialized();
    if (!ok) {
      supported = false;
      return false;
    }
    try {
      // إظهار إشعارات المقدمة على iOS (غير ضار على أندرويد).
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        await _persistToken(fcmToken);
      } catch (_) {}

      try {
        FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
          fcmToken = t;
          await _persistToken(t);
          try {
            onTokenChanged?.call(t);
          } catch (_) {}
        });
      } catch (_) {}

      if (!_listenersAttached) {
        _listenersAttached = true;
        try {
          FirebaseMessaging.onMessage.listen((m) => showLocal(local, m));
        } catch (_) {}
        try {
          FirebaseMessaging.onMessageOpenedApp.listen(
            (m) => routeMessage(m.data),
          );
        } catch (_) {}
      }
      supported = true;
      return true;
    } catch (_) {
      supported = false;
      return false;
    }
  }

  /// يُستدعى بعد بناء الراوتر (بعد bootstrap) لتصريف ضغطات الإشعارات.
  static void attachRouter(GoRouter router) {
    _router = router;
    if (_pendingLocation != null) {
      final loc = _pendingLocation!;
      _pendingLocation = null;
      try {
        router.push(loc);
      } catch (_) {
        _pendingLocation = loc;
      }
    }
    _drainTerminatedLocalTap();
    _drainInitialMessage();
  }

  /// ضغطة إشعار محلي والتطبيق مقتول تماماً: الـ callback لا يعمل حينها،
  /// فنقرأ تفاصيل الإطلاق ونوجّه حسب الـ payload المخزّن.
  static Future<void> _drainTerminatedLocalTap() async {
    try {
      final details = await local.getNotificationAppLaunchDetails();
      final launched = details?.didNotificationLaunchApp ?? false;
      final payload = details?.notificationResponse?.payload;
      if (launched && payload != null && payload.isNotEmpty) {
        _onTapPayload(payload);
      }
    } catch (_) {}
  }

  static Future<void> _drainInitialMessage() async {
    if (!supported) {
      // بدون FCM قد يكون الفتح من إشعار نظام لرسالة notification —
      // getInitialMessage يتطلب تهيئة، نحاول بأمان.
      try {
        if (Firebase.apps.isEmpty) return;
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) routeMessage(initial.data);
      } catch (_) {}
      return;
    }
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) routeMessage(initial.data);
    } catch (_) {}
  }

  static Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {}
  }

  /// التوكن المُرسل مع تسجيل الدخول (يُخزّن في UserToken بالسيرفر).
  static Future<String?> getStoredToken() async {
    if (fcmToken != null && fcmToken!.isNotEmpty) return fcmToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(_tokenKey);
      if (t != null && t.isNotEmpty) {
        fcmToken = t;
        return t;
      }
    } catch (_) {}
    return null;
  }

  /// إعادة طلب إذن الإشعارات (تُستخدم من زر "إشعارات الجهاز" في حسابي).
  static Future<bool> requestPermission() async {
    var localGranted = permissionGranted;
    try {
      localGranted = await local
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          localGranted;
    } catch (_) {}
    if (!supported) {
      // بدون إعداد Firebase نحاول التهيئة أولاً (قد يكون أُضيف للتو).
      await ensureFcm();
      if (!supported) {
        permissionGranted = localGranted;
        return localGranted;
      }
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final fcmGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      permissionGranted = localGranted && fcmGranted;
      return permissionGranted;
    } catch (_) {
      permissionGranted = localGranted;
      return localGranted;
    }
  }

  static String get statusText {
    if (!FirebaseConfig.isConfigured && !supported) {
      return 'غير مهيأة بعد — أضف Android appId من Firebase Console';
    }
    if (!supported) return 'تعذّر التهيئة — تحقق من الإنترنت والإعداد';
    return permissionGranted ? 'مفعّلة — تصلك حتى والتطبيق مغلق' : 'معطّلة من الجهاز';
  }

  /// يعرض إشعاراً محلياً من رسالة FCM (واجهة أمامية أو خلفية data-only).
  /// الحمولة JSON كاملة في payload ليوجّه الضغط للتفاصيل حتى من مقتول.
  static Future<void> showLocal(
    FlutterLocalNotificationsPlugin plugin,
    RemoteMessage message,
  ) async {
    final d = message.data;
    final title = _str(d['title']) ??
        message.notification?.title ??
        'طلب جديد في متجرك!';
    final body = _str(d['message']) ??
        _str(d['body']) ??
        message.notification?.body ??
        'لديك نشاط جديد في المتجر';
    final id = _str(d['id']) ?? '';
    final type = (_str(d['type']) ?? '').toLowerCase();
    String payload;
    if (id.isNotEmpty && id != '0' && int.tryParse(id) != null) {
      payload = jsonEncode({'type': type, 'id': id});
    } else {
      payload = jsonEncode({'type': type});
    }
    try {
      await plugin.show(
        // id ثابت نسبياً لكل طلب حتى يُحدَّث بدل التكدس.
        id.isNotEmpty && id != '0'
            ? (int.tryParse(id) ?? DateTime.now().millisecondsSinceEpoch ~/ 1000)
            : DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'sreamart_seller_orders',
            'طلبات المتجر',
            channelDescription: 'إشعارات طلبات التاجر الجديدة',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  static void _onTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      _go('/seller-orders');
      return;
    }
    // صيغة قديمة: order:<id> أو orders
    if (payload.startsWith('order:')) {
      final id = payload.substring('order:'.length).trim();
      if (id.isNotEmpty && id != '0') {
        _go('/seller-orders/$id');
        return;
      }
      _go('/seller-orders');
      return;
    }
    if (payload == 'orders') {
      _go('/seller-orders');
      return;
    }
    // صيغة JSON الجديدة من showLocal.
    try {
      final map = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      _go(_routeFromData(map));
      return;
    } catch (_) {}
    _go('/seller-orders');
  }

  /// توجيه رسالة FCM مفتوحة: id موجود → تفاصيل الطلب، وإلا → الطلبات.
  /// طلبات new_order تحمل id الطلب (الباكند يرسله) فتفتح التفاصيل مباشرة.
  static void routeMessage(Map<String, dynamic> data) => _go(_routeFromData(data));

  static String _routeFromData(Map data) {
    final id = '${data['id'] ?? ''}'.trim();
    if (id.isNotEmpty && id != '0' && int.tryParse(id) != null) {
      return '/seller-orders/$id';
    }
    return '/seller-orders';
  }

  static void _go(String location) {
    final router = _router;
    if (router == null) {
      _pendingLocation = location;
      return;
    }
    try {
      router.push(location);
    } catch (_) {
      _pendingLocation = location;
    }
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }
}
