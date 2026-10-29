import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_controller.dart';
import '../core/formatters.dart';
import '../core/json_util.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ResourceListScreen extends StatefulWidget {
  const ResourceListScreen({
    super.key,
    required this.title,
    required this.loader,
    required this.itemTitle,
    this.itemSub,
    this.openAdd,
    this.openEdit,
    this.onDelete,
  });

  final String title;
  final Future<ApiResult> Function() loader;
  final String Function(Map<String, dynamic>) itemTitle;
  final String Function(Map<String, dynamic>)? itemSub;
  final Future<bool?> Function(BuildContext context)? openAdd;
  final Future<bool?> Function(BuildContext context, Map<String, dynamic> item)?
  openEdit;
  final Future<ApiResult> Function(Map<String, dynamic> item)? onDelete;

  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    final result = await widget.loader();
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
      loading = false;
      error = result.ok ? null : result.failMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: widget.openAdd == null || !app.canWrite
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final ok = await widget.openAdd!(context);
                if (ok == true) reload();
              },
              child: const Icon(Icons.add),
            ),
      body: FetchBody(
        loading: loading,
        onRefresh: reload,
        error: error,
        isEmpty: items.isEmpty,
        emptyText: 'لا توجد عناصر بعد',
        emptyIcon: Icons.inbox_outlined,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final item = items[i];
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(widget.itemTitle(item)),
              subtitle: widget.itemSub == null
                  ? null
                  : Text(widget.itemSub!(item)),
              onTap: widget.openEdit == null
                  ? null
                  : () async {
                      final ok = await widget.openEdit!(context, item);
                      if (ok == true) reload();
                    },
              trailing: widget.onDelete == null || !app.canWrite
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await confirmWrite(context)) return;
                        final ok = await confirmAction(
                          context,
                          title: 'حذف',
                          body: 'هل تريد حذف هذا العنصر؟',
                          confirmLabel: 'حذف',
                          destructive: true,
                        );
                        if (!ok || !context.mounted) return;
                        final result = await widget.onDelete!(item);
                        if (!context.mounted) return;
                        toast(context, result.ok ? 'تم الحذف' : result.message);
                        if (result.ok) reload();
                      },
                    ),
            );
          },
        ),
      ),
    );
  }
}

class PromoFormScreen extends StatefulWidget {
  const PromoFormScreen({super.key, this.item});
  final Map<String, dynamic>? item;

  @override
  State<PromoFormScreen> createState() => _PromoFormScreenState();
}

class _PromoFormScreenState extends State<PromoFormScreen> {
  final code = TextEditingController();
  final message = TextEditingController();
  final users = TextEditingController(text: '100');
  final minOrder = TextEditingController(text: '0');
  final discount = TextEditingController();
  final maxDiscount = TextEditingController(text: '0');
  final repeats = TextEditingController(text: '1');
  String start = '';
  String end = '';
  String discountType = 'percentage';
  bool repeatUsage = true;
  int status = 1;
  String scopeType = 'all';
  String? scopeCategoryId;
  List<Map<String, dynamic>> scopeCategories = [];
  String? imagePath;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    app.api.categories().then((res) {
      if (mounted) setState(() => scopeCategories = res.dataMaps);
    });
    final item = widget.item;
    if (item != null) {
      code.text = J.str(item['promo_code']);
      message.text = J.str(item['message']);
      users.text = J.str(item['no_of_users'], '100');
      minOrder.text = J.str(item['minimum_order_amount'], '0');
      discount.text = J.str(item['discount']);
      maxDiscount.text = J.str(item['max_discount_amount'], '0');
      repeats.text = J.str(item['no_of_repeat_usage'], '1');
      start = J.str(item['start_date']);
      end = J.str(item['end_date']);
      discountType = J.str(item['discount_type'], 'percentage');
      repeatUsage = J.flag(item['repeat_usage']);
      status = J.i(item['status'], 1);
      scopeType = J.str(item['scope_type'], 'all');
      final sc = item['scope_id'];
      if (sc != null && '$sc'.isNotEmpty) scopeCategoryId = '$sc';
    }
  }

  @override
  void dispose() {
    code.dispose();
    message.dispose();
    users.dispose();
    minOrder.dispose();
    discount.dispose();
    maxDiscount.dispose();
    repeats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'كود خصم جديد' : 'تعديل كود خصم'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            labeledField(code, 'الكود'),
            labeledField(message, 'الرسالة', maxLines: 2),
            labeledField(users, 'عدد المستخدمين', type: TextInputType.number),
            labeledField(minOrder, 'حد أدنى للطلب', type: TextInputType.number),
            DropdownButtonFormField<String>(
              initialValue: discountType,
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('نسبة %')),
                DropdownMenuItem(value: 'amount', child: Text('مبلغ')),
              ],
              onChanged: (v) =>
                  setState(() => discountType = v ?? 'percentage'),
              decoration: const InputDecoration(
                labelText: 'نوع الخصم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            labeledField(discount, 'قيمة الخصم', type: TextInputType.number),
            labeledField(maxDiscount, 'أقصى خصم', type: TextInputType.number),
            SwitchListTile(
              title: const Text('استخدام متكرر'),
              value: repeatUsage,
              onChanged: (v) => setState(() => repeatUsage = v),
            ),
            if (repeatUsage)
              labeledField(repeats, 'مرات التكرار', type: TextInputType.number),
            DropdownButtonFormField<String>(
              initialValue: scopeType,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('كل المتجر')),
                DropdownMenuItem(value: 'category', child: Text('تصنيف محدد')),
              ],
              onChanged: (v) => setState(() => scopeType = v ?? 'all'),
              decoration: const InputDecoration(
                labelText: 'نطاق الكود (مطابق الباكند)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (scopeType == 'category')
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'promo-scope-${scopeCategories.length}-$scopeCategoryId',
                ),
                initialValue: dropdownId(scopeCategoryId, scopeCategories),
                items: scopeCategories
                    .map(
                      (c) => DropdownMenuItem(
                        value: '${c['id']}',
                        child: Text(J.str(c['name'])),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => scopeCategoryId = v),
                decoration: const InputDecoration(
                  labelText: 'التصنيف',
                  border: OutlineInputBorder(),
                ),
              ),
            if (scopeType == 'category') const SizedBox(height: 10),
            ListTile(
              title: Text(start.isEmpty ? 'تاريخ البداية' : Fmt.date(start)),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final value = await pickDate(context);
                if (value != null) setState(() => start = value);
              },
            ),
            ListTile(
              title: Text(end.isEmpty ? 'تاريخ النهاية' : Fmt.date(end)),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final value = await pickDate(context);
                if (value != null) setState(() => end = value);
              },
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final file = await pickStoreImage(
                  context,
                  reason:
                      'سنفتح المعرض لاختيار صورة العرض فقط. لا نصل إلى صورك الأخرى.',
                );
                if (file != null && mounted)
                  setState(() => imagePath = file.path);
              },
              icon: const Icon(Icons.image),
              label: Text(
                imagePath == null ? 'صورة (اختياري)' : 'تم اختيار الصورة',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!await confirmWrite(context)) return;
                      if (code.text.trim().isEmpty ||
                          discount.text.trim().isEmpty) {
                        toast(context, 'أكمل الكود وقيمة الخصم');
                        return;
                      }
                      if (start.isEmpty || end.isEmpty) {
                        toast(context, 'حدد تاريخ البداية والنهاية');
                        return;
                      }
                      setState(() => busy = true);
                      final map = <String, dynamic>{
                        'promo_code': code.text,
                        'message': message.text,
                        'start_date': start,
                        'end_date': end,
                        'no_of_users': users.text,
                        'minimum_order_amount': minOrder.text,
                        'discount_type': discountType,
                        'discount': discount.text,
                        'max_discount_amount': maxDiscount.text,
                        'repeat_usage': repeatUsage ? 1 : 0,
                        'no_of_repeat_usage': repeats.text,
                        'status': status,
                        'scope_type': scopeType,
                        if (scopeType == 'category' && scopeCategoryId != null)
                          'scope_id': scopeCategoryId,
                        if (widget.item != null) 'id': widget.item!['id'],
                      };
                      if (imagePath != null) {
                        map['image'] = await MultipartFile.fromFile(
                          imagePath!,
                          filename: 'promo.jpg',
                        );
                      }
                      final data = FormData.fromMap(map);
                      final result = widget.item == null
                          ? await app.api.savePromo(data)
                          : await app.api.updatePromo(data);
                      if (!mounted) return;
                      setState(() => busy = false);
                      toast(context, result.ok ? 'تم الحفظ' : result.message);
                      if (result.ok) Navigator.pop(context, true);
                    },
              child: busy ? const BusySpinner() : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class FlashFormScreen extends StatefulWidget {
  const FlashFormScreen({super.key, this.item});
  final Map<String, dynamic>? item;

  @override
  State<FlashFormScreen> createState() => _FlashFormScreenState();
}

class _FlashFormScreenState extends State<FlashFormScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  final discount = TextEditingController(text: '10');
  String start = '';
  String end = '';
  String? productId;
  int status = 1;
  List<Map<String, dynamic>> products = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    app.api.products().then((res) {
      if (mounted) setState(() => products = res.dataMaps);
    });
    final item = widget.item;
    if (item != null) {
      title.text = J.str(item['title']);
      description.text = J.str(item['description']);
      start = J.str(item['start_at']);
      end = J.str(item['end_at']);
      status = J.i(item['status'], 1);
      final items = J.maps(item['items']);
      if (items.isNotEmpty) {
        productId = '${items.first['product_id']}';
        discount.text = J.str(items.first['discount_value'], '10');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'عرض فلاش جديد' : 'تعديل عرض فلاش'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            labeledField(title, 'العنوان'),
            labeledField(description, 'الوصف', maxLines: 3),
            DropdownButtonFormField<String>(
              key: ValueKey('flash-${products.length}-$productId'),
              initialValue: dropdownId(productId, products),
              items: products
                  .map(
                    (p) => DropdownMenuItem(
                      value: '${p['id']}',
                      child: Text(J.str(p['name'])),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => productId = v),
              decoration: const InputDecoration(
                labelText: 'المنتج',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            labeledField(discount, 'نسبة الخصم %', type: TextInputType.number),
            ListTile(
              title: Text(
                start.isEmpty ? 'يبدأ' : Fmt.date(start, withTime: true),
              ),
              onTap: () async {
                final value = await pickDate(context, withTime: true);
                if (value != null) setState(() => start = value);
              },
            ),
            ListTile(
              title: Text(
                end.isEmpty ? 'ينتهي' : Fmt.date(end, withTime: true),
              ),
              onTap: () async {
                final value = await pickDate(context, withTime: true);
                if (value != null) setState(() => end = value);
              },
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!await confirmWrite(context)) return;
                      if (productId == null) {
                        toast(context, 'اختر منتجاً');
                        return;
                      }
                      if (start.isEmpty || end.isEmpty) {
                        toast(context, 'حدد وقت البداية والنهاية');
                        return;
                      }
                      setState(() => busy = true);
                      final items = jsonEncode([
                        {
                          'product_id': int.tryParse(productId!) ?? productId,
                          'discount_type': 'percentage',
                          'discount_value': discount.text,
                          'status': 1,
                        },
                      ]);
                      final data = FormData.fromMap({
                        'title': title.text,
                        'description': description.text,
                        'start_at': start,
                        'end_at': end,
                        'items': items,
                        'status': status,
                        if (widget.item != null) 'id': widget.item!['id'],
                      });
                      final result = widget.item == null
                          ? await app.api.saveFlash(data)
                          : await app.api.updateFlash(data);
                      if (!mounted) return;
                      setState(() => busy = false);
                      toast(context, result.ok ? 'تم الحفظ' : result.message);
                      if (result.ok) Navigator.pop(context, true);
                    },
              child: busy ? const BusySpinner() : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class BxgyFormScreen extends StatefulWidget {
  const BxgyFormScreen({super.key, this.item});
  final Map<String, dynamic>? item;

  @override
  State<BxgyFormScreen> createState() => _BxgyFormScreenState();
}

class _BxgyFormScreenState extends State<BxgyFormScreen> {
  final title = TextEditingController();
  final buyQty = TextEditingController(text: '1');
  final getQty = TextEditingController(text: '1');
  String start = '';
  String end = '';
  String? productId;
  String? getProductId;
  int status = 1;
  List<Map<String, dynamic>> products = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    app.api.products().then((res) {
      if (mounted) setState(() => products = res.dataMaps);
    });
    final item = widget.item;
    if (item != null) {
      title.text = J.str(item['title']);
      buyQty.text = J.str(item['buy_qty'], '1');
      getQty.text = J.str(item['get_qty'], '1');
      status = J.i(item['status'], 1);
      start = J.str(item['start_date']);
      end = J.str(item['end_date']);
      productId = '${item['product_id'] ?? ''}';
      getProductId = item['get_product_id'] == null
          ? null
          : '${item['get_product_id']}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'عرض اشترِ واحصل' : 'تعديل العرض'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            labeledField(title, 'العنوان (اختياري)'),
            DropdownButtonFormField<String>(
              key: ValueKey('bxgy-buy-${products.length}-$productId'),
              initialValue: dropdownId(productId, products),
              items: products
                  .map(
                    (p) => DropdownMenuItem(
                      value: '${p['id']}',
                      child: Text(J.str(p['name'])),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => productId = v),
              decoration: const InputDecoration(
                labelText: 'المنتج المشترى',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey('bxgy-get-${products.length}-$getProductId'),
              initialValue: products.any((p) => '${p['id']}' == getProductId)
                  ? getProductId
                  : '',
              items: [
                const DropdownMenuItem(value: '', child: Text('نفس المنتج')),
                ...products.map(
                  (p) => DropdownMenuItem(
                    value: '${p['id']}',
                    child: Text(J.str(p['name'])),
                  ),
                ),
              ],
              onChanged: (v) => setState(
                () => getProductId = (v == null || v.isEmpty) ? null : v,
              ),
              decoration: const InputDecoration(
                labelText: 'المنتج المهدى',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            labeledField(buyQty, 'كمية الشراء', type: TextInputType.number),
            labeledField(getQty, 'كمية الهدية', type: TextInputType.number),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'الهدية مجانية بالكامل (خصم 100%)، ويتحمل التاجر قيمة العرض.',
                ),
              ),
            ),
            ListTile(
              title: Text(start.isEmpty ? 'تاريخ البداية' : Fmt.date(start)),
              onTap: () async {
                final value = await pickDate(context);
                if (value != null) setState(() => start = value);
              },
            ),
            ListTile(
              title: Text(end.isEmpty ? 'تاريخ النهاية' : Fmt.date(end)),
              onTap: () async {
                final value = await pickDate(context);
                if (value != null) setState(() => end = value);
              },
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!await confirmWrite(context)) return;
                      if (productId == null || productId!.isEmpty) {
                        toast(context, 'اختر المنتج المشترى');
                        return;
                      }
                      if (start.isEmpty || end.isEmpty) {
                        toast(context, 'حدد تاريخ البداية والنهاية');
                        return;
                      }
                      setState(() => busy = true);
                      final body = {
                        'title': title.text,
                        'product_id': productId,
                        'buy_qty': buyQty.text,
                        'get_qty': getQty.text,
                        'get_product_id': getProductId,
                        'get_discount_percent': 100,
                        'start_date': start,
                        'end_date': end,
                        'status': status,
                        if (widget.item != null) 'id': widget.item!['id'],
                      };
                      final result = widget.item == null
                          ? await app.api.saveBxgy(body)
                          : await app.api.updateBxgy(body);
                      if (!mounted) return;
                      setState(() => busy = false);
                      toast(context, result.ok ? 'تم الحفظ' : result.message);
                      if (result.ok) Navigator.pop(context, true);
                    },
              child: busy ? const BusySpinner() : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryDiscountFormScreen extends StatefulWidget {
  const CategoryDiscountFormScreen({super.key, this.item});
  final Map<String, dynamic>? item;

  @override
  State<CategoryDiscountFormScreen> createState() =>
      _CategoryDiscountFormScreenState();
}

class _CategoryDiscountFormScreenState
    extends State<CategoryDiscountFormScreen> {
  final title = TextEditingController();
  final discount = TextEditingController();
  final maxDiscount = TextEditingController(text: '0');
  String type = 'percentage';
  String start = '';
  String end = '';
  int status = 1;
  String? sectionId;
  List<Map<String, dynamic>> sections = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    app.api.sellerSections().then((res) {
      if (mounted) setState(() => sections = res.dataMaps);
    });
    final item = widget.item;
    if (item != null) {
      title.text = J.str(item['title']);
      discount.text = J.str(item['discount']);
      maxDiscount.text = J.str(item['max_discount_amount'], '0');
      type = J.str(item['discount_type'], 'percentage');
      status = J.i(item['status'], 1);
      start = J.str(item['start_date']);
      end = J.str(item['end_date']);
      sectionId = '${item['seller_section_id'] ?? item['category_id'] ?? ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'خصم تصنيف' : 'تعديل خصم تصنيف'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            labeledField(title, 'العنوان'),
            DropdownButtonFormField<String>(
              key: ValueKey('catd-${sections.length}-$sectionId'),
              initialValue: dropdownId(sectionId, sections),
              items: sections
                  .map(
                    (c) => DropdownMenuItem(
                      value: '${c['id']}',
                      child: Text(J.str(c['name'])),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => sectionId = v),
              decoration: const InputDecoration(
                labelText: 'قسم المتجر',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('نسبة %')),
                DropdownMenuItem(value: 'amount', child: Text('مبلغ')),
              ],
              onChanged: (v) => setState(() => type = v ?? 'percentage'),
              decoration: const InputDecoration(
                labelText: 'نوع الخصم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            labeledField(discount, 'قيمة الخصم', type: TextInputType.number),
            labeledField(maxDiscount, 'أقصى خصم', type: TextInputType.number),
            ListTile(
              title: Text(start.isEmpty ? 'تاريخ البداية' : Fmt.date(start)),
              onTap: () async {
                final value = await pickDate(context);
                if (value != null) setState(() => start = value);
              },
            ),
            ListTile(
              title: Text(end.isEmpty ? 'تاريخ النهاية' : Fmt.date(end)),
              onTap: () async {
                final value = await pickDate(context);
                if (value != null) setState(() => end = value);
              },
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!await confirmWrite(context)) return;
                      if (sectionId == null ||
                          sectionId!.isEmpty ||
                          discount.text.trim().isEmpty) {
                        toast(context, 'اختر قسم المتجر وأدخل قيمة الخصم');
                        return;
                      }
                      if (start.isEmpty || end.isEmpty) {
                        toast(context, 'حدد تاريخ البداية والنهاية');
                        return;
                      }
                      setState(() => busy = true);
                      final body = {
                        'title': title.text,
                        'seller_section_id': sectionId,
                        'discount_type': type,
                        'discount': discount.text,
                        'max_discount_amount': maxDiscount.text,
                        'start_date': start,
                        'end_date': end,
                        'status': status,
                        if (widget.item != null) 'id': widget.item!['id'],
                      };
                      final result = widget.item == null
                          ? await app.api.saveCategoryDiscount(body)
                          : await app.api.updateCategoryDiscount(body);
                      if (!mounted) return;
                      setState(() => busy = false);
                      toast(context, result.ok ? 'تم الحفظ' : result.message);
                      if (result.ok) Navigator.pop(context, true);
                    },
              child: busy ? const BusySpinner() : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class DeliveryOfferFormScreen extends StatefulWidget {
  const DeliveryOfferFormScreen({super.key, this.item});
  final Map<String, dynamic>? item;

  @override
  State<DeliveryOfferFormScreen> createState() =>
      _DeliveryOfferFormScreenState();
}

class _DeliveryOfferFormScreenState extends State<DeliveryOfferFormScreen> {
  final title = TextEditingController();
  final minAmount = TextEditingController(text: '0');
  final freeCount = TextEditingController(text: '1');
  final nthValue = TextEditingController(text: '2');
  final maxSubsidy = TextEditingController(text: '0');
  final message = TextEditingController();
  String type = 'min_amount';
  String start = '';
  String end = '';
  int status = 1;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      title.text = J.str(item['title']);
      type = J.str(item['type'], 'min_amount');
      start = J.str(item['start_at']);
      end = J.str(item['end_at']);
      minAmount.text = J.str(item['min_order_amount'], '0');
      freeCount.text = J.str(item['free_orders_count'], '1');
      nthValue.text = J.str(item['nth_value'], '2');
      maxSubsidy.text = J.str(item['max_subsidy_amount'], '0');
      message.text = J.str(item['customer_message']);
      status = J.i(item['status'], 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item == null ? 'عرض توصيل مجاني' : 'تعديل عرض التوصيل',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'هذا العرض ممول من متجرك تلقائياً، وتُخصم تكلفة التوصيل المدعومة من مستحقاتك.',
                ),
              ),
            ),
            labeledField(title, 'عنوان العرض'),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(
                  value: 'min_amount',
                  child: Text('مجاني عند حد أدنى للطلب'),
                ),
                DropdownMenuItem(
                  value: 'new_user',
                  child: Text('أول عدد من طلبات العميل'),
                ),
                DropdownMenuItem(
                  value: 'nth_order',
                  child: Text('كل طلب رقم N'),
                ),
                DropdownMenuItem(
                  value: 'schedule',
                  child: Text('خلال مناسبة / فترة'),
                ),
              ],
              onChanged: (v) => setState(() => type = v ?? 'min_amount'),
              decoration: const InputDecoration(
                labelText: 'نوع العرض',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (type == 'min_amount')
              labeledField(
                minAmount,
                'الحد الأدنى للطلب',
                type: TextInputType.number,
              ),
            if (type == 'new_user')
              labeledField(
                freeCount,
                'عدد الطلبات المجانية الأولى',
                type: TextInputType.number,
              ),
            if (type == 'nth_order')
              labeledField(nthValue, 'كل طلب رقم', type: TextInputType.number),
            labeledField(
              maxSubsidy,
              'أقصى دعم لتكلفة التوصيل (0 = بلا حد)',
              type: TextInputType.number,
            ),
            labeledField(message, 'رسالة للعميل (اختياري)'),
            ListTile(
              title: Text(
                start.isEmpty
                    ? 'تاريخ البداية (اختياري)'
                    : Fmt.date(start, withTime: true),
              ),
              onTap: () async {
                final value = await pickDate(context, withTime: true);
                if (value != null) setState(() => start = value);
              },
            ),
            ListTile(
              title: Text(
                end.isEmpty
                    ? 'تاريخ النهاية (اختياري)'
                    : Fmt.date(end, withTime: true),
              ),
              onTap: () async {
                final value = await pickDate(context, withTime: true);
                if (value != null) setState(() => end = value);
              },
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!await confirmWrite(context)) return;
                      if (!mounted) return;
                      if (title.text.trim().isEmpty) {
                        toast(context, 'أدخل عنوان العرض');
                        return;
                      }
                      if (type == 'schedule' &&
                          (start.isEmpty || end.isEmpty)) {
                        toast(context, 'حدد بداية ونهاية فترة العرض');
                        return;
                      }
                      setState(() => busy = true);
                      final body = <String, dynamic>{
                        'title': title.text.trim(),
                        'type': type,
                        'start_at': start.isEmpty ? null : start,
                        'end_at': end.isEmpty ? null : end,
                        'min_order_amount': minAmount.text,
                        'free_orders_count': freeCount.text,
                        'nth_value': nthValue.text,
                        'max_subsidy_amount': maxSubsidy.text,
                        'customer_message': message.text.trim(),
                        'status': status,
                        if (widget.item != null) 'id': widget.item!['id'],
                      };
                      final result = widget.item == null
                          ? await app.api.saveDeliveryOffer(body)
                          : await app.api.updateDeliveryOffer(body);
                      if (!mounted) return;
                      setState(() => busy = false);
                      toast(context, result.ok ? 'تم الحفظ' : result.message);
                      if (result.ok) Navigator.pop(context, true);
                    },
              child: busy ? const BusySpinner() : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class NamedCrudScreen extends StatefulWidget {
  const NamedCrudScreen({super.key, required this.title, required this.kind});
  final String title;
  final String kind;

  @override
  State<NamedCrudScreen> createState() => _NamedCrudScreenState();
}

class _NamedCrudScreenState extends State<NamedCrudScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  Future<void> _load() async {
    final result = switch (widget.kind) {
      'units' => await app.api.units(),
      'taxes' => await app.api.taxes(),
      _ => await app.api.brands(),
    };
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
      loading = false;
      error = result.ok ? null : result.failMessage;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    if (!await confirmWrite(context)) return;
    final name = TextEditingController(
      text: J.str(item?['name'] ?? item?['title']),
    );
    final extra = TextEditingController(
      text: J.str(item?['short_code'] ?? item?['percentage']),
    );
    String? imagePath;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'إضافة' : 'تعديل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: widget.kind == 'taxes' ? 'الاسم' : 'الاسم',
              ),
            ),
            if (widget.kind != 'brands')
              TextField(
                controller: extra,
                decoration: InputDecoration(
                  labelText: widget.kind == 'units' ? 'الرمز' : 'النسبة %',
                ),
              ),
            if (widget.kind == 'brands')
              TextButton(
                onPressed: () async {
                  final file = await pickStoreImage(
                    context,
                    reason:
                        'سنفتح المعرض لاختيار صورة الماركة فقط. لا نصل إلى صورك الأخرى.',
                  );
                  if (file != null) imagePath = file.path;
                },
                child: const Text('صورة الماركة'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty) {
      toast(context, 'أدخل الاسم');
      return;
    }
    late ApiResult result;
    if (widget.kind == 'units') {
      final body = {
        'name': name.text,
        'short_code': extra.text,
        if (item != null) 'id': item['id'],
      };
      result = item == null
          ? await app.api.saveUnit(body)
          : await app.api.updateUnit(body);
    } else if (widget.kind == 'taxes') {
      final body = {
        'title': name.text,
        'percentage': extra.text,
        'status': 1,
        if (item != null) 'id': item['id'],
      };
      result = item == null
          ? await app.api.saveTax(body)
          : await app.api.updateTax(body);
    } else {
      final map = <String, dynamic>{
        'name': name.text,
        'status': 1,
        if (item != null) 'id': item['id'],
      };
      if (imagePath != null)
        map['image'] = await MultipartFile.fromFile(
          imagePath!,
          filename: 'brand.jpg',
        );
      final data = FormData.fromMap(map);
      result = item == null
          ? await app.api.saveBrand(data)
          : await app.api.updateBrand(data);
    }
    if (!mounted) return;
    toast(context, result.ok ? 'تم الحفظ' : result.message);
    if (result.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: app.canWrite
          ? FloatingActionButton(
              onPressed: () => _edit(),
              child: const Icon(Icons.add),
            )
          : null,
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: items.isEmpty,
        emptyText: 'لا توجد عناصر بعد',
        child: ListView(
          children: items
              .map(
                (item) => ListTile(
                  title: Text(J.str(item['name'] ?? item['title'])),
                  subtitle: Text(
                    J.str(item['short_code'] ?? item['percentage'] ?? ''),
                  ),
                  onTap: () => _edit(item),
                  trailing: app.canWrite
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (!await confirmWrite(context)) return;
                            final ok = await confirmAction(
                              context,
                              title: 'حذف',
                              body: 'هل تريد حذف هذا العنصر؟',
                              confirmLabel: 'حذف',
                              destructive: true,
                            );
                            if (!ok || !context.mounted) return;
                            final result = switch (widget.kind) {
                              'units' => await app.api.deleteUnit(item['id']),
                              'taxes' => await app.api.deleteTax(item['id']),
                              _ => await app.api.deleteBrand(item['id']),
                            };
                            if (!context.mounted) return;
                            toast(
                              context,
                              result.ok ? 'تم الحذف' : result.message,
                            );
                            if (result.ok) _load();
                          },
                        )
                      : null,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});
  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  String? path;
  String? fileName;
  bool busy = false;
  String? resultText;
  bool resultOk = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رفع منتجات جماعي')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, c) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'اختر ملف Excel أو CSV. الأعمدة: اسم المنتج + السعر (إجباري)، الوصف، المخزون، سعر الخصم، القسم، الصورة.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await pickStoreFiles(
                        context,
                        reason: 'سنفتح منتقي الملفات لاختيار ملف المنتجات فقط.',
                        type: FileType.custom,
                        extensions: const ['csv', 'txt', 'xlsx', 'xls'],
                      );
                      if (picked?.files.single.path != null && mounted) {
                        setState(() {
                          path = picked!.files.single.path;
                          fileName = picked.files.single.name;
                          resultText = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      path == null
                          ? 'اختيار ملف (CSV / Excel)'
                          : 'تم: $fileName',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy || path == null
                        ? null
                        : () async {
                            if (!await confirmWrite(context)) return;
                            setState(() {
                              busy = true;
                              resultText = null;
                            });
                            final result = await app.api.bulkUpload(
                              FormData.fromMap({
                                'file': await MultipartFile.fromFile(
                                  path!,
                                  filename: fileName ?? 'products.csv',
                                ),
                              }),
                            );
                            if (!mounted) return;
                            setState(() {
                              busy = false;
                              resultOk = result.ok;
                              // الباكند يرجع عدد المنشأة + أول 5 أخطاء صفوف داخل الرسالة
                              resultText = result.ok
                                  ? result.message
                                  : result.message;
                            });
                            toast(
                              context,
                              result.ok ? 'اكتمل الاستيراد' : result.message,
                            );
                          },
                    child: busy ? const BusySpinner() : const Text('رفع'),
                  ),
                  if (resultText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: resultOk
                            ? Colors.green.withValues(alpha: 0.08)
                            : Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: resultOk
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        resultText!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});
  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> daily = [];
  List<Map<String, dynamic>> invoices = [];
  bool loading = true;
  String? error;

  Future<void> _load() async {
    final result = await app.api.accounting();
    if (!mounted) return;
    setState(() {
      summary = J.map(result.dataMap['summary']);
      daily = result.list('daily');
      invoices = result.list('invoices');
      loading = false;
      error = result.ok ? null : result.failMessage;
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
      appBar: AppBar(title: const Text('المحاسبة')),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('مبيعات', summary['gross_sales']),
                _chip('عمولة', summary['commission_amount']),
                _chip('صافي', summary['net_earnings']),
                _chip('المحفظة', summary['wallet_balance']),
                _chip('طلبات', summary['orders_count'], money: false),
                _chip('فواتير', summary['invoices_count'], money: false),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final r = await app.api.accountingExportExcel();
                    if (!context.mounted) return;
                    toast(
                      context,
                      r.ok ? 'تم تصدير الإكسل (خلفية)' : r.message,
                    );
                  },
                  icon: const Icon(Icons.table_chart, size: 18),
                  label: const Text('تصدير إكسل'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final r = await app.api.accountingExportInvoices();
                    if (!context.mounted) return;
                    toast(
                      context,
                      r.ok ? 'تم تصدير الفواتير (خلفية)' : r.message,
                    );
                  },
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('تصدير الفواتير'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final r = await app.api.sellerCommission();
                    if (!context.mounted) return;
                    toast(
                      context,
                      r.ok
                          ? 'العمولة: ${r.dataMap['commission'] ?? r.dataMap}'
                          : r.message,
                    );
                  },
                  icon: const Icon(Icons.percent, size: 18),
                  label: const Text('العمولة'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (app.isHomeSeller)
              const BrandedCard(
                child: Text(
                  'متجر منزلي — تُحسب العمولة حسب سياسة المنصة',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (app.requireProductsApproval)
              BrandedCard(
                child: Text(
                  'تنبيه: منتجاتك تحتاج موافقة الإدارة قبل النشر',
                  style: TextStyle(fontSize: 13, color: AppColors.orange),
                ),
              ),
            const SizedBox(height: 16),
            const SectionHeader('البيانات اليومية'),
            if (daily.isEmpty)
              const ListTile(title: Text('لا توجد بيانات يومية')),
            ...daily.map(
              (d) => ListTile(
                title: Text(Fmt.date(d['date'])),
                subtitle: Text('صافي: ${Fmt.money(d['net_earnings'])}'),
                trailing: Text(Fmt.money(d['gross_sales'] ?? d['total_sales'])),
              ),
            ),
            const Divider(),
            const SectionHeader('الفواتير'),
            if (invoices.isEmpty) const ListTile(title: Text('لا توجد فواتير')),
            ...invoices.map(
              (inv) => ListTile(
                title: Text('#${inv['order_id'] ?? inv['id']}'),
                subtitle: Text(
                  Fmt.date(inv['created_at'] ?? inv['date'], withTime: true),
                ),
                trailing: Text(
                  Fmt.money(
                    inv['total'] ?? inv['net_amount'] ?? inv['final_total'],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, dynamic value, {bool money = true}) {
    final text = money ? Fmt.money(value ?? 0) : J.str(value, '0');
    return Chip(label: Text('$label: $text'));
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late String start;
  late String end;
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String? error;

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    end = _iso(now);
    start = _iso(now.subtract(const Duration(days: 30)));
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    final results = await Future.wait([
      app.api.salesReports(startDate: start, endDate: end),
      app.api.productSalesReports(startDate: start, endDate: end),
    ]);
    if (!mounted) return;
    final a = results[0];
    final b = results[1];
    setState(() {
      sales = a.list('salesReports').isNotEmpty
          ? a.list('salesReports')
          : a.dataMaps;
      products = b.dataMaps;
      loading = false;
      if (!a.ok || !b.ok) {
        error = a.ok ? b.failMessage : a.failMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: Column(
        children: [
          ListTile(
            title: Text('من ${Fmt.date(start)} إلى ${Fmt.date(end)}'),
            trailing: const Icon(Icons.date_range),
            onTap: () async {
              final s = await pickDate(context);
              if (s == null || !context.mounted) return;
              final e = await pickDate(context);
              if (e == null) return;
              start = s;
              end = e;
              _load();
            },
          ),
          Expanded(
            child: FetchBody(
              loading: loading,
              onRefresh: _load,
              error: error,
              isEmpty: sales.isEmpty && products.isEmpty,
              emptyText: 'لا توجد تقارير لهذه الفترة',
              emptyIcon: Icons.bar_chart_outlined,
              child: ListView(
                children: [
                  const ListTile(
                    title: Text(
                      'المبيعات',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...sales.map(
                    (s) => ListTile(
                      title: Text(
                        J.str(s['product_name'] ?? s['user_name'], 'طلب'),
                      ),
                      subtitle: Text(
                        Fmt.date(
                          s['added_date'] ?? s['created_at'],
                          withTime: true,
                        ),
                      ),
                      trailing: Text(
                        Fmt.money(s['sub_total'] ?? s['final_total']),
                      ),
                    ),
                  ),
                  const ListTile(
                    title: Text(
                      'حسب المنتج',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...products.map(
                    (p) => ListTile(
                      title: Text(
                        J.str(p['product_name'] ?? p['name'], 'منتج'),
                      ),
                      subtitle: Text(
                        'الكمية المبيعة: ${J.str(p['total_sales'], '-')}',
                      ),
                      trailing: Text(
                        Fmt.money(p['total_price'] ?? p['sub_total']),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final name = TextEditingController();
  final store = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final description = TextEditingController();
  final address = TextEditingController();
  final accountNumber = TextEditingController();
  final bankName = TextEditingController();
  final accountName = TextEditingController();
  final ifsc = TextEditingController();
  final taxName = TextEditingController();
  final taxNumber = TextEditingController();
  final panNumber = TextEditingController();
  final pincode = TextEditingController();
  final stateCtrl = TextEditingController();
  String? cityId;
  String? logoPath;
  String? proofPath;
  String? nationalIdPath;
  List<Map<String, dynamic>> cities = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final s = app.seller;
    name.text = J.str(s['name'] ?? app.user?['name']);
    store.text = J.str(s['store_name']);
    mobile.text = J.str(s['mobile']);
    email.text = J.str(s['email'] ?? app.user?['email']);
    description.text = J.str(s['store_description']);
    address.text = J.str(s['formatted_address'] ?? s['street']);
    accountNumber.text = J.str(s['account_number']);
    bankName.text = J.str(s['bank_name']);
    accountName.text = J.str(s['account_name']);
    ifsc.text = J.str(s['bank_ifsc_code'] ?? s['ifsc_code']);
    taxName.text = J.str(s['tax_name']);
    taxNumber.text = J.str(s['tax_number']);
    panNumber.text = J.str(s['pan_number']);
    pincode.text = J.str(s['pincode_id'] == 0 ? '' : s['pincode_id']);
    stateCtrl.text = J.str(s['state']);
    cityId = s['city_id']?.toString();
    app.api.cities().then((res) {
      if (mounted) setState(() => cities = res.dataMaps);
    });
  }

  @override
  void dispose() {
    name.dispose();
    store.dispose();
    mobile.dispose();
    email.dispose();
    description.dispose();
    address.dispose();
    accountNumber.dispose();
    bankName.dispose();
    accountName.dispose();
    ifsc.dispose();
    taxName.dispose();
    taxNumber.dispose();
    panNumber.dispose();
    pincode.dispose();
    stateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ملف المتجر')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('معلومات المتجر'),
          BrandedCard(
            child: Column(
              children: [
                labeledField(name, 'الاسم'),
                labeledField(store, 'اسم المتجر'),
                labeledField(mobile, 'الجوال', type: TextInputType.phone),
                labeledField(email, 'البريد'),
                labeledField(description, 'وصف المتجر', maxLines: 3),
                labeledField(address, 'العنوان'),
                DropdownButtonFormField<String>(
                  key: ValueKey('profile-city-${cities.length}-$cityId'),
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
                  decoration: const InputDecoration(labelText: 'المدينة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('البيانات البنكية والضريبية (اختيارية)'),
          BrandedCard(
            child: Column(
              children: [
                labeledField(bankName, 'اسم البنك'),
                labeledField(accountName, 'اسم صاحب الحساب'),
                labeledField(accountNumber, 'رقم الحساب / الآيبان'),
                labeledField(ifsc, 'رمز البنك أو الفرع (اختياري)'),
                labeledField(taxName, 'الاسم الضريبي'),
                labeledField(taxNumber, 'الرقم الضريبي'),
                labeledField(panNumber, 'الرقم الضريبي الشخصي (اختياري)'),
                labeledField(
                  pincode,
                  'الرمز البريدي (اختياري)',
                  type: TextInputType.number,
                ),
                labeledField(stateCtrl, 'المحافظة / الولاية'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('الصور والهوية'),
          UploadDropZone(
            label: logoPath == null ? 'شعار المتجر' : 'تم اختيار الشعار ✓',
            selected: logoPath != null,
            subtitle: 'يظهر في صفحة متجرك',
            onTap: () async {
              final file = await pickStoreImage(
                context,
                reason:
                    'سنفتح المعرض لاختيار شعار المتجر فقط. لا نصل إلى صورك الأخرى.',
              );
              if (file != null && mounted) setState(() => logoPath = file.path);
            },
          ),
          const SizedBox(height: 12),
          UploadDropZone(
            label: proofPath == null ? 'إثبات العنوان' : 'تم اختيار الإثبات ✓',
            selected: proofPath != null,
            subtitle: 'مطلوب للتحقق من عنوان المتجر',
            onTap: () async {
              final file = await pickStoreImage(
                context,
                reason:
                    'سنفتح المعرض لاختيار إثبات العنوان فقط. لا نصل إلى صورك الأخرى.',
              );
              if (file != null && mounted)
                setState(() => proofPath = file.path);
            },
          ),
          const SizedBox(height: 12),
          UploadDropZone(
            label: nationalIdPath == null
                ? 'البطاقة الوطنية'
                : 'تم اختيار البطاقة ✓',
            selected: nationalIdPath != null,
            subtitle: 'مطلوبة إن لم تكن مرفوعة من قبل',
            onTap: () async {
              final file = await pickStoreImage(
                context,
                reason:
                    'سنفتح المعرض لاختيار صورة البطاقة الوطنية فقط. لا نصل إلى صورك الأخرى.',
              );
              if (file != null && mounted)
                setState(() => nationalIdPath = file.path);
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await confirmWrite(context)) return;
                    if (name.text.trim().isEmpty ||
                        store.text.trim().isEmpty ||
                        mobile.text.trim().isEmpty) {
                      toast(context, 'أكمل الاسم واسم المتجر والجوال');
                      return;
                    }
                    setState(() => busy = true);
                    final city = cities
                        .cast<Map<String, dynamic>?>()
                        .firstWhere(
                          (c) => '${c?['id']}' == cityId,
                          orElse: () => cities.isNotEmpty ? cities.first : null,
                        );
                    final map = <String, dynamic>{
                      'name': name.text,
                      'store_name': store.text,
                      'mobile': mobile.text,
                      'email': email.text,
                      'store_description': description.text,
                      'formatted_address': address.text,
                      'street': address.text,
                      'city_id': cityId ?? app.seller['city_id'],
                      'categories_ids': J.str(app.seller['categories']),
                      'store_url': J.str(
                        app.seller['store_url'] ??
                            app.seller['slug'] ??
                            store.text,
                      ),
                      'latitude':
                          city?['latitude'] ?? app.seller['latitude'] ?? 0,
                      'longitude':
                          city?['longitude'] ?? app.seller['longitude'] ?? 0,
                      'account_number': accountNumber.text,
                      'bank_name': bankName.text,
                      'account_name': accountName.text,
                      'ifsc_code': ifsc.text,
                      'tax_name': taxName.text,
                      'tax_number': taxNumber.text,
                      'pan_number': panNumber.text,
                      if (pincode.text.trim().isNotEmpty)
                        'pincode_id': pincode.text.trim(),
                      if (stateCtrl.text.trim().isNotEmpty)
                        'state': stateCtrl.text.trim(),
                    };
                    if (logoPath != null)
                      map['store_logo'] = await MultipartFile.fromFile(
                        logoPath!,
                        filename: 'logo.jpg',
                      );
                    if (proofPath != null)
                      map['address_proof'] = await MultipartFile.fromFile(
                        proofPath!,
                        filename: 'proof.jpg',
                      );
                    if (nationalIdPath != null)
                      map['national_id_card'] = await MultipartFile.fromFile(
                        nationalIdPath!,
                        filename: 'national_id.jpg',
                      );
                    final result = await app.api.saveSellerDetails(
                      FormData.fromMap(map),
                    );
                    if (!mounted) return;
                    setState(() => busy = false);
                    if (!context.mounted) return;
                    toast(context, result.ok ? 'تم حفظ الملف' : result.message);
                    if (result.ok) await app.refreshSession();
                  },
            child: busy ? const BusySpinner() : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ───────── أقسام المتجر (مطابق seller/seller_sections list/save/update/delete) ─────────
// الباكند: name* + is_always_available + available_from/to (H:i) + row_order + status
class SellerSectionsScreen extends StatefulWidget {
  const SellerSectionsScreen({super.key});
  @override
  State<SellerSectionsScreen> createState() => _SellerSectionsScreenState();
}

class _SellerSectionsScreenState extends State<SellerSectionsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    final r = await app.api.sellerSections(activeOnly: false);
    if (!mounted) return;
    setState(() {
      items = r.dataMaps;
      loading = false;
      error = r.ok ? null : r.failMessage;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _form([Map<String, dynamic>? item]) async {
    if (!await confirmWrite(context)) return;
    final name = TextEditingController(text: J.str(item?['name']));
    final rowOrder = TextEditingController(
      text: J.str(item?['row_order'], '0'),
    );
    bool always = item == null
        ? true
        : J.i(item['is_always_available'], 1) == 1;
    String from = J.str(item?['available_from']);
    String to = J.str(item?['available_to']);
    int status = J.i(item?['status'], 1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(item == null ? 'قسم جديد' : 'تعديل قسم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'الاسم *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rowOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الترتيب',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  title: const Text('متاح طوال الوقت'),
                  value: always,
                  onChanged: (v) => setDlg(() => always = v),
                ),
                if (!always)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.now(),
                            );
                            if (t != null)
                              setDlg(
                                () => from =
                                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                              );
                          },
                          child: Text(from.isEmpty ? 'من' : from),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.now(),
                            );
                            if (t != null)
                              setDlg(
                                () => to =
                                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                              );
                          },
                          child: Text(to.isEmpty ? 'إلى' : to),
                        ),
                      ),
                    ],
                  ),
                SwitchListTile(
                  title: const Text('نشط'),
                  value: status == 1,
                  onChanged: (v) => setDlg(() => status = v ? 1 : 0),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    name.dispose();
    rowOrder.dispose();
    if (ok != true) return;
    if (n.isEmpty) {
      if (mounted) toast(context, 'أدخل الاسم');
      return;
    }
    if (!always && (from.isEmpty || to.isEmpty)) {
      if (mounted)
        toast(context, 'حدد وقت البداية والنهاية أو اختر متاح طوال الوقت');
      return;
    }
    final body = <String, dynamic>{
      'name': n,
      'row_order': int.tryParse(rowOrder.text.trim()) ?? 0,
      'status': status,
      'is_always_available': always ? 1 : 0,
      if (!always) 'available_from': from,
      if (!always) 'available_to': to,
      if (item != null) 'id': item['id'],
    };
    final r = item == null
        ? await app.api.saveSellerSection(body)
        : await app.api.updateSellerSection(body);
    if (!mounted) return;
    toast(context, r.ok ? 'تم الحفظ' : r.message);
    if (r.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أقسام المتجر')),
      floatingActionButton: app.canWrite
          ? FloatingActionButton(
              onPressed: () => _form(),
              child: const Icon(Icons.add),
            )
          : null,
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: items.isEmpty,
        emptyText: 'لا توجد أقسام — أضف قسماً لتنظيم منتجاتك',
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final it = items[i];
            final always = J.i(it['is_always_available'], 1) == 1;
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(J.str(it['name'])),
              subtitle: Text(
                always
                    ? 'متاح طوال الوقت • ترتيب ${J.str(it['row_order'], '0')}'
                    : '${J.str(it['available_from'])} - ${J.str(it['available_to'])}',
              ),
              trailing: J.i(it['status'], 1) == 1
                  ? null
                  : const Icon(Icons.visibility_off_outlined),
              onTap: app.canWrite ? () => _form(it) : null,
              leading: app.canWrite
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await confirmWrite(context)) return;
                        final ok = await confirmAction(
                          context,
                          title: 'حذف القسم',
                          body: 'حذف ${J.str(it['name'])}؟ (تُفك منتجاته)',
                          confirmLabel: 'حذف',
                          destructive: true,
                        );
                        if (!ok || !context.mounted) return;
                        final r = await app.api.deleteSellerSection(it['id']);
                        if (!context.mounted) return;
                        toast(context, r.ok ? 'تم الحذف' : r.message);
                        if (r.ok) _load();
                      },
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }
}

// ───────── الإعدادات: ساعات العمل + تغيير اسم المستخدم وكلمة المرور ─────────
// Web parity: views/Sellers/SellerSettings.vue
// GET/POST seller/business_hours + POST system_users/change_password
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool loading = true;
  bool busyHours = false;
  bool busyPass = false;
  bool busyOpen = false;
  String storeName = '';
  String openingTime = '';
  String closingTime = '';
  String statusOverride = 'auto';
  bool isOpen = true;
  String? nextOpeningAt;
  String? nextOpeningDate;

  final username = TextEditingController();
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    username.text = J.str(app.user?['username']);
    _load();
  }

  @override
  void dispose() {
    username.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  static String normTime(String v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(v.trim());
    if (m == null) return '';
    return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final r = await app.api.businessHours();
    if (!mounted) return;
    setState(() => loading = false);
    if (!r.ok) {
      toast(context, r.message);
      return;
    }
    final d = r.dataMap;
    setState(() {
      storeName = J.str(d['store_name']);
      openingTime = normTime(J.str(d['opening_time']));
      closingTime = normTime(J.str(d['closing_time']));
      isOpen = d['is_open'] != false;
      final ov = J.str(d['status_override']);
      statusOverride = (ov == 'open' || ov == 'closed') ? ov : 'auto';
      final n = J.str(d['next_opening_at']);
      nextOpeningAt = n.isEmpty ? null : n;
      final nd = J.str(d['next_opening_date']);
      nextOpeningDate = nd.isEmpty ? null : nd;
    });
  }

  Future<TimeOfDay?> _pick(String current) async {
    TimeOfDay initial = TimeOfDay.now();
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(current);
    if (m != null) {
      initial = TimeOfDay(
        hour: int.parse(m.group(1)!) % 24,
        minute: int.parse(m.group(2)!),
      );
    }
    return showTimePicker(context: context, initialTime: initial);
  }

  static String fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _saveHours() async {
    if (!await confirmWrite(context)) return;
    setState(() => busyHours = true);
    final r = await app.api.saveBusinessHours(
      openingTime: openingTime,
      closingTime: closingTime,
    );
    if (!mounted) return;
    setState(() => busyHours = false);
    toast(context, r.ok ? 'تم الحفظ' : r.message);
    if (r.ok) _load();
  }

  Future<void> _setStatusOverride(String? value) async {
    if (busyOpen || value == null || value == statusOverride) return;
    setState(() => busyOpen = true);
    final r = await app.api.saveBusinessHours(
      openingTime: openingTime,
      closingTime: closingTime,
      statusOverride: value,
    );
    if (!mounted) return;
    setState(() => busyOpen = false);
    if (!r.ok) {
      toast(context, r.message);
      return;
    }
    await _load();
    if (!mounted) return;
    toast(
      context,
      statusOverride == value
          ? 'تم تحديث حالة المتجر'
          : 'الخادم لم يطبّق الحالة اليدوية؛ حدّث الباك اند ثم أعد المحاولة.',
    );
  }

  Future<void> _savePassword() async {
    if (username.text.trim().isEmpty ||
        currentPassword.text.isEmpty ||
        newPassword.text.isEmpty) {
      toast(context, 'أكمل جميع الحقول');
      return;
    }
    if (newPassword.text != confirmPassword.text) {
      toast(context, 'كلمتا المرور غير متطابقتين');
      return;
    }
    if (!await confirmWrite(context)) return;
    setState(() => busyPass = true);
    final r = await app.api.changePassword({
      'username': username.text.trim(),
      'current_password': currentPassword.text,
      'password': newPassword.text,
      'confirm_password': confirmPassword.text,
    });
    if (!mounted) return;
    setState(() => busyPass = false);
    if (!r.ok) {
      toast(context, r.message);
      return;
    }
    toast(context, 'تم الحفظ');
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: null,
        isEmpty: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('ساعات عمل المتجر'),
            BrandedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (storeName.isNotEmpty)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          storeName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isOpen ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isOpen ? 'مفتوح الآن' : 'مغلق الآن',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (!isOpen && nextOpeningAt != null)
                          Text(
                            '$nextOpeningAt${nextOpeningDate != null ? ' ($nextOpeningDate)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('store-status-$statusOverride'),
                          initialValue: statusOverride,
                          decoration: const InputDecoration(
                            labelText: 'حالة المتجر',
                            helperText:
                                'تلقائي يتبع الساعات، واليدوي يتجاوزها حتى تعيده',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'auto',
                              child: Text('حسب ساعات العمل'),
                            ),
                            DropdownMenuItem(
                              value: 'open',
                              child: Text('فتح الآن'),
                            ),
                            DropdownMenuItem(
                              value: 'closed',
                              child: Text('إغلاق الآن'),
                            ),
                          ],
                          onChanged: busyOpen ? null : _setStatusOverride,
                        ),
                      ),
                      if (busyOpen)
                        const Padding(
                          padding: EdgeInsets.only(top: 18, right: 8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await _pick(openingTime);
                            if (t != null) setState(() => openingTime = fmt(t));
                          },
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            openingTime.isEmpty
                                ? 'وقت الفتح'
                                : 'الفتح: $openingTime',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await _pick(closingTime);
                            if (t != null) setState(() => closingTime = fmt(t));
                          },
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            closingTime.isEmpty
                                ? 'وقت الإغلاق'
                                : 'الإغلاق: $closingTime',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text('بيانات المتجر / ملفي'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busyHours ? null : _saveHours,
                      child: busyHours
                          ? const BusySpinner()
                          : const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader('تغيير اسم المستخدم وكلمة المرور'),
            BrandedCard(
              child: Column(
                children: [
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: currentPassword,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPassword,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPassword,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busyPass ? null : _savePassword,
                      child: busyPass ? const BusySpinner() : const Text('حفظ'),
                    ),
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
