import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';
import 'core/app_controller.dart';
import 'core/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // معالج الخلفية يُسجَّل قبل runApp ليستقبل النظام الرسائل والتطبيق مقتول.
  try {
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
  } catch (_) {}
  // تهيئة الإشعارات (محلية دائماً + FCM عند توفر الإعداد).
  await PushService.preInit();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  GoRouter? router;
  String? error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => error = null);
    try {
      await app.bootstrap();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
      return;
    }
    if (!mounted) return;
    final r = buildRouter();
    // تصريف ضغطات الإشعارات (حتى بعد فتح التطبيق من مغلق)
    PushService.attachRouter(r);
    setState(() => router = r);
  }

  @override
  Widget build(BuildContext context) {
    if (router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0A2540),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/brand/logo.webp',
                    height: 96,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.storefront,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'سريع ماركت',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'تطبيق التاجر',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                if (error == null)
                  const CircularProgressIndicator(color: Color(0xFFFF6B00))
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'تعذر التهيئة: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _boot,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return SellerApp(router: router!);
  }
}