import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_controller.dart';
import '../core/config.dart';
import '../core/json_util.dart';
import '../core/otp_resend.dart';
import '../core/theme.dart';
import '../widgets/branded_skeleton.dart';
import '../widgets/common.dart';

/// هيدر كحلي فخم لصفحات الدخول/الحساب: اسم العلامة نصاً بخط كبير
/// وتوزيع جانبي غير متماثل + علامة البرق (نفس هوية تطبيق العميل).
class AuthNavyHeader extends StatelessWidget {
  const AuthNavyHeader({super.key, required this.subtitle, this.badge});

  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          children: [
            // علامة برق ضخمة شفافة في الزاوية للعمق.
            const Positioned(
              left: -18,
              bottom: -28,
              child: Icon(
                Icons.bolt_rounded,
                size: 130,
                color: Color(0x0DFFFFFF),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Sarea Mart',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3.2,
                                color: Color(0x99FFFFFF),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'سريع ',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'مارت',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                      color: AppColors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // علامة البرق بدل الشعار الصوري.
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(19),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.orange.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (badge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: AppColors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.6,
                            color: Color(0xC4FFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final otp = TextEditingController();
  final newPassword = TextEditingController();
  final confirm = TextEditingController();
  String view = 'login';
  String? error;
  bool busy = false;
  bool hidePassword = true;
  final OtpResendGate _otpGate = OtpResendGate();
  String? _otpSuccess;
  bool _showDelayHint = false;
  bool _editingPhone = false;
  bool _resending = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    otp.dispose();
    newPassword.dispose();
    confirm.dispose();
    _otpGate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = view == 'login';
    final headerSubtitle = isLogin
        ? 'مرحباً بعودتك، سجّل الدخول لإدارة متجرك'
        : (view == 'forgot'
              ? 'سنرسل رمز تحقق إلى واتساب أو الجوال المسجّل'
              : 'أدخل رمز التحقق وكلمة المرور الجديدة');
    return Scaffold(
      backgroundColor: AppColors.greyBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isLogin ? 'دخول المتجر' : 'استعادة كلمة المرور',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              AuthNavyHeader(
                subtitle: headerSubtitle,
                badge: isLogin ? 'تطبيق التاجر' : 'استعادة الحساب',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  children: [
                    AuthFormCard(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isLogin
                                    ? Icons.storefront_rounded
                                    : Icons.lock_reset_rounded,
                                size: 18,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLogin
                                        ? 'أدخل بيانات متجرك للمتابعة'
                                        : 'خطوة واحدة وتستعيد حسابك',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 36,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (view != 'reset')
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.text,
                            textDirection: TextDirection.ltr,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'الجوال أو البريد',
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                                color: AppColors.navy.withValues(alpha: 0.7),
                              ),
                              prefixText: view == 'login'
                                  ? null
                                  : '+${AppConfig.countryDialCode} ',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        if (view == 'login') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: password,
                            obscureText: hidePassword,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                size: 20,
                                color: AppColors.navy.withValues(alpha: 0.7),
                              ),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => hidePassword = !hidePassword,
                                ),
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (view == 'forgot')
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'سنرسل رمز تحقق إلى واتساب أو الجوال المسجّل.',
                            ),
                          ),
                        if (view == 'reset') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text('الرقم: ${email.text.trim()}'),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _editingPhone = !_editingPhone,
                                ),
                                child: Text(_editingPhone ? 'تم' : 'تعديل'),
                              ),
                            ],
                          ),
                          if (_editingPhone)
                            TextField(
                              controller: email,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'الجوال',
                                prefixText: '+${AppConfig.countryDialCode} ',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          TextField(
                            controller: otp,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'رمز التحقق',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          labeledField(
                            newPassword,
                            'كلمة المرور الجديدة',
                            toggleObscure: true,
                          ),
                          labeledField(
                            confirm,
                            'تأكيد كلمة المرور',
                            toggleObscure: true,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: (_resending || !_otpGate.canSend)
                                ? null
                                : _resendOtp,
                            child: _resending
                                ? const BusySpinner()
                                : const Text('إعادة إرسال الرمز'),
                          ),
                        ],
                        if (_otpSuccess != null)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFA5D6A7),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _otpSuccess!,
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_showDelayHint &&
                            _otpSuccess != null &&
                            view != 'login')
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'لم يصلك الرمز؟ لا تقلق، قد يتأخر قليلاً وسيصلك',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (error != null)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFCDD2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFC62828),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    error!,
                                    style: const TextStyle(
                                      color: Color(0xFFB71C1C),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed:
                                busy || (view == 'forgot' && !_otpGate.canSend)
                                ? null
                                : _submit,
                            icon: busy
                                ? const SizedBox.shrink()
                                : const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                            label: busy
                                ? const BusySpinner()
                                : Text(
                                    view == 'login'
                                        ? 'دخول'
                                        : view == 'forgot'
                                        ? 'إرسال الرمز'
                                        : 'تغيير كلمة المرور',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                        if (view != 'reset')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      view = view == 'login'
                                          ? 'forgot'
                                          : 'login';
                                      error = null;
                                      _otpSuccess = null;
                                      _showDelayHint = false;
                                      _editingPhone = false;
                                      if (view == 'login')
                                        _otpGate.resetBackground();
                                    }),
                              icon: Icon(
                                view == 'login'
                                    ? Icons.help_outline_rounded
                                    : Icons.login_rounded,
                                size: 16,
                                color: AppColors.navy,
                              ),
                              label: Text(
                                view == 'login'
                                    ? 'نسيت كلمة المرور؟'
                                    : 'العودة لتسجيل الدخول',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // بطاقة روابط بلمسة كحلية.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.navy.withValues(alpha: 0.10),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (view == 'login')
                            TextButton.icon(
                              onPressed: () => context.push('/register'),
                              icon: Icon(
                                Icons.storefront_rounded,
                                size: 18,
                                color: AppColors.navy,
                              ),
                              label: Text(
                                'تسجيل متجر جديد',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.orange,
                                ),
                              ),
                            ),
                          TextButton(
                            onPressed: () => context.push('/privacy'),
                            child: const Text('سياسة الخصوصية والشروط'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final mobile = email.text.trim();
    if (mobile.isEmpty) {
      setState(() => error = 'أكمل الجوال أو البريد');
      return;
    }
    if (view == 'login' && password.text.isEmpty) {
      setState(() => error = 'أكمل الجوال أو البريد وكلمة المرور');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (view == 'login') {
        final message = await app.login(mobile, password.text);
        if (!mounted) return;
        if (message != null) {
          setState(() => error = message);
        } else {
          // يعتمد على GoRouter redirect عبر refreshListenable: app
          // لا نستدعي context.go مباشرة لتجنب ازدواج التوجيه و Duplicate GlobalKey
          if (!mounted) return;
          // إعطاء GoRouter فرصة لإعادة التوجيه تلقائياً
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (!mounted) return;
          final loc = GoRouter.of(
            context,
          ).routerDelegate.currentConfiguration.uri.path;
          if (loc == '/login') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go('/');
            });
          }
        }
      } else if (view == 'forgot') {
        final result = await app.api.forgotPasswordOtp(mobile);
        if (!mounted) return;
        _applyOtpResult(
          result,
          isBackground: false,
          allowNavigateToReset: true,
        );
      } else {
        if (otp.text.trim().isEmpty ||
            newPassword.text.length < 6 ||
            newPassword.text != confirm.text) {
          setState(
            () => error = 'تحقق من الرمز وكلمة المرور (6 أحرف على الأقل)',
          );
        } else {
          final result = await app.api.resetPasswordOtp(
            mobile: mobile,
            otp: otp.text.trim(),
            password: newPassword.text,
            passwordConfirmation: confirm.text,
          );
          if (!mounted) return;
          if (!result.ok) {
            setState(() => error = result.message);
          } else {
            _otpGate.resetBackground();
            setState(() {
              view = 'login';
              error = null;
              _otpSuccess = 'تم تغيير كلمة المرور. سجّل الدخول الآن';
              _showDelayHint = false;
              _editingPhone = false;
            });
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showOtpGreen(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _lockOtp(int extraSec) {
    _otpGate.lock(extraSec, () {
      if (mounted) setState(() {});
    });
  }

  void _scheduleBackgroundOtp(int retryAfter) {
    if (!_otpGate.canBackground) return;
    final delay = Duration(seconds: retryAfter > 0 ? retryAfter : 60);
    _otpGate.scheduleBackground(delay, () {
      if (!mounted) return;
      _fireBackgroundOtp();
    });
  }

  Future<void> _fireBackgroundOtp() async {
    if (!mounted) return;
    if (!_otpGate.canBackground) return;
    _otpGate.noteBackgroundTry();
    final current = email.text.trim();
    if (current.isEmpty) return;
    try {
      final result = await app.api.forgotPasswordOtp(current);
      if (!mounted) return;
      _applyOtpResult(result, isBackground: true);
    } catch (_) {
      // Keep the tries cap; a network throw simply stops this round.
    }
  }

  Future<void> _resendOtp() async {
    if (_resending || !_otpGate.canSend) return;
    final mobile = email.text.trim();
    if (mobile.isEmpty) {
      setState(() => error = 'أكمل الجوال أو البريد');
      return;
    }
    setState(() {
      _resending = true;
      error = null;
    });
    try {
      final result = await app.api.forgotPasswordOtp(mobile);
      if (!mounted) return;
      _applyOtpResult(result, isBackground: false);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _applyOtpResult(
    ApiResult result, {
    required bool isBackground,
    bool allowNavigateToReset = false,
  }) {
    if (result.ok) {
      setState(() {
        _otpSuccess = 'تم إرسال الرمز بنجاح';
        _showDelayHint = false;
        error = null;
        if (allowNavigateToReset && view == 'forgot') {
          view = 'reset';
        }
      });
      _showOtpGreen('تم إرسال الرمز بنجاح');
      _lockOtp(0);
      return;
    }
    final info = analyzeOtpSend(result.raw);
    if (info.kind == OtpSendKind.hardLimit) {
      setState(() {
        error = info.message.isNotEmpty
            ? info.message
            : 'تجاوزت الحد المسموح لطلب رموز التحقق، يرجى المحاولة لاحقاً';
        _otpSuccess = null;
        _showDelayHint = false;
      });
      _lockOtp(info.retryAfter);
      return;
    }
    if (info.kind == OtpSendKind.cooldown) {
      setState(() {
        _otpSuccess = 'تم إرسال الرمز بنجاح';
        _showDelayHint = true;
        error = null;
        if (allowNavigateToReset && view == 'forgot') {
          view = 'reset';
        }
      });
      _showOtpGreen('تم إرسال الرمز بنجاح');
      _lockOtp(info.retryAfter);
      _scheduleBackgroundOtp(info.retryAfter);
      return;
    }
    setState(() {
      error = result.message;
      _otpSuccess = null;
      _showDelayHint = false;
    });
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final store = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final description = TextEditingController();
  final address = TextEditingController();
  List<Map<String, dynamic>> cities = [];
  List<Map<String, dynamic>> categories = [];
  String? cityId;
  String? selectedCat;
  String? error;
  bool busy = false;
  bool accepted = false;
  bool adult = false;
  String? logoPath;
  String? nationalIdPath;
  bool listsLoading = true;
  // OTP التسجيل (مطابق OtpApiController + AdminAuth@sellerRegister: otp nullable)
  final otpCtrl = TextEditingController();
  bool otpSent = false;
  bool otpVerified = false;
  bool otpBypassed = false;
  bool otpBusy = false;
  // فحص التوفر المباشر — GET seller/check-name + check-store-name
  Timer? _checkDebounce;
  String? storeAvailability; // null=لم يُفحص, ok/taken/error
  String? nameAvailability;
  bool checkingStore = false;
  bool checkingName = false;
  final _errorKey = GlobalKey();

  void _fail(String message) {
    if (!mounted) return;
    setState(() => error = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _errorKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: 0.9,
        );
      }
    });
  }

  void _scheduleCheck({required bool isStore, required String value}) {
    _checkDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        if (isStore) {
          storeAvailability = null;
          checkingStore = false;
        } else {
          nameAvailability = null;
          checkingName = false;
        }
      });
      return;
    }
    setState(() {
      if (isStore) {
        checkingStore = true;
      } else {
        checkingName = true;
      }
    });
    _checkDebounce = Timer(const Duration(milliseconds: 700), () async {
      ApiResult res;
      try {
        res = isStore
            ? await app.api.checkStoreName(value.trim())
            : await app.api.checkName(value.trim());
      } catch (_) {
        if (!mounted) return;
        setState(() {
          if (isStore) {
            checkingStore = false;
            storeAvailability = 'error';
          } else {
            checkingName = false;
            nameAvailability = 'error';
          }
        });
        return;
      }
      if (!mounted) return;
      // العقد: status=1 متاح. أي فشل = مأخوذ أو خطأ مع رسالة.
      final available = res.ok;
      setState(() {
        if (isStore) {
          checkingStore = false;
          storeAvailability = available ? 'ok' : 'taken';
        } else {
          checkingName = false;
          nameAvailability = available ? 'ok' : 'taken';
        }
      });
      if (!available && res.message.isNotEmpty && mounted) {
        toast(context, res.message);
      }
    });
  }

  Widget _availabilitySuffix(bool checking, String? state) {
    if (checking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state == 'ok') {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (state == 'taken') {
      return const Icon(Icons.error_outline, color: Colors.red);
    }
    return const SizedBox.shrink();
  }

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => listsLoading = true);
    final cityRes = await app.api.cities();
    final catRes = await app.api.sellerCategoriesPublic();
    if (!mounted) return;
    setState(() {
      cities = cityRes.dataMaps;
      categories = catRes.dataMaps;
      listsLoading = false;
    });
  }

  @override
  void dispose() {
    _checkDebounce?.cancel();
    name.dispose();
    store.dispose();
    mobile.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    description.dispose();
    address.dispose();
    otpCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(
    String label,
    IconData icon, {
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: AppColors.navy.withValues(alpha: 0.7),
      ),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.navy.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.orange, width: 2),
      ),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionHeader(
    IconData icon,
    String step,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.navy,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.navy.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, size: 18, color: AppColors.navy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 28,
                height: 2.5,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepIndicator(int current) {
    return Row(
      children: List.generate(4, (i) {
        final active = i < current;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.orange
                  : AppColors.navy.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedSteps = [
      name.text.trim().isNotEmpty && mobile.text.trim().isNotEmpty,
      store.text.trim().isNotEmpty,
      cityId != null && selectedCat != null,
      logoPath != null && nationalIdPath != null,
    ].where((e) => e).length;
    return Scaffold(
      backgroundColor: AppColors.greyBg,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'تسجيل متجر',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const AuthNavyHeader(
                subtitle: 'أنشئ متجرك وابدأ البيع بعد موافقة الإدارة',
                badge: 'تسجيل متجر',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    // Step progress card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.navy.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.checklist_rounded,
                                size: 16,
                                color: AppColors.navy,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'أكملت $completedSteps من 4 خطوات',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _stepIndicator(completedSteps),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Owner info
                    AuthFormCard(
                      children: [
                        _sectionHeader(
                          Icons.person_outline_rounded,
                          '1',
                          'صاحب المتجر',
                          'الاسم وبيانات التواصل',
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: name,
                          decoration: _dec(
                            'الاسم الكامل *',
                            Icons.badge_outlined,
                            hint: 'الاسم',
                            suffix: _availabilitySuffix(
                              checkingName,
                              nameAvailability,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (v) =>
                              _scheduleCheck(isStore: false, value: v),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: mobile,
                          keyboardType: TextInputType.phone,
                          onChanged: (_) => setState(() {}),
                          decoration:
                              _dec(
                                'الجوال *',
                                Icons.phone_outlined,
                                hint: '777 000 000',
                              ).copyWith(
                                prefixText: '+${AppConfig.countryDialCode} ',
                                prefixStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        // توثيق الجوال (مطابق otp/send + otp/verify — مطلوب عند تفعيل بوابة OTP)
                        BrandedCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    otpVerified
                                        ? Icons.verified
                                        : Icons.sms_outlined,
                                    size: 18,
                                    color: otpVerified
                                        ? Colors.green
                                        : AppColors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      otpVerified
                                          ? 'تم توثيق الجوال ✓'
                                          : 'توثيق الجوال (يُطلب عند تفعيل OTP)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (!otpVerified)
                                    TextButton(
                                      onPressed: otpBusy
                                          ? null
                                          : () async {
                                              final m = mobile.text.trim();
                                              if (m.isEmpty) {
                                                setState(
                                                  () => error =
                                                      'أدخل الجوال أولاً',
                                                );
                                                return;
                                              }
                                              setState(() {
                                                otpBusy = true;
                                                error = null;
                                              });
                                              final r = await app.api
                                                  .sendRegisterOtp(m);
                                              if (!mounted) return;
                                              setState(() {
                                                otpBusy = false;
                                                otpBypassed =
                                                    r.ok &&
                                                    r.dataMap['requires_otp'] ==
                                                        false;
                                                otpVerified =
                                                    otpBypassed || otpVerified;
                                                otpSent =
                                                    (r.ok && !otpBypassed) ||
                                                    otpSent;
                                              });
                                              toast(
                                                context,
                                                otpBypassed
                                                    ? 'تم السماح بالتسجيل مؤقتاً بسبب توقف بوابة التحقق'
                                                    : r.ok
                                                    ? 'تم إرسال الرمز'
                                                    : r.message,
                                              );
                                            },
                                      child: otpBusy
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('إرسال الرمز'),
                                    ),
                                ],
                              ),
                              if (otpSent && !otpVerified) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: otpCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: _dec(
                                          'رمز التحقق',
                                          Icons.key_outlined,
                                          hint: '••••',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: otpBusy
                                          ? null
                                          : () async {
                                              if (otpCtrl.text.trim().isEmpty) {
                                                toast(context, 'أدخل الرمز');
                                                return;
                                              }
                                              setState(() => otpBusy = true);
                                              final r = await app.api.verifyOtp(
                                                mobile.text.trim(),
                                                otpCtrl.text.trim(),
                                              );
                                              if (!mounted) return;
                                              setState(() {
                                                otpBusy = false;
                                                otpVerified = r.ok;
                                              });
                                              toast(
                                                context,
                                                r.ok ? 'تم التوثيق' : r.message,
                                              );
                                            },
                                      child: const Text('توثيق'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dec(
                            'البريد (اختياري)',
                            Icons.mail_outline_rounded,
                            hint: 'example@email.com',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: true,
                          decoration: _dec(
                            'كلمة المرور *',
                            Icons.lock_outline,
                            hint: '••••••••',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirm,
                          obscureText: true,
                          decoration: _dec(
                            'تأكيد كلمة المرور *',
                            Icons.verified_user_outlined,
                            hint: '••••••••',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Store info
                    AuthFormCard(
                      children: [
                        _sectionHeader(
                          Icons.storefront_rounded,
                          '2',
                          'معلومات المتجر',
                          'الاسم والوصف والعنوان',
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: store,
                          decoration: _dec(
                            'اسم المتجر *',
                            Icons.store_outlined,
                            hint: 'مثال: متجر النور',
                            suffix: _availabilitySuffix(
                              checkingStore,
                              storeAvailability,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (v) =>
                              _scheduleCheck(isStore: true, value: v),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: description,
                          maxLines: 3,
                          onChanged: (_) => setState(() {}),
                          decoration: _dec(
                            'وصف المتجر *',
                            Icons.description_outlined,
                            hint: 'ما الذي تبيعه؟',
                          ),
                          textInputAction: TextInputAction.newline,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: address,
                          decoration: _dec(
                            'العنوان التفصيلي',
                            Icons.location_on_outlined,
                            hint: 'الشارع، الحي',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Location & type
                    AuthFormCard(
                      children: [
                        _sectionHeader(
                          Icons.location_city_rounded,
                          '3',
                          'الموقع والتصنيف',
                          'اختر مدينتك ونوع النشاط',
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          key: ValueKey('city-${cities.length}-$cityId'),
                          initialValue: dropdownId(cityId, cities),
                          items: cities
                              .map(
                                (c) => DropdownMenuItem(
                                  value: '${c['id']}',
                                  child: Text(J.str(c['name'])),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => cityId = v),
                          decoration: _dec('المدينة *', Icons.map_outlined),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 16,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'نوع المتجر *',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (listsLoading)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: BusySpinner(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        else if (categories.isEmpty || cities.isEmpty)
                          OutlinedButton.icon(
                            onPressed: _loadLists,
                            icon: Icon(
                              Icons.refresh,
                              size: 18,
                              color: AppColors.orange,
                            ),
                            label: Text(
                              'تعذر التحميل — إعادة المحاولة',
                              style: TextStyle(color: AppColors.orange),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categories.map((c) {
                              final sel = selectedCat == '${c['id']}';
                              return ChoiceChip(
                                label: Text(J.str(c['name'])),
                                selected: sel,
                                onSelected: (on) => setState(
                                  () => selectedCat = on ? '${c['id']}' : null,
                                ),
                                selectedColor: AppColors.navy,
                                checkmarkColor: AppColors.white,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: sel
                                      ? AppColors.white
                                      : AppColors.textPrimary,
                                ),
                                side: BorderSide(
                                  color: sel
                                      ? AppColors.navy
                                      : AppColors.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Documents
                    AuthFormCard(
                      children: [
                        _sectionHeader(
                          Icons.verified_outlined,
                          '4',
                          'المستندات',
                          'شعار المتجر والهوية للمراجعة',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الصور تستخدم للمراجعة فقط. لا نصل لمعرضك إلا بموافقتك.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: UploadDropZone(
                                label: logoPath == null
                                    ? 'شعار المتجر *'
                                    : 'تم الاختيار ✓',
                                subtitle: logoPath == null
                                    ? 'PNG / JPG'
                                    : logoPath!.split('/').last,
                                selected: logoPath != null,
                                onTap: () async {
                                  final file = await pickStoreImage(
                                    context,
                                    reason:
                                        'سنفتح المعرض لاختيار شعار المتجر فقط. لا نصل إلى صورك الأخرى.',
                                  );
                                  if (file != null && mounted)
                                    setState(() => logoPath = file.path);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: UploadDropZone(
                                label: nationalIdPath == null
                                    ? 'صورة الهوية *'
                                    : 'تم الاختيار ✓',
                                subtitle: nationalIdPath == null
                                    ? 'للتحقق'
                                    : nationalIdPath!.split('/').last,
                                selected: nationalIdPath != null,
                                onTap: () async {
                                  final file = await pickStoreImage(
                                    context,
                                    reason:
                                        'سنفتح المعرض لاختيار صورة الهوية فقط لأغراض التحقق.',
                                  );
                                  if (file != null && mounted)
                                    setState(() => nationalIdPath = file.path);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Consents
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: adult,
                            activeColor: AppColors.orange,
                            onChanged: (v) => setState(() => adult = v == true),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'أؤكد أن عمري 18 عاماً فأكثر',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'التسجيل مخصص للبالغين فقط',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Divider(height: 1, color: AppColors.border),
                          CheckboxListTile(
                            value: accepted,
                            activeColor: AppColors.orange,
                            onChanged: (v) =>
                                setState(() => accepted = v == true),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'أوافق على ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => context.push('/privacy'),
                                  child: Text(
                                    'سياسة الخصوصية والشروط',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.orange,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (error != null)
                      Container(
                        key: _errorKey,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: Color(0xFFC62828),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color: Color(0xFFB71C1C),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? BusySpinner(color: AppColors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.storefront_rounded,
                                    size: 20,
                                    color: AppColors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'إنشاء المتجر',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => context.push('/privacy'),
                      child: Text(
                        'قراءة السياسات',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'لديك حساب؟',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty ||
        store.text.trim().isEmpty ||
        mobile.text.trim().isEmpty) {
      _fail('أكمل الاسم واسم المتجر والجوال');
      return;
    }
    if (description.text.trim().isEmpty) {
      _fail('أدخل وصف المتجر');
      return;
    }
    if (otpSent && !otpVerified) {
      _fail('وثّق رقم الجوال قبل إنشاء المتجر');
      return;
    }
    if (storeAvailability == 'taken') {
      _fail('اسم المتجر مأخوذ — اختر اسماً آخر');
      return;
    }
    if (nameAvailability == 'taken') {
      _fail('هذا الاسم مسجل — اختر اسماً آخر');
      return;
    }
    if (password.text.length < 6 || password.text != confirm.text) {
      _fail('تحقق من كلمة المرور (6 أحرف على الأقل)');
      return;
    }
    if (cityId == null || selectedCat == null) {
      _fail('اختر المدينة ونوع المتجر');
      return;
    }
    if (logoPath == null || nationalIdPath == null) {
      _fail('شعار المتجر وصورة الهوية مطلوبان');
      return;
    }
    if (!adult) {
      _fail('التسجيل متاح لمن يبلغ 18 عاماً فأكثر');
      return;
    }
    if (!accepted) {
      _fail('يجب الموافقة على السياسات قبل التسجيل');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final city = cities.cast<Map<String, dynamic>?>().firstWhere(
        (c) => '${c?['id']}' == cityId,
        orElse: () => cities.isNotEmpty ? cities.first : null,
      );
      final data = FormData.fromMap({
        'name': name.text.trim(),
        'store_name': store.text.trim(),
        'mobile': mobile.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'confirm_password': confirm.text,
        'store_description': description.text,
        'categories_ids': selectedCat,
        'city_id': cityId,
        'formatted_address': address.text,
        'latitude': city?['latitude'] ?? 0,
        'longitude': city?['longitude'] ?? 0,
        if (otpCtrl.text.trim().isNotEmpty) 'otp': otpCtrl.text.trim(),
        'store_logo': await MultipartFile.fromFile(
          logoPath!,
          filename: 'logo.jpg',
        ),
        'national_id_card': await MultipartFile.fromFile(
          nationalIdPath!,
          filename: 'id.jpg',
        ),
      });
      final result = await app.api.register(data);
      if (!mounted) return;
      if (result.ok) {
        if (!mounted) return;
        if (context.mounted) toast(context, 'تم التسجيل، بانتظار الموافقة');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/login');
        });
      } else {
        _fail(
          result.message.isEmpty
              ? 'تعذر التسجيل. حاول مرة أخرى'
              : result.message,
        );
      }
    } catch (_) {
      _fail('تعذر الاتصال بالخادم. تحقق من الإنترنت.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  String privacy = '';
  String terms = '';
  bool loading = true;

  static const _privacyFallback =
      'تنطبق سياسة الخصوصية هذه على تطبيق سريع مارت - تاجر في اليمن. نجمع بيانات الحساب اللازمة لإدارة المتجر: الاسم، اسم المتجر، رقم الجوال، البريد إن وُجد، العنوان والمدينة، التصنيفات، المنتجات، الطلبات، العمولات، المحفظة وطلبات السحب.\n\n'
      'الصور: يمكنك اختيار شعار المتجر وصورة الهوية وإثبات العنوان وصور المنتجات من المعرض عند التسجيل أو التحديث. لا نصل إلى المعرض إلا عند اختيارك ذلك.\n\n'
      'لا نبيع بياناتك لمعلنين. قد تظهر بيانات لازمة لتنفيذ الطلب داخل المنصة (العميل والإدارة والموصل عند التعيين). يمكنك حذف الحساب من: حسابي ثم حذف الحساب.\n\n'
      'الخدمة مخصصة لأصحاب المتاجر البالغين 18 عاماً فأكثر. آخر تحديث: 15 أغسطس 2026.';

  static const _termsFallback =
      'باستخدام تطبيق سريع مارت - تاجر فإنك توافق على هذه الشروط. التسجيل يخضع لمراجعة الإدارة قبل تفعيل المتجر.\n\n'
      'أنت مسؤول عن صحة بيانات المنتجات والأسعار والمخزون، وتنفيذ الطلبات أو تعيين موصل عند السماح بذلك، وتحديث حالة الطلب بدقة.\n\n'
      'يُمنع عرض سلع محظورة أو إساءة استخدام بيانات العملاء. يحق للإدارة إيقاف الحساب عند المخالفة. العمولة تُحسب حسب إعدادات المنصة.\n\n'
      'يمكنك حذف حسابك من داخل التطبيق: حسابي ثم حذف الحساب. آخر تحديث: 15 أغسطس 2026.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String pick(dynamic source, String key) {
      if (source is Map) return J.plain(source[key]);
      return J.plain(source);
    }

    var p = pick(app.settings, 'privacy_policy_seller');
    var t = pick(app.settings, 'terms_conditions_seller');
    if (p.isEmpty || t.isEmpty) {
      final result = await app.api.privacyPolicy();
      final data = result.dataMap.isNotEmpty ? result.dataMap : result.raw;
      if (p.isEmpty) p = pick(data, 'privacy_policy_seller');
      if (t.isEmpty) t = pick(data, 'terms_conditions_seller');
    }
    if (!mounted) return;
    setState(() {
      privacy = p.isEmpty ? _privacyFallback : p;
      terms = t.isEmpty ? _termsFallback : t;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('السياسات')),
      body: loading
          ? const BrandedSkeletonList(count: 3)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'سياسة الخصوصية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(privacy),
                const SizedBox(height: 24),
                const Text(
                  'الشروط والأحكام',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(terms),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() => loading = true);
                    _load();
                  },
                  child: const Text('تحديث'),
                ),
              ],
            ),
    );
  }
}

// ───────── الشروط والأحكام (مطابق GET seller-terms-conditions) ─────────
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});
  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  String text = '';
  bool loading = true;
  String? error;

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    final r = await app.api.termsConditions();
    if (!mounted) return;
    setState(() {
      text = J.plain(r.dataMap.isNotEmpty ? r.dataMap : r.raw);
      if (text.isEmpty) {
        text = J.plain(app.settings['terms_conditions_seller']);
      }
      loading = false;
      error = (r.ok || text.isNotEmpty) ? null : r.failMessage;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشروط والأحكام')),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: text.isEmpty,
        emptyText: 'لا توجد شروط حالياً',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [Text(text)],
        ),
      ),
    );
  }
}

// ───────── حالة الطلب (انتظار/قبول/رفض) ─────────
// Web parity: views/Sellers/SellerPendingStatus.vue — GET seller/status
class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});
  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  bool busy = false;

  int get status {
    if (app.seller.isEmpty) return -1; // لا يوجد متجر مرتبط
    return app.sellerStatus;
  }

  Future<void> _refresh() async {
    setState(() => busy = true);
    await app.refreshSession();
    if (!mounted) return;
    setState(() => busy = false);
    if (app.sellerStatus == 1 && context.mounted) context.go('/');
  }

  @override
  void initState() {
    super.initState();
    if (app.sellerStatus == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = status;
    final email = J.str(app.user?['email']);
    final store = J.str(app.seller['store_name']);
    final reason = J.str(
      app.seller['rejection_reason'] ?? app.seller['rejection_note'],
    );
    return Scaffold(
      backgroundColor: AppColors.greyBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.navy.withValues(alpha: 0.10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    st == 1
                        ? Icons.check_circle
                        : st == 2
                        ? Icons.cancel
                        : st == -1
                        ? Icons.store_outlined
                        : Icons.hourglass_empty,
                    size: 72,
                    color: st == 1
                        ? Colors.green
                        : st == 2
                        ? Colors.red
                        : AppColors.orange,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    st == 1
                        ? 'تم قبول طلبك'
                        : st == 2
                        ? 'تم رفض الطلب'
                        : st == -1
                        ? 'لا يوجد متجر مرتبط'
                        : 'طلبك قيد المراجعة',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    st == 1
                        ? 'تمت الموافقة على حساب التاجر الخاص بك'
                        : st == 2
                        ? 'تم رفض طلب تسجيل التاجر الخاص بك'
                        : st == -1
                        ? 'هذا الحساب دخول تاجر لكن لا يوجد سجل متجر مرتبط به. تواصل مع الإدارة لإنشاء سجل المتجر أو تفعيله.'
                        : 'طلب تسجيل التاجر الخاص بك قيد المراجعة من الإدارة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BrandedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (email.isNotEmpty) Text('البريد: $email'),
                  if (J.str(app.user?['mobile']).isNotEmpty) ...[
                    if (email.isNotEmpty) const SizedBox(height: 6),
                    Text('الجوال: ${J.str(app.user?['mobile'])}'),
                  ],
                  if (store.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('المتجر: $store'),
                  ],
                  if (app.supportPhone.isNotEmpty ||
                      app.supportEmail.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(),
                    const Text(
                      'للاستفسار تواصل مع الدعم:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (app.supportPhone.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => openTel(app.supportPhone),
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        label: Text(app.supportPhone),
                      ),
                    if (app.supportEmail.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => openMail(app.supportEmail),
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: Text(app.supportEmail),
                      ),
                  ],
                ],
              ),
            ),
            if (st == 2 && reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: AppColors.orange, width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'سبب الرفض:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(reason),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (st == 1)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('الذهاب للوحة التحكم'),
                ),
              )
            else if (st == 2 || st == -1)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await app.logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('العودة لتسجيل الدخول'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : _refresh,
                  child: busy
                      ? const BusySpinner()
                      : const Text('تحديث الحالة'),
                ),
              ),
            if (st == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await app.logout();
                          if (context.mounted) context.go('/login');
                        },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('تسجيل الخروج'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

