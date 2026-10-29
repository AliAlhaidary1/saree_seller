import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/formatters.dart';
import '../core/json_util.dart';
import '../core/theme.dart';
import '../widgets/branded_skeleton.dart';
import '../widgets/common.dart';

// ───────── SellerOrders new commerce system ─────────
class SellerOrdersNewScreen extends StatefulWidget {
  const SellerOrdersNewScreen({super.key});
  @override
  State<SellerOrdersNewScreen> createState() => _SellerOrdersNewScreenState();
}

class _SellerOrdersNewScreenState extends State<SellerOrdersNewScreen> {
  List<Map<String, dynamic>> items = [];
  int total = 0;
  bool loading = true;
  String? error;
  // فلاتر الصفحة: pending/preparing/ready/cancelled — طبق seller/orders/page.jsx
  String filter = '';
  static const filters = ['', 'pending', 'preparing', 'ready', 'cancelled'];
  static const filterLabels = {
    '': 'الكل',
    'pending': 'بانتظار التجهيز',
    'preparing': 'قيد التجهيز',
    'ready': 'جاهز',
    'cancelled': 'ملغي',
  };
  static const deliveryStatuses = [
    'unassigned',
    'assigned',
    'accepted',
    'picking_up',
    'picked_up',
    'out_for_delivery',
    'delivered',
    'failed',
    'cancelled',
  ];
  static const sorts = ['followup', 'newest', 'oldest'];
  static const sortLabels = {
    'followup': 'المتابعة أولاً',
    'newest': 'الأحدث أولاً',
    'oldest': 'الأقدم أولاً',
  };
  String deliveryStatus = '';
  // الأقدم أولاً افتراضياً (FIFO) — مثل الويب.
  String sort = 'oldest';
  bool returnsOnly = false;
  String preset = '';
  String startDate = '';
  String endDate = '';
  final searchCtrl = TextEditingController();

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  static String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _applyPreset(String name) {
    final now = DateTime.now();
    if (name == '') {
      setState(() {
        preset = '';
        startDate = '';
        endDate = '';
      });
    } else if (name == 'today') {
      final s = fmt(now);
      setState(() {
        preset = name;
        startDate = s;
        endDate = s;
      });
    } else if (name == 'yesterday') {
      final y = now.subtract(const Duration(days: 1));
      final s = fmt(y);
      setState(() {
        preset = name;
        startDate = s;
        endDate = s;
      });
    } else if (name == 'week') {
      setState(() {
        preset = name;
        startDate = fmt(now.subtract(const Duration(days: 6)));
        endDate = fmt(now);
      });
    } else if (name == 'month') {
      setState(() {
        preset = name;
        startDate = fmt(DateTime(now.year, now.month, 1));
        endDate = fmt(now);
      });
    }
    _load();
  }

  int get activeFilterCount {
    var n = 0;
    if (startDate.isNotEmpty || endDate.isNotEmpty) n++;
    if (deliveryStatus.isNotEmpty) n++;
    if (filter.isNotEmpty) n++;
    if (returnsOnly) n++;
    if (searchCtrl.text.trim().isNotEmpty) n++;
    return n;
  }

  void _clearAll() {
    searchCtrl.clear();
    setState(() {
      filter = '';
      deliveryStatus = '';
      sort = 'oldest';
      returnsOnly = false;
      preset = '';
      startDate = '';
      endDate = '';
    });
    _load();
  }

  int page = 1;
  int lastPage = 1;
  bool loadingMore = false;

  Future<void> _load({bool more = false}) async {
    if (more) {
      if (loadingMore || page >= lastPage) return;
      setState(() => loadingMore = true);
    } else {
      setState(() {
        loading = true;
        error = null;
        page = 1;
        lastPage = 1;
      });
    }
    final r = await app.api.sellerOrders(
      fulfillmentStatus: filter.isEmpty ? null : filter,
      deliveryStatus: deliveryStatus.isEmpty ? null : deliveryStatus,
      search: searchCtrl.text.trim().isEmpty ? null : searchCtrl.text.trim(),
      sort: sort,
      hasReturn: returnsOnly,
      // عند فلتر المرتجعات تُتجاهل تواريخ الإنشاء (الإرجاع يُطلب لاحقاً)
      startDate: returnsOnly ? '' : startDate,
      endDate: returnsOnly ? '' : endDate,
      page: more ? page + 1 : 1,
    );
    if (!mounted) return;
    final list = r.dataMaps.isNotEmpty ? r.dataMaps : r.list('seller_orders');
    final pg = r.dataMap;
    setState(() {
      items = more ? [...items, ...list] : list;
      total = J.i(pg['total'], more ? total : list.length);
      page = J.i(pg['current_page'], more ? page + 1 : 1);
      lastPage = J.i(pg['last_page'], 1);
      loading = false;
      loadingMore = false;
      error = r.ok ? null : r.failMessage;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Color _fulfillmentColor(String s) {
    switch (s) {
      case 'ready':
        return Colors.green;
      case 'preparing':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('طلباتي ($total)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'بحث برقم الطلب/الجوال',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sort,
                      isDense: true,
                      items: sorts
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(sortLabels[s]!),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => sort = v);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('delivery-$deliveryStatus'),
                    initialValue: deliveryStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('الكل')),
                      ...deliveryStatuses.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(Fmt.delivery(s)),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => deliveryStatus = v ?? '');
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('فيها إرجاع'),
                  selected: returnsOnly,
                  onSelected: (v) {
                    setState(() => returnsOnly = v);
                    _load();
                  },
                ),
                if (activeFilterCount > 0) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: Text('مسح ($activeFilterCount)'),
                  ),
                ],
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ...filters.map((f) {
                  final active = filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filterLabels[f]!),
                      selected: active,
                      onSelected: (_) {
                        if (filter == f) return;
                        setState(() => filter = f);
                        _load();
                      },
                    ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('|', style: TextStyle(color: Colors.grey)),
                ),
                ...['', 'today', 'yesterday', 'week', 'month'].map((p) {
                  const labels = {
                    '': 'كل الفترات',
                    'today': 'اليوم',
                    'yesterday': 'أمس',
                    'week': 'أسبوع',
                    'month': 'شهر',
                  };
                  final active = preset == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(labels[p]!),
                      selected: active,
                      onSelected: (_) => _applyPreset(p),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      Icons.date_range,
                      size: 16,
                      color: startDate.isNotEmpty ? AppColors.orange : null,
                    ),
                    label: Text(
                      startDate.isNotEmpty
                          ? '$startDate → $endDate'
                          : 'فترة مخصصة',
                    ),
                    onPressed: () async {
                      final s = await pickDate(context);
                      if (s == null || !context.mounted) return;
                      final e = await pickDate(context);
                      if (e == null) return;
                      setState(() {
                        preset = 'custom';
                        startDate = s;
                        endDate = e;
                      });
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FetchBody(
              loading: loading,
              onRefresh: _load,
              error: error,
              isEmpty: items.isEmpty,
              emptyText: 'لا توجد طلبات مطابقة للفلاتر الحالية',
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length + (page < lastPage ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  if (i >= items.length) {
                    // ترقيم الصفحات — الباكند يرقّم 20 لكل صفحة.
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: loadingMore
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                                onPressed: () => _load(more: true),
                                child: Text(
                                  'عرض المزيد (${total - items.length})',
                                ),
                              ),
                      ),
                    );
                  }
                  final o = items[i];
                  final fulfillment = J.str(
                    o['fulfillment_status'] ?? o['status'],
                  );
                  final fc = _fulfillmentColor(fulfillment);
                  final itemsList = J.maps(o['items']);
                  final courier = J.map(o['delivery_assignment']);
                  return BrandedCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SellerOrderNewDetailsScreen(id: '${o['id']}'),
                      ),
                    ).then((_) => _load()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'طلب #${J.str(o['public_id']).isNotEmpty ? o['public_id'] : o['id']} (مجموعة ${J.str(o['checkout_group'] is Map ? (o['checkout_group']['public_id'] ?? o['checkout_group_id']) : o['checkout_group_id'] ?? '')})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: fc.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                Fmt.fulfillment(fulfillment).isEmpty
                                    ? '—'
                                    : Fmt.fulfillment(fulfillment),
                                style: TextStyle(
                                  color: fc,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'العميل: ${J.str(o['customer_name'])} (${J.str(o['customer_mobile'])})',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          Fmt.date(o['created_at'], withTime: true),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'الأصناف: ${itemsList.length} | الإجمالي: ${Fmt.money(o['final_total'])}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          'الدفع: ${Fmt.paymentMethod(o['payment_method'])} (${Fmt.payment(o['payment_status'])}) | المتوقع نقداً: ${Fmt.money(o['cod_expected_amount'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'التوصيل: ${Fmt.delivery(o['delivery_status'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (courier.isNotEmpty)
                          Text(
                            'مهمة المندوب #${courier['id']}: ${Fmt.delivery(courier['status'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (itemsList.isNotEmpty) ...[
                          const Divider(),
                          ...itemsList.map(
                            (it) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${J.str(it['product_name'])} x${it['quantity'] ?? 1} — ${Fmt.money(it['sub_total'])}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    Fmt.status(it['active_status']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SellerOrderNewDetailsScreen extends StatefulWidget {
  const SellerOrderNewDetailsScreen({super.key, required this.id});
  final String id;
  @override
  State<SellerOrderNewDetailsScreen> createState() =>
      _SellerOrderNewDetailsScreenState();
}

class _SellerOrderNewDetailsScreenState
    extends State<SellerOrderNewDetailsScreen> {
  Map<String, dynamic> order = {};
  bool loading = true;
  String? error;
  bool busy = false;
  Future<void> _load() async {
    final r = await app.api.sellerOrderById(widget.id);
    if (!mounted) return;
    setState(() {
      order = r.dataMap.isNotEmpty
          ? r.dataMap
          : (r.dataMaps.isNotEmpty ? r.dataMaps.first : {});
      loading = false;
      error = r.ok || order.isNotEmpty ? null : r.failMessage;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String> get _allowed {
    final v = order['allowed_next_fulfillment'];
    if (v is List) return v.map((e) => '$e').toList();
    return [];
  }

  List<Map<String, dynamic>> get _activeItems => J
      .maps(order['items'])
      .where((it) => J.str(it['active_status']) != 'cancelled')
      .toList();

  Future<void> _fulfill(String status) async {
    if (busy) return;
    if (!await confirmWrite(context)) return;
    setState(() => busy = true);
    final r = await app.api.sellerOrderFulfillment(
      id: widget.id,
      status: status,
    );
    if (!mounted) return;
    setState(() => busy = false);
    toast(
      context,
      r.ok ? 'تم التحديث إلى ${Fmt.fulfillment(status)}' : r.message,
    );
    if (r.ok) _load();
  }

  // رفض صنف — مثل الويب: اختيار الصنف ثم السبب ثم POST reject-item
  Future<void> _rejectItem() async {
    if (busy) return;
    final active = _activeItems;
    if (active.isEmpty) {
      toast(context, 'لا توجد أصناف قابلة للرفض');
      return;
    }
    final choice = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض صنف'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: active
                .map(
                  (it) => ListTile(
                    title: Text(
                      '${J.str(it['product_name'])} x${it['quantity'] ?? 1}',
                    ),
                    subtitle: Text(Fmt.status(it['active_status'])),
                    onTap: () => Navigator.pop(ctx, it),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final reasonCtrl = TextEditingController();
    final reasonOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب رفض الصنف'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'السبب (اختياري)',
            hintText: 'مثال: نفد المخزون أو تالف',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفض الصنف'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (reasonOk != true || !mounted) return;
    if (!await confirmWrite(context)) return;
    setState(() => busy = true);
    final r = await app.api.sellerOrderRejectItem(
      id: widget.id,
      orderItemId: choice['id'],
      reason: reason.trim().isEmpty ? null : reason.trim(),
    );
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, r.ok ? 'تم رفض الصنف' : r.message);
    if (r.ok) _load();
  }

  // إلغاء الطلب — مثل الويب: سبب عبر prompt (الفارغ مسموح)
  Future<void> _cancel() async {
    if (busy) return;
    if (!await confirmWrite(context)) return;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'سبب الإلغاء (اختياري)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    final r = await app.api.sellerOrderCancel(id: widget.id, reason: reason);
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, r.ok ? 'تم الإلغاء' : r.message);
    if (r.ok) _load();
  }

  Future<void> _rejectReturn(Map<String, dynamic> item) async {
    if (busy) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('رفض المرتجع'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            maxLength: 500,
            onChanged: (_) => setD(() {}),
            decoration: const InputDecoration(
              labelText: 'سبب الرفض (إلزامي)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: ctrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('رفض المرتجع'),
            ),
          ],
        ),
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || reason.isEmpty || !mounted) return;
    if (!await confirmWrite(context)) return;
    if (!mounted) return;
    setState(() => busy = true);
    final result = await app.api.sellerOrderRejectReturn(
      id: widget.id,
      orderItemId: item['id'],
      reason: reason,
    );
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, result.ok ? 'تم رفض المرتجع وتسجيل السبب' : result.message);
    if (result.ok) _load();
  }

  Future<void> _advanceSellerDelivery(String status) async {
    if (busy) return;
    final task = J.map(order['seller_delivery_task']);
    if (task.isEmpty) return;
    String? reason;
    if (status == 'failed') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('سبب تعذر التوصيل'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'اكتب السبب'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      reason = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true || reason.isEmpty || !mounted) return;
    }

    num? cash;
    if (status == 'delivered') {
      final remaining = J.d(task['cod_remaining']);
      final ctrl = TextEditingController(text: remaining.toStringAsFixed(2));
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد التسليم والتحصيل'),
          content: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المبلغ المستلم',
              helperText: 'المتبقي ${Fmt.money(remaining)}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تم التسليم'),
            ),
          ],
        ),
      );
      cash = num.tryParse(ctrl.text.trim());
      ctrl.dispose();
      if (ok != true || cash == null || cash + 0.009 < remaining || !mounted) {
        if (ok == true && mounted)
          toast(context, 'يجب تحصيل كامل المبلغ المتبقي');
        return;
      }
    }

    setState(() => busy = true);
    final r = await app.api.sellerDeliveryTransition(
      taskId: task['id'],
      status: status,
      cashReceived: cash,
      failureReason: reason,
    );
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, r.ok ? 'تم تحديث التوصيل' : r.message);
    if (r.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return Scaffold(
        appBar: AppBar(title: Text('طلب ${widget.id}')),
        body: const BrandedSkeletonList(count: 3),
      );
    if (order.isEmpty)
      return Scaffold(
        appBar: AppBar(title: Text('طلب ${widget.id}')),
        body: FetchBody(
          loading: false,
          onRefresh: _load,
          error: error ?? 'تعذر التحميل',
          isEmpty: true,
          child: const SizedBox.shrink(),
        ),
      );
    final fulfillment = J.str(order['fulfillment_status']);
    final courier = J.map(order['delivery_assignment']);
    final sellerTask = J.map(order['seller_delivery_task']);
    final cancelled = fulfillment == 'cancelled';
    final canCancel =
        !cancelled && fulfillment != 'delivered' && fulfillment != 'completed';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'طلب #${J.str(order['public_id']).isNotEmpty ? order['public_id'] : widget.id}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrandedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الحالة: ${Fmt.fulfillment(fulfillment)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'التوصيل: ${Fmt.delivery(order['delivery_status'])}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  Fmt.date(order['created_at'], withTime: true),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (app.canViewCustomerDetail)
                  Text(
                    'العميل: ${J.str(order['customer_name'])} (${J.str(order['customer_mobile'])})',
                    style: const TextStyle(fontSize: 14),
                  ),
                Text(
                  'الدفع: ${Fmt.paymentMethod(order['payment_method'])} (${Fmt.payment(order['payment_status'])}) | المتوقع نقداً: ${Fmt.money(order['cod_expected_amount'])}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'الإجمالي: ${Fmt.money(order['final_total'])}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (courier.isNotEmpty)
                  Text(
                    'مهمة المندوب #${courier['id']}: ${Fmt.delivery(courier['status'])}',
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
            ),
          ),
          if (sellerTask.isNotEmpty) ...[
            const SizedBox(height: 12),
            BrandedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'توصيل المتجر',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('الحالة: ${Fmt.delivery(sellerTask['status'])}'),
                  Text(
                    'المتبقي للتحصيل: ${Fmt.money(sellerTask['cod_remaining'])}',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  if (app.canWrite &&
                      [
                        'pending',
                        'assigned',
                        'failed',
                      ].contains(J.str(sellerTask['status'])))
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => _advanceSellerDelivery('out_for_delivery'),
                      child: const Text('خرج للتوصيل'),
                    ),
                  if (app.canWrite &&
                      J.str(sellerTask['status']) == 'out_for_delivery')
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => _advanceSellerDelivery('delivered'),
                          child: const Text('تم التسليم والتحصيل'),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => _advanceSellerDelivery('failed'),
                          child: const Text('تعذر التوصيل'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (app.canWrite && !cancelled)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._allowed.map(
                  (s) => FilledButton(
                    onPressed: busy ? null : () => _fulfill(s),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            s == 'preparing'
                                ? 'بدء التحضير'
                                : s == 'ready'
                                ? 'جاهز للاستلام'
                                : Fmt.fulfillment(s),
                          ),
                  ),
                ),
                if (_activeItems.isNotEmpty)
                  OutlinedButton(
                    onPressed: busy ? null : _rejectItem,
                    child: const Text('رفض صنف'),
                  ),
                if (canCancel)
                  OutlinedButton(
                    onPressed: busy ? null : _cancel,
                    child: const Text(
                      'إلغاء الطلب',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          ...J
              .maps(order['items'])
              .map(
                (it) => BrandedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${J.str(it['product_name'])}${J.str(it['variant_name']).isNotEmpty ? ' — ${it['variant_name']}' : ''}',
                            ),
                          ),
                          Text(
                            'x${it['quantity'] ?? 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${Fmt.money(it['sub_total'])} | ${Fmt.status(it['active_status'])}${J.str(it['return_status']).isNotEmpty && J.str(it['return_status']) != 'none' ? ' / إرجاع: ${Fmt.status(it['return_status'])}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (app.canWrite &&
                          [
                            'requested',
                            'approved',
                            'picked_up',
                          ].contains(J.str(it['return_status']))) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _rejectReturn(it),
                          icon: const Icon(Icons.assignment_return_outlined),
                          label: const Text('رفض المرتجع مع السبب'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
