import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';
import 'core/app_controller.dart';
import 'core/push_service.dart';
import 'core/theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'widgets/vendor_splash.dart';

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
  bool showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => error = null);
    // مدة الأنيميشن المبسط (700ms) — سريعة بدون انتظار زائد
    final splashMin = Future<void>.delayed(const Duration(milliseconds: 700));
    try {
      await app.bootstrap();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
      return;
    }
    await splashMin;
    if (!mounted) return;
    final r = buildRouter();
    // تصريف ضغطات الإشعارات (حتى بعد فتح التطبيق من مغلق)
    PushService.attachRouter(r);
    setState(() {
      router = r;
      showOnboarding = !app.onboardingCompleted;
    });
  }

  @override
  Widget build(BuildContext context) {
    // انتقال واحد متلاشي: سبلاش -> تطبيق (بدون قفزة بين واجهتين)
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _child(),
    );
  }

  Widget _child() {
    if (router == null) {
      return MaterialApp(
        key: const ValueKey('splash'),
        debugShowCheckedModeBanner: false,
        home: VendorSplashScreen(error: error, onRetry: _boot),
      );
    }
    if (showOnboarding) {
      return MaterialApp(
        key: const ValueKey('onboarding'),
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildSellerTheme(app.brand),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: OnboardingScreen(
          onComplete: () async {
            await app.completeOnboarding();
            if (mounted) setState(() => showOnboarding = false);
          },
        ),
      );
    }
    return SellerApp(key: const ValueKey('app'), router: router!);
  }
}
