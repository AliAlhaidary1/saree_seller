import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/config.dart';
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
  final Future<bool?> Function(BuildContext context, Map<String, dynamic> item)? openEdit;
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
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final item = items[i];
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(widget.itemTitle(item)),
              subtitle: widget.itemSub == null ? null : Text(widget.itemSub!(item)),
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
  String? imagePath;
  bool busy = false;

  @override
  void initState() {
    super.initState();
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
      appBar: AppBar(title: Text(widget.item == null ? 'كود خصم جديد' : 'تعديل كود خصم')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            onChanged: (v) => setState(() => discountType = v ?? 'percentage'),
            decoration: const InputDecoration(labelText: 'نوع الخصم', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          labeledField(discount, 'قيمة الخصم', type: TextInputType.number),
          labeledField(maxDiscount, 'أقصى خصم', type: TextInputType.number),
          SwitchListTile(title: const Text('استخدام متكرر'), value: repeatUsage, onChanged: (v) => setState(() => repeatUsage = v)),
          if (repeatUsage) labeledField(repeats, 'مرات التكرار', type: TextInputType.number),
          ListTile(
            title: Text(start.isEmpty ? 'تاريخ البداية' : start),
            trailing: const Icon(Icons.event),
            onTap: () async {
              final value = await pickDate(context);
              if (value != null) setState(() => start = value);
            },
          ),
          ListTile(
            title: Text(end.isEmpty ? 'تاريخ النهاية' : end),
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
                reason: 'سنفتح المعرض لاختيار صورة العرض فقط. لا نصل إلى صورك الأخرى.',
              );
              if (file != null && mounted) setState(() => imagePath = file.path);
            },
            icon: const Icon(Icons.image),
            label: Text(imagePath == null ? 'صورة (اختياري)' : 'تم اختيار الصورة'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await confirmWrite(context)) return;
                    if (code.text.trim().isEmpty || discount.text.trim().isEmpty) {
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
                      'status': 1,
                      'scope_type': 'all',
                      if (widget.item != null) 'id': widget.item!['id'],
                    };
                    if (imagePath != null) {
                      map['image'] = await MultipartFile.fromFile(imagePath!, filename: 'promo.jpg');
                    }
                    final data = FormData.fromMap(map);
                    final result = widget.item == null ? await app.api.savePromo(data) : await app.api.updatePromo(data);
                    if (!mounted) return;
                    setState(() => busy = false);
                    toast(context, result.ok ? 'تم الحفظ' : result.message);
                    if (result.ok) Navigator.pop(context, true);
                  },
            child: busy ? const BusySpinner() : const Text('حفظ'),
          ),
        ],
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
      appBar: AppBar(title: Text(widget.item == null ? 'عرض فلاش جديد' : 'تعديل عرض فلاش')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          labeledField(title, 'العنوان'),
          labeledField(description, 'الوصف', maxLines: 3),
          DropdownButtonFormField<String>(
            key: ValueKey('flash-${products.length}-$productId'),
            initialValue: dropdownId(productId, products),
            items: products.map((p) => DropdownMenuItem(value: '${p['id']}', child: Text(J.str(p['name'])))).toList(),
            onChanged: (v) => setState(() => productId = v),
            decoration: const InputDecoration(labelText: 'المنتج', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          labeledField(discount, 'نسبة الخصم %', type: TextInputType.number),
          ListTile(
            title: Text(start.isEmpty ? 'يبدأ' : start),
            onTap: () async {
              final value = await pickDate(context, withTime: true);
              if (value != null) setState(() => start = value);
            },
          ),
          ListTile(
            title: Text(end.isEmpty ? 'ينتهي' : end),
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
                      {'product_id': int.tryParse(productId!) ?? productId, 'discount_type': 'percentage', 'discount_value': discount.text, 'status': 1},
                    ]);
                    final data = FormData.fromMap({
                      'title': title.text,
                      'description': description.text,
                      'start_at': start,
                      'end_at': end,
                      'items': items,
                      'status': 1,
                      if (widget.item != null) 'id': widget.item!['id'],
                    });
                    final result = widget.item == null ? await app.api.saveFlash(data) : await app.api.updateFlash(data);
                    if (!mounted) return;
                    setState(() => busy = false);
                    toast(context, result.ok ? 'تم الحفظ' : result.message);
                    if (result.ok) Navigator.pop(context, true);
                  },
            child: busy ? const BusySpinner() : const Text('حفظ'),
          ),
        ],
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
  final percent = TextEditingController(text: '100');
  String start = '';
  String end = '';
  String? productId;
  String? getProductId;
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
      percent.text = J.str(item['get_discount_percent'], '100');
      start = J.str(item['start_date']);
      end = J.str(item['end_date']);
      productId = '${item['product_id'] ?? ''}';
      getProductId = item['get_product_id'] == null ? null : '${item['get_product_id']}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'عرض اشترِ واحصل' : 'تعديل العرض')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          labeledField(title, 'العنوان (اختياري)'),
          DropdownButtonFormField<String>(
            key: ValueKey('bxgy-buy-${products.length}-$productId'),
            initialValue: dropdownId(productId, products),
            items: products.map((p) => DropdownMenuItem(value: '${p['id']}', child: Text(J.str(p['name'])))).toList(),
            onChanged: (v) => setState(() => productId = v),
            decoration: const InputDecoration(labelText: 'المنتج المشترى', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('bxgy-get-${products.length}-$getProductId'),
            initialValue: products.any((p) => '${p['id']}' == getProductId) ? getProductId : '',
            items: [
              const DropdownMenuItem(value: '', child: Text('نفس المنتج')),
              ...products.map((p) => DropdownMenuItem(value: '${p['id']}', child: Text(J.str(p['name'])))),
            ],
            onChanged: (v) => setState(() => getProductId = (v == null || v.isEmpty) ? null : v),
            decoration: const InputDecoration(labelText: 'المنتج المهدى', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          labeledField(buyQty, 'كمية الشراء', type: TextInputType.number),
          labeledField(getQty, 'كمية الهدية', type: TextInputType.number),
          labeledField(percent, 'نسبة خصم الهدية %', type: TextInputType.number),
          ListTile(
            title: Text(start.isEmpty ? 'تاريخ البداية' : start),
            onTap: () async {
              final value = await pickDate(context);
              if (value != null) setState(() => start = value);
            },
          ),
          ListTile(
            title: Text(end.isEmpty ? 'تاريخ النهاية' : end),
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
                      'get_discount_percent': percent.text,
                      'start_date': start,
                      'end_date': end,
                      'status': 1,
                      if (widget.item != null) 'id': widget.item!['id'],
                    };
                    final result = widget.item == null ? await app.api.saveBxgy(body) : await app.api.updateBxgy(body);
                    if (!mounted) return;
                    setState(() => busy = false);
                    toast(context, result.ok ? 'تم الحفظ' : result.message);
                    if (result.ok) Navigator.pop(context, true);
                  },
            child: busy ? const BusySpinner() : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class CategoryDiscountFormScreen extends StatefulWidget {
  const CategoryDiscountFormScreen({super.key, this.item});
  final Map<String, dynamic>? item;

  @override
  State<CategoryDiscountFormScreen> createState() => _CategoryDiscountFormScreenState();
}

class _CategoryDiscountFormScreenState extends State<CategoryDiscountFormScreen> {
  final title = TextEditingController();
  final discount = TextEditingController();
  final maxDiscount = TextEditingController(text: '0');
  String type = 'percentage';
  String start = '';
  String end = '';
  String? categoryId;
  List<Map<String, dynamic>> categories = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    app.api.categories().then((res) {
      if (mounted) setState(() => categories = res.dataMaps);
    });
    final item = widget.item;
    if (item != null) {
      title.text = J.str(item['title']);
      discount.text = J.str(item['discount']);
      maxDiscount.text = J.str(item['max_discount_amount'], '0');
      type = J.str(item['discount_type'], 'percentage');
      start = J.str(item['start_date']);
      end = J.str(item['end_date']);
      categoryId = '${item['category_id'] ?? ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'خصم تصنيف' : 'تعديل خصم تصنيف')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          labeledField(title, 'العنوان'),
          DropdownButtonFormField<String>(
            key: ValueKey('catd-${categories.length}-$categoryId'),
            initialValue: dropdownId(categoryId, categories),
            items: categories.map((c) => DropdownMenuItem(value: '${c['id']}', child: Text(J.str(c['name'])))).toList(),
            onChanged: (v) => setState(() => categoryId = v),
            decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: type,
            items: const [
              DropdownMenuItem(value: 'percentage', child: Text('نسبة %')),
              DropdownMenuItem(value: 'amount', child: Text('مبلغ')),
            ],
            onChanged: (v) => setState(() => type = v ?? 'percentage'),
            decoration: const InputDecoration(labelText: 'نوع الخصم', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          labeledField(discount, 'قيمة الخصم', type: TextInputType.number),
          labeledField(maxDiscount, 'أقصى خصم', type: TextInputType.number),
          ListTile(
            title: Text(start.isEmpty ? 'تاريخ البداية' : start),
            onTap: () async {
              final value = await pickDate(context);
              if (value != null) setState(() => start = value);
            },
          ),
          ListTile(
            title: Text(end.isEmpty ? 'تاريخ النهاية' : end),
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
                    if (categoryId == null || categoryId!.isEmpty || discount.text.trim().isEmpty) {
                      toast(context, 'اختر التصنيف وأدخل قيمة الخصم');
                      return;
                    }
                    if (start.isEmpty || end.isEmpty) {
                      toast(context, 'حدد تاريخ البداية والنهاية');
                      return;
                    }
                    setState(() => busy = true);
                    final body = {
                      'title': title.text,
                      'category_id': categoryId,
                      'discount_type': type,
                      'discount': discount.text,
                      'max_discount_amount': maxDiscount.text,
                      'start_date': start,
                      'end_date': end,
                      'status': 1,
                      if (widget.item != null) 'id': widget.item!['id'],
                    };
                    final result = widget.item == null ? await app.api.saveCategoryDiscount(body) : await app.api.updateCategoryDiscount(body);
                    if (!mounted) return;
                    setState(() => busy = false);
                    toast(context, result.ok ? 'تم الحفظ' : result.message);
                    if (result.ok) Navigator.pop(context, true);
                  },
            child: busy ? const BusySpinner() : const Text('حفظ'),
          ),
        ],
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
    final name = TextEditingController(text: J.str(item?['name'] ?? item?['title']));
    final extra = TextEditingController(text: J.str(item?['short_code'] ?? item?['percentage']));
    String? imagePath;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'إضافة' : 'تعديل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: widget.kind == 'taxes' ? 'الاسم' : 'الاسم')),
            if (widget.kind != 'brands')
              TextField(
                controller: extra,
                decoration: InputDecoration(labelText: widget.kind == 'units' ? 'الرمز' : 'النسبة %'),
              ),
            if (widget.kind == 'brands')
              TextButton(
                onPressed: () async {
                  final file = await pickStoreImage(
                    context,
                    reason: 'سنفتح المعرض لاختيار صورة الماركة فقط. لا نصل إلى صورك الأخرى.',
                  );
                  if (file != null) imagePath = file.path;
                },
                child: const Text('صورة الماركة'),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
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
      final body = {'name': name.text, 'short_code': extra.text, if (item != null) 'id': item['id']};
      result = item == null ? await app.api.saveUnit(body) : await app.api.updateUnit(body);
    } else if (widget.kind == 'taxes') {
      final body = {'title': name.text, 'percentage': extra.text, 'status': 1, if (item != null) 'id': item['id']};
      result = item == null ? await app.api.saveTax(body) : await app.api.updateTax(body);
    } else {
      final map = <String, dynamic>{'name': name.text, 'status': 1, if (item != null) 'id': item['id']};
      if (imagePath != null) map['image'] = await MultipartFile.fromFile(imagePath!, filename: 'brand.jpg');
      final data = FormData.fromMap(map);
      result = item == null ? await app.api.saveBrand(data) : await app.api.updateBrand(data);
    }
    if (!mounted) return;
    toast(context, result.ok ? 'تم الحفظ' : result.message);
    if (result.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: app.canWrite ? FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)) : null,
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: items.isEmpty,
        child: ListView(
                    children: items
                        .map(
                          (item) => ListTile(
                            title: Text(J.str(item['name'] ?? item['title'])),
                            subtitle: Text(J.str(item['short_code'] ?? item['percentage'] ?? '')),
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
                                      );
                                      if (!ok || !context.mounted) return;
                                      final result = switch (widget.kind) {
                                        'units' => await app.api.deleteUnit(item['id']),
                                        'taxes' => await app.api.deleteTax(item['id']),
                                        _ => await app.api.deleteBrand(item['id']),
                                      };
                                      if (!context.mounted) return;
                                      toast(context, result.ok ? 'تم الحذف' : result.message);
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

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});
  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  Future<void> _load() async {
    final result = await app.api.media();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الميديا')),
      floatingActionButton: null,
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: items.isEmpty,
        emptyText: 'لا توجد ملفات',
        child: Column(
          children: [
            if (app.canWrite)
              Padding(
                padding: const EdgeInsets.all(16),
                child: UploadDropZone(
                  label: 'رفع صور جديدة',
                  subtitle: 'PNG, JPG — اختر عدة صور',
                  onTap: () async {
                    if (!await confirmWrite(context)) return;
                    final picked = await pickStoreFiles(
                      context,
                      reason: 'سنفتح منتقي الملفات لرفع صور المنتجات فقط. لا نصل إلى ملفاتك الأخرى.',
                      multiple: true,
                    );
                    if (picked == null || picked.files.isEmpty) return;
                    final files = <MultipartFile>[];
                    for (final file in picked.files) {
                      if (file.path != null) files.add(await MultipartFile.fromFile(file.path!, filename: file.name));
                    }
                    final result = await app.api.saveMedia(FormData.fromMap({'files[]': files, 'files': files}));
                    if (!context.mounted) return;
                    toast(context, result.ok ? 'تم الرفع' : result.message);
                    if (result.ok) _load();
                  },
                ),
              ),
            Expanded(
              child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final url = AppConfig.fileUrl(
                        app.apiUrl,
                        '${item['sub_directory'] ?? ''}${item['name'] ?? item['image'] ?? ''}',
                      );
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: AppColors.greyBg, child: Icon(Icons.image, color: AppColors.textSecondary)),
                            ),
                            if (app.canWrite)
                              Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.navy.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: AppColors.white, size: 20),
                                    onPressed: () async {
                                      final ok = await confirmAction(
                                        context,
                                        title: 'حذف الملف',
                                        body: 'هل تريد حذف هذا الملف؟',
                                        confirmLabel: 'حذف',
                                      );
                                      if (!ok || !context.mounted) return;
                                      final result = await app.api.deleteMedia(item['id']);
                                      if (!context.mounted) return;
                                      toast(context, result.ok ? 'تم الحذف' : result.message);
                                      if (result.ok) _load();
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});
  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> ratings = [];
  String? productId;
  bool loading = true;
  String? error;

  Future<void> _load() async {
    final list = await app.api.products();
    products = list.dataMaps;
    productId ??= products.isNotEmpty ? '${products.first['id']}' : null;
    if (productId != null) {
      final res = await app.api.productRatings(productId: productId);
      ratings = res.dataMaps;
    }
    if (!mounted) return;
    setState(() {
      loading = false;
      error = list.ok ? null : list.failMessage;
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
      appBar: AppBar(title: const Text('تقييمات المنتجات')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Refreshable(
                  onRefresh: _load,
                  child: EmptyBox(error!, icon: Icons.wifi_off_outlined, actionLabel: 'إعادة المحاولة', onAction: () { _load(); }),
                )
          : products.isEmpty
              ? const EmptyBox('لا توجد منتجات لعرض تقييماتها')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('rating-${products.length}-$productId'),
                    initialValue: dropdownId(productId, products),
                    items: products.map((p) => DropdownMenuItem(value: '${p['id']}', child: Text(J.str(p['name'])))).toList(),
                    onChanged: (v) async {
                      productId = v;
                      final res = await app.api.productRatings(productId: productId);
                      if (mounted) setState(() => ratings = res.dataMaps);
                    },
                    decoration: const InputDecoration(labelText: 'المنتج', border: OutlineInputBorder()),
                  ),
                ),
                Expanded(
                  child: ratings.isEmpty
                      ? const EmptyBox('لا توجد تقييمات لهذا المنتج')
                      : ListView(
                    children: ratings
                        .map(
                          (r) => ListTile(
                            title: Text('${J.str(r['user'] is Map ? r['user']['name'] : r['user_name'])} • ${r['rate'] ?? r['rating']}'),
                            subtitle: Text(J.str(r['review'] ?? r['comment'])),
                            trailing: app.canWrite
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(J.flag(r['status']) ? Icons.visibility : Icons.visibility_off),
                                        onPressed: () async {
                                          await app.api.updateRatingStatus(id: r['id'], status: J.flag(r['status']) ? 0 : 1);
                                          final res = await app.api.productRatings(productId: productId);
                                          if (mounted) setState(() => ratings = res.dataMaps);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          final ok = await confirmAction(
                                            context,
                                            title: 'حذف التقييم',
                                            body: 'هل تريد حذف هذا التقييم؟',
                                            confirmLabel: 'حذف',
                                          );
                                          if (!ok || !context.mounted) return;
                                          await app.api.deleteRating(r['id']);
                                          final res = await app.api.productRatings(productId: productId);
                                          if (mounted) setState(() => ratings = res.dataMaps);
                                        },
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
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
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رفع منتجات جماعي')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('اختر ملف CSV بنفس قالب لوحة الويب. تأكد أن seller_id وcategory_id صحيحان.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickStoreFiles(
                  context,
                  reason: 'سنفتح منتقي الملفات لاختيار ملف CSV للمنتجات فقط.',
                  type: FileType.custom,
                  extensions: const ['csv'],
                );
                if (picked?.files.single.path != null && mounted) {
                  setState(() => path = picked!.files.single.path);
                }
              },
              icon: const Icon(Icons.attach_file),
              label: Text(path == null ? 'اختيار ملف CSV' : 'تم اختيار الملف'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy || path == null
                  ? null
                  : () async {
                      if (!await confirmWrite(context)) return;
                      setState(() => busy = true);
                      final result = await app.api.bulkUpload(FormData.fromMap({
                        'file': await MultipartFile.fromFile(path!, filename: 'products.csv'),
                      }));
                      if (!mounted) return;
                      setState(() => busy = false);
                      toast(context, result.ok ? 'تم الاستيراد' : result.message);
                    },
              child: busy ? const BusySpinner() : const Text('رفع'),
            ),
          ],
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
                    _chip('طلبات', summary['orders_count']),
                    _chip('فواتير', summary['invoices_count']),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('يومياً', style: TextStyle(fontWeight: FontWeight.bold)),
                if (daily.isEmpty) const ListTile(title: Text('لا توجد بيانات يومية')),
                ...daily.map((d) => ListTile(title: Text(J.str(d['date'])), trailing: Text(J.str(d['net_earnings'])))),
                const Divider(),
                const Text('الفواتير', style: TextStyle(fontWeight: FontWeight.bold)),
                if (invoices.isEmpty) const ListTile(title: Text('لا توجد فواتير')),
                ...invoices.map((inv) => ListTile(
                      title: Text('#${inv['order_id'] ?? inv['id']}'),
                      subtitle: Text(J.str(inv['created_at'] ?? inv['date'])),
                      trailing: Text(J.str(inv['total'] ?? inv['net_amount'] ?? inv['final_total'])),
                    )),
              ],
            ),
      ),
    );
  }

  Widget _chip(String label, dynamic value) {
    return Chip(label: Text('$label: ${value ?? 0}'));
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

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    end = _iso(now);
    start = _iso(now.subtract(const Duration(days: 30)));
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final a = await app.api.salesReports(startDate: start, endDate: end);
    final b = await app.api.productSalesReports(startDate: start, endDate: end);
    if (!mounted) return;
    setState(() {
      sales = a.list('salesReports').isNotEmpty ? a.list('salesReports') : a.dataMaps;
      products = b.dataMaps;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: Column(
        children: [
          ListTile(
            title: Text('من $start إلى $end'),
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
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: sales.isEmpty && products.isEmpty && !loading
                ? const EmptyBox('لا توجد تقارير لهذه الفترة')
                : ListView(
              children: [
                const ListTile(title: Text('المبيعات', style: TextStyle(fontWeight: FontWeight.bold))),
                ...sales.map((s) => ListTile(
                      title: Text(J.str(s['product_name'] ?? s['user_name'])),
                      subtitle: Text(J.str(s['added_date'] ?? s['created_at'])),
                      trailing: Text(J.str(s['sub_total'] ?? s['final_total'])),
                    )),
                const ListTile(title: Text('حسب المنتج', style: TextStyle(fontWeight: FontWeight.bold))),
                ...products.map((p) => ListTile(
                      title: Text(J.str(p['product_name'] ?? p['name'])),
                      subtitle: Text('مبيعات ${p['total_sales'] ?? '-'}'),
                      trailing: Text(J.str(p['total_price'] ?? p['sub_total'])),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> boys = [];
  bool loading = true;
  String? error;

  Future<void> _load() async {
    final result = await app.api.returnRequests();
    final db = await app.api.deliveryBoys();
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
      boys = db.dataMaps;
      loading = false;
      error = result.ok ? null : result.failMessage;
    });
  }

  String _status(dynamic value) {
    switch (J.i(value)) {
      case 2:
        return 'مقبول';
      case 3:
        return 'مرفوض';
      default:
        return 'قيد الانتظار';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الإرجاع')),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: items.isEmpty,
        emptyText: 'لا توجد طلبات إرجاع',
        child: ListView(
                    children: items
                        .map(
                          (item) => ListTile(
                            title: Text('${J.str(item['product_name'])} • ${J.str(item['name'])}'),
                            subtitle: Text('${_status(item['status'])} • ${J.str(item['reason'] ?? item['remarks'])}'),
                            trailing: J.i(item['status']) != 1 || !app.canWrite
                                ? null
                                : PopupMenuButton<int>(
                                    onSelected: (status) async {
                                      final ok = await confirmAction(
                                        context,
                                        title: status == 2 ? 'قبول الإرجاع' : 'رفض الإرجاع',
                                        body: status == 2
                                            ? 'قبول طلب الإرجاع؟'
                                            : 'رفض طلب الإرجاع؟',
                                      );
                                      if (!ok || !context.mounted) return;
                                      dynamic boy;
                                      if (status == 2 && boys.isNotEmpty) {
                                        boy = boys.first['id'];
                                      }
                                      final result = await app.api.updateReturn(
                                        id: item['id'],
                                        status: status,
                                        deliveryBoyId: boy,
                                      );
                                      if (!context.mounted) return;
                                      toast(context, result.ok ? 'تم التحديث' : result.message);
                                      if (result.ok) _load();
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 2, child: Text('قبول')),
                                      PopupMenuItem(value: 3, child: Text('رفض')),
                                    ],
                                  ),
                          ),
                        )
                        .toList(),
        ),
      ),
    );
  }
}

class MailSettingsScreen extends StatefulWidget {
  const MailSettingsScreen({super.key});
  @override
  State<MailSettingsScreen> createState() => _MailSettingsScreenState();
}

class _MailSettingsScreenState extends State<MailSettingsScreen> {
  List<Map<String, dynamic>> statuses = [];
  final mail = <int, bool>{};
  final mobile = <int, bool>{};
  final sms = <int, bool>{};
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await app.api.orderStatuses();
    final set = await app.api.mailSettings();
    statuses = st.dataMaps;
    final rows = set.dataMaps.isNotEmpty ? set.dataMaps : [set.dataMap];
    for (final status in statuses) {
      final id = J.i(status['id']);
      mail[id] = true;
      mobile[id] = true;
      sms[id] = true;
    }
    for (final row in rows) {
      final id = J.i(row['order_status_id'] ?? row['status_id']);
      if (id == 0) continue;
      mail[id] = J.flag(row['mail_status'] ?? row['mail']);
      mobile[id] = J.flag(row['mobile_status'] ?? row['mobile']);
      sms[id] = J.flag(row['sms_status'] ?? row['sms']);
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إشعارات الطلبات')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : statuses.isEmpty
              ? Refreshable(
                  onRefresh: _load,
                  child: const EmptyBox('لا توجد حالات طلب لضبط الإشعارات'),
                )
          : ListView(
              children: [
                ...statuses.map((s) {
                  final id = J.i(s['id']);
                  return ExpansionTile(
                    title: Text(J.str(s['status'] ?? s['name'])),
                    children: [
                      SwitchListTile(title: const Text('بريد'), value: mail[id] ?? true, onChanged: (v) => setState(() => mail[id] = v)),
                      SwitchListTile(title: const Text('جوال'), value: mobile[id] ?? true, onChanged: (v) => setState(() => mobile[id] = v)),
                      SwitchListTile(title: const Text('رسالة'), value: sms[id] ?? true, onChanged: (v) => setState(() => sms[id] = v)),
                    ],
                  );
                }),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!await confirmWrite(context)) return;
                            setState(() => busy = true);
                            final ids = statuses.map((s) => J.i(s['id'])).toList();
                            final result = await app.api.saveMailSettings({
                              'status_ids': ids.join(','),
                              'mail_statuses': ids.map((id) => (mail[id] ?? true) ? 1 : 0).join(','),
                              'mobile_statuses': ids.map((id) => (mobile[id] ?? true) ? 1 : 0).join(','),
                              'sms_statuses': ids.map((id) => (sms[id] ?? true) ? 1 : 0).join(','),
                            });
                            if (!mounted) return;
                            setState(() => busy = false);
                            if (!context.mounted) return;
                            toast(context, result.ok ? 'تم الحفظ' : result.message);
                          },
                    child: busy ? const BusySpinner() : const Text('حفظ'),
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
  String? cityId;
  String? logoPath;
  String? proofPath;
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
                  items: cities.map((c) => DropdownMenuItem(value: '${c['id']}', child: Text(J.str(c['name'])))).toList(),
                  onChanged: (v) => setState(() => cityId = v),
                  decoration: const InputDecoration(labelText: 'المدينة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('البيانات البنكية'),
          BrandedCard(
            child: Column(
              children: [
                labeledField(bankName, 'البنك'),
                labeledField(accountName, 'اسم الحساب'),
                labeledField(accountNumber, 'رقم الحساب'),
                labeledField(ifsc, 'رمز البنك'),
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
                reason: 'سنفتح المعرض لاختيار شعار المتجر فقط. لا نصل إلى صورك الأخرى.',
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
                reason: 'سنفتح المعرض لاختيار إثبات العنوان فقط. لا نصل إلى صورك الأخرى.',
              );
              if (file != null && mounted) setState(() => proofPath = file.path);
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await confirmWrite(context)) return;
                    if (name.text.trim().isEmpty || store.text.trim().isEmpty || mobile.text.trim().isEmpty) {
                      toast(context, 'أكمل الاسم واسم المتجر والجوال');
                      return;
                    }
                    setState(() => busy = true);
                    final city = cities.cast<Map<String, dynamic>?>().firstWhere(
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
                      'store_url': J.str(app.seller['store_url'] ?? app.seller['slug'] ?? store.text),
                      'latitude': city?['latitude'] ?? app.seller['latitude'] ?? 0,
                      'longitude': city?['longitude'] ?? app.seller['longitude'] ?? 0,
                      'account_number': accountNumber.text,
                      'bank_name': bankName.text,
                      'account_name': accountName.text,
                      'ifsc_code': ifsc.text,
                    };
                    if (logoPath != null) map['store_logo'] = await MultipartFile.fromFile(logoPath!, filename: 'logo.jpg');
                    if (proofPath != null) map['address_proof'] = await MultipartFile.fromFile(proofPath!, filename: 'proof.jpg');
                    final result = await app.api.saveSellerDetails(FormData.fromMap(map));
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
