import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_controller.dart';
import '../core/config.dart';
import '../core/json_util.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

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

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    otp.dispose();
    newPassword.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/brand/logo.webp',
                      height: 80,
                      errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 64, color: AppColors.orange),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'سريع ماركت',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.white),
                  ),
                  const Text(
                    'تطبيق تاجر',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              view == 'login' ? 'دخول المتجر' : 'استعادة كلمة المرور',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: email,
              keyboardType: TextInputType.text,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'الجوال أو البريد',
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
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => hidePassword = !hidePassword),
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
                child: Text('سنرسل رمز تحقق إلى واتساب أو الجوال المسجّل.'),
              ),
            if (view == 'reset') ...[
              const SizedBox(height: 12),
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
              labeledField(confirm, 'تأكيد كلمة المرور', toggleObscure: true),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const BusySpinner()
                  : Text(
                      view == 'login'
                          ? 'دخول'
                          : view == 'forgot'
                          ? 'إرسال الرمز'
                          : 'تغيير كلمة المرور',
                    ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      view = view == 'login' ? 'forgot' : 'login';
                      error = null;
                    }),
              child: Text(
                view == 'login' ? 'نسيت كلمة المرور؟' : 'العودة لتسجيل الدخول',
                style: const TextStyle(color: AppColors.navy),
              ),
            ),
            if (view == 'login')
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('تسجيل متجر جديد'),
              ),
            TextButton(
              onPressed: () => context.push('/privacy'),
              child: const Text('سياسة الخصوصية والشروط'),
            ),
          ],
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
          context.go('/');
        }
      } else if (view == 'forgot') {
        final result = await app.api.forgotPasswordOtp(mobile);
        if (!mounted) return;
        if (!result.ok) {
          setState(() => error = result.message);
        } else {
          setState(() {
            view = 'reset';
            error = 'أدخل رمز التحقق وكلمة المرور الجديدة';
          });
        }
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
            setState(() {
              view = 'login';
              error = 'تم تغيير كلمة المرور. سجّل الدخول الآن';
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
    name.dispose();
    store.dispose();
    mobile.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    description.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل متجر')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          labeledField(name, 'الاسم'),
          labeledField(store, 'اسم المتجر'),
          labeledField(mobile, 'الجوال', type: TextInputType.phone),
          labeledField(email, 'البريد (اختياري)'),
          labeledField(password, 'كلمة المرور', toggleObscure: true),
          labeledField(confirm, 'تأكيد كلمة المرور', toggleObscure: true),
          labeledField(description, 'وصف المتجر', maxLines: 3),
          labeledField(address, 'العنوان'),
          const SizedBox(height: 8),
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
            decoration: const InputDecoration(
              labelText: 'المدينة',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text('نوع المتجر'),
          if (listsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: BusySpinner(color: Colors.grey)),
            )
          else if (categories.isEmpty || cities.isEmpty)
            TextButton(
              onPressed: _loadLists,
              child: const Text('تعذر تحميل المدن أو التصنيفات. إعادة المحاولة'),
            ),
          Wrap(
            spacing: 8,
            children: categories
                .map(
                  (c) => ChoiceChip(
                    label: Text(J.str(c['name'])),
                    selected: selectedCat == '${c['id']}',
                    onSelected: (on) => setState(() {
                      selectedCat = on ? '${c['id']}' : null;
                    }),
                  ),
                )
                .toList(),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          const Text(
            'نحتاج شعار المتجر وصورة الهوية للمراجعة فقط. لا نصل إلى المعرض إلا بعد موافقتك.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final file = await pickStoreImage(
                context,
                reason:
                    'سنفتح المعرض لاختيار شعار المتجر فقط. لا نصل إلى صورك الأخرى.',
              );
              if (file != null && mounted) setState(() => logoPath = file.path);
            },
            icon: const Icon(Icons.storefront),
            label: Text(
              logoPath == null ? 'شعار المتجر (مطلوب)' : 'تم اختيار الشعار',
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final file = await pickStoreImage(
                context,
                reason:
                    'سنفتح المعرض لاختيار صورة الهوية فقط لأغراض التحقق. لا نصل إلى صورك الأخرى.',
              );
              if (file != null && mounted) {
                setState(() => nationalIdPath = file.path);
              }
            },
            icon: const Icon(Icons.badge_outlined),
            label: Text(
              nationalIdPath == null
                  ? 'صورة الهوية (مطلوب)'
                  : 'تم اختيار الهوية',
            ),
          ),
          CheckboxListTile(
            value: adult,
            onChanged: (v) => setState(() => adult = v == true),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('أؤكد أن عمري 18 عاماً فأكثر'),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: accepted,
            onChanged: (v) => setState(() => accepted = v == true),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('أوافق على سياسة الخصوصية والشروط'),
            contentPadding: EdgeInsets.zero,
          ),
          TextButton(
            onPressed: () => context.push('/privacy'),
            child: const Text('قراءة السياسات'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: busy ? const BusySpinner() : const Text('تسجيل'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty ||
        store.text.trim().isEmpty ||
        mobile.text.trim().isEmpty) {
      setState(() => error = 'أكمل الاسم واسم المتجر والجوال');
      return;
    }
    if (password.text.length < 6 || password.text != confirm.text) {
      setState(() => error = 'تحقق من كلمة المرور (6 أحرف على الأقل)');
      return;
    }
    if (cityId == null || selectedCat == null) {
      setState(() => error = 'اختر المدينة ونوع المتجر');
      return;
    }
    if (logoPath == null || nationalIdPath == null) {
      setState(() => error = 'شعار المتجر وصورة الهوية مطلوبان');
      return;
    }
    if (!adult) {
      setState(() => error = 'التسجيل متاح لمن يبلغ 18 عاماً فأكثر');
      return;
    }
    if (!accepted) {
      setState(() => error = 'يجب الموافقة على السياسات قبل التسجيل');
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
        toast(context, 'تم التسجيل، بانتظار الموافقة');
        context.go('/login');
      } else {
        setState(
          () => error = result.message.isEmpty
              ? 'تعذر التسجيل. حاول مرة أخرى'
              : result.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت.');
      }
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
      'تنطبق سياسة الخصوصية هذه على تطبيق مجمع مأرب متجر في اليمن. نجمع بيانات الحساب اللازمة لإدارة المتجر: الاسم، اسم المتجر، رقم الجوال، البريد إن وُجد، العنوان والمدينة، التصنيفات، المنتجات، الطلبات، العمولات، المحفظة وطلبات السحب.\n\n'
      'الصور: يمكنك اختيار شعار المتجر وصورة الهوية وإثبات العنوان وصور المنتجات من المعرض عند التسجيل أو التحديث. لا نصل إلى المعرض إلا عند اختيارك ذلك.\n\n'
      'لا نبيع بياناتك لمعلنين. قد تظهر بيانات لازمة لتنفيذ الطلب داخل المنصة (العميل والإدارة والموصل عند التعيين). يمكنك حذف الحساب من: حسابي ثم حذف الحساب.\n\n'
      'الخدمة مخصصة لأصحاب المتاجر البالغين 18 عاماً فأكثر. آخر تحديث: 15 أغسطس 2026.';

  static const _termsFallback =
      'باستخدام تطبيق مجمع مأرب متجر فإنك توافق على هذه الشروط. التسجيل يخضع لمراجعة الإدارة قبل تفعيل المتجر.\n\n'
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
          ? const Center(child: CircularProgressIndicator())
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
