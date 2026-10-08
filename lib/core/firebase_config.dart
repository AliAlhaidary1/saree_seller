import 'package:firebase_core/firebase_core.dart';

/// إعدادات Firebase لمشروع saree-market.
///
/// لاستقبال الإشعارات والتطبيق **مغلق تماماً** يلزم سطر واحد فقط:
/// 1) Firebase Console ← مشروع saree-market ← Add app ← Android.
/// 2) سجّل package name: `com.saree.saree_seller`.
/// 3) انسخ قيمة appId التي تظهر بشكل `1:615854672127:android:XXXXXXXX`
///    والصقها في [androidAppId] أدناه ثم أعد بناء التطبيق.
///
/// لا حاجة لملف `google-services.json` ولا لإضافات Gradle — التهيئة تتم
/// برمجياً من هذه القيم، وتُحفظ نسخة في التخزين المحلي لتعمل حتى في
/// عزلة الخلفية (التطبيق مقتول) قبل أي تسجيل دخول.
class FirebaseConfig {
  static const String apiKey = 'AIzaSyCwH0a0pbRT2hqu_z-BHlJLzqYOUaDR4zM';

  /// Web appId (للباكند/الويب — لا يعمل على أندرويد).
  static const String appId = '1:615854672127:web:596f455d7a2b93c2b824ca';

  /// ⬅️ الصق هنا Android appId من Firebase Console (إلزامي للإشعارات).
  static const String androidAppId = '';

  static const String messagingSenderId = '615854672127';
  static const String projectId = 'saree-market';
  static const String storageBucket = 'saree-market.firebasestorage.app';
  static const String authDomain = 'saree-market.firebaseapp.com';

  /// الـ appId الفعّال على أندرويد: الخاص بالأندرويد إن وُجد.
  static String get effectiveAppId =>
      androidAppId.isNotEmpty ? androidAppId : '';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      effectiveAppId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: effectiveAppId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket,
        authDomain: authDomain,
      );

  static Map<String, String> toCacheMap() => {
        'apiKey': apiKey,
        'appId': effectiveAppId,
        'messagingSenderId': messagingSenderId,
        'projectId': projectId,
        'storageBucket': storageBucket,
        'authDomain': authDomain,
      };
}
