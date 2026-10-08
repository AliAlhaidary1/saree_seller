import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../core/app_controller.dart';
import '../core/config.dart';
import '../core/json_util.dart';
import '../core/push_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/branded_skeleton.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool? storeOpen;
  String storeHoursNote = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) app.refreshDashboard();
    });
    _loadStoreHours();
  }

  Future<void> _loadStoreHours() async {
    final r = await app.api.businessHours();
    if (!mounted) return;
    if (!r.ok) return;
    final d = r.dataMap;
    setState(() {
      storeOpen = d['is_open'] != false;
      final n = J.str(d['next_opening_at']);
      storeHoursNote = n.isEmpty
          ? ''
          : '$n${J.str(d['next_opening_date']).isNotEmpty ? ' (${J.str(d['next_opening_date'])})' : ''}';
    });
  }

  String _dashValue(Map<String, dynamic> d, List<String> keys, [String fallback = '0']) {
    for (final key in keys) {
      final v = d[key];
      if (v != null && '$v'.isNotEmpty && '$v' != 'null') return '$v';
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (app.isRejected || app.isDeactivated) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: BrandedCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 48, color: AppColors.error.withValues(alpha: 0.8)),
                    const SizedBox(height: 16),
                    Text(
                      app.isRejected
                          ? 'رُفض طلبك. تواصل مع الإدارة للموافقة.'
                          : 'حسابك معطّل. تواصل مع الإدارة للتفعيل.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (app.supportPhone.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => openTel(app.supportPhone),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('اتصال بالدعم'),
                      ),
                    TextButton(
                      onPressed: () => context.go('/account'),
                      child: const Text('حسابي والسياسات'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final d = app.dashboard;
        final totalOrders = J.i(d['order_count']);
        final pendingOrders = J.i(d['pending_order_count']);
        final completedOrders = (totalOrders - pendingOrders).clamp(0, totalOrders);
        // مطابق SellerController@index: balance + weekly_sales + counts
        String weeklySum() {
          final w = J.maps(d['weekly_sales']);
          if (w.isEmpty) return '';
          double sum = 0;
          for (final r in w) {
            sum += J.d(r['total_sale'] ?? r['total_sales'] ?? r['gross_sales']);
          }
          return sum > 0 ? sum.toStringAsFixed(2) : '';
        }
        final weeklyTotal = weeklySum();
        final totalSales = _dashValue(d, ['total_sales', 'sales', 'gross_sales'], weeklyTotal.isNotEmpty ? weeklyTotal : _dashValue(d, ['balance'], '—'));
        final balance = _dashValue(d, ['balance'], '—');
        final lowStock = _dashValue(d, ['low_stock_count'], '0');
        final soldOut = _dashValue(d, ['sold_out_count'], '0');
        final productCount = _dashValue(d, ['product_count'], '0');
        final categoryCount = _dashValue(d, ['category_count'], '0');
        final weekly = J.maps(d['weekly_sales']);
        final statusCounts = J.maps(d['status_order_count']);
        final catCounts = J.maps(d['category_product_count']);

        return RefreshIndicator(
          onRefresh: app.refreshDashboard,
          color: AppColors.orange,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (app.dashboardFailed)
                BrandedCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_outlined, color: AppColors.error),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('تعذر تحديث الرئيسية')),
                      TextButton(onPressed: app.refreshDashboard, child: Text('إعادة', style: TextStyle(color: AppColors.orange))),
                    ],
                  ),
                ),
              if (app.isPending)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_top, color: AppColors.orange, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'حسابك قيد المراجعة. يمكنك التصفح، والتعديل يتاح بعد موافقة الإدارة.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SectionHeader('ملخص الأداء'),
              if (!app.platformOpen)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.storefront, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'المنصة مغلقة حالياً — لن تصلك طلبات جديدة حتى الافتتاح.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),              LayoutBuilder(builder: (ctx, c) {
                final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 3 : 2;
                final aspect = c.maxWidth > 600 ? 1.35 : 1.15;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: aspect,
                  children: [
                    KpiMetricCard(
                      icon: Icons.payments_outlined,
                      label: 'مبيعات 7 أيام',
                      value: totalSales,
                      subtitle: 'الرصيد: $balance',
                      iconColor: AppColors.orange,
                      onTap: () => context.push('/accounting'),
                    ),
                    KpiMetricCard(
                      icon: Icons.pending_actions,
                      label: 'طلبات قيد التنفيذ',
                      value: '$pendingOrders',
                      iconColor: AppColors.orange,
                      onTap: () => context.push('/orders'),
                    ),
                    KpiMetricCard(
                      icon: Icons.check_circle_outline,
                      label: 'طلبات مكتملة',
                      value: '$completedOrders',
                      subtitle: 'الإجمالي: $totalOrders',
                      iconColor: AppColors.success,
                      onTap: () => context.push('/orders'),
                    ),
                    KpiMetricCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'المنتجات',
                      value: productCount,
                      subtitle: 'نفد: $soldOut • منخفض: $lowStock',
                      iconColor: AppColors.navy,
                      onTap: () => context.push('/products'),
                    ),
                    KpiMetricCard(
                      icon: Icons.star_outline,
                      label: 'التقييم',
                      value: _dashValue(d, ['average_rating'], '—'),
                      subtitle: 'عدد المقيمين: ${_dashValue(d, ['rating_count'], '0')}',
                      iconColor: AppColors.orange,
                      onTap: () => context.push('/ratings'),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 20),
              const SectionHeader('إجراءات سريعة'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    QuickActionButton(
                      icon: Icons.add_shopping_cart,
                      label: 'إضافة منتج',
                      onTap: app.canWrite ? () => context.push('/products/create') : () => toast(context, 'لا يمكن التعديل قبل موافقة الإدارة'),
                    ),
                    const SizedBox(width: 10),
                    QuickActionButton(
                      icon: Icons.receipt_long,
                      label: 'الطلبات الجديدة',
                      onTap: () => context.push('/orders'),
                    ),
                    const SizedBox(width: 10),
                    QuickActionButton(
                      icon: Icons.account_balance_wallet,
                      label: 'طلب سحب',
                      onTap: () => context.push('/withdrawals'),
                    ),
                    const SizedBox(width: 10),
                    BrandedCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: InkWell(
                        onTap: () => context.push('/settings'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              storeOpen == null
                                  ? Icons.store_outlined
                                  : storeOpen == true
                                      ? Icons.store
                                      : Icons.store_mall_directory_outlined,
                              color: storeOpen == null
                                  ? AppColors.textSecondary
                                  : storeOpen == true
                                      ? AppColors.success
                                      : AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  storeOpen == null
                                      ? 'ساعات العمل'
                                      : storeOpen == true
                                          ? 'مفتوح الآن'
                                          : 'مغلق الآن',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  storeHoursNote.isEmpty ? 'الإعدادات' : storeHoursNote,
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader('الإدارة'),
              LayoutBuilder(builder: (ctx, c) {
                final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 3 : 2;
                final aspect = c.maxWidth > 600 ? 1.2 : 1.05;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: aspect,
                  children: [
                    DashboardShortcutCard(icon: Icons.receipt_long, title: 'الطلبات', value: '$totalOrders', path: '/orders'),
                    DashboardShortcutCard(icon: Icons.inventory_2, title: 'المنتجات', value: productCount, path: '/products'),
                    DashboardShortcutCard(icon: Icons.warning_amber, title: 'نفد المخزون', value: soldOut, path: '/stock/sold_out'),
                    DashboardShortcutCard(icon: Icons.category_outlined, title: 'التصنيفات', value: categoryCount, path: '/categories'),
                    DashboardShortcutCard(icon: Icons.account_balance, title: 'المحاسبة', path: '/accounting'),
                    DashboardShortcutCard(icon: Icons.account_balance_wallet, title: 'المحفظة', value: balance, path: '/wallet'),
                    DashboardShortcutCard(icon: Icons.payments_outlined, title: 'السحب', path: '/withdrawals'),
                    DashboardShortcutCard(icon: Icons.bar_chart, title: 'التقارير', path: '/reports'),
                    DashboardShortcutCard(icon: Icons.assignment_return, title: 'الإرجاع', path: '/returns'),
                    DashboardShortcutCard(icon: Icons.local_offer, title: 'أكواد الخصم', path: '/promos'),
                    DashboardShortcutCard(icon: Icons.flash_on, title: 'عروض فلاش', path: '/flash'),
                    DashboardShortcutCard(icon: Icons.card_giftcard, title: 'اشترِ واحصل', path: '/bxgy'),
                    DashboardShortcutCard(icon: Icons.discount, title: 'خصم تصنيف', path: '/category-discounts'),
                    DashboardShortcutCard(icon: Icons.layers_outlined, title: 'أقسام المتجر', path: '/sections'),
                    DashboardShortcutCard(icon: Icons.campaign_outlined, title: 'الحملات', path: '/campaigns'),
                    DashboardShortcutCard(icon: Icons.storefront_outlined, title: 'واجهة المتجر', path: '/storefront'),
                    DashboardShortcutCard(icon: Icons.shopping_bag_outlined, title: 'طلبات التجارة', value: '$pendingOrders', path: '/seller-orders'),
                    DashboardShortcutCard(icon: Icons.table_chart_outlined, title: 'تصدير المحاسبة', path: '/accounting'),
                  ],
                );
              }),
              const SizedBox(height: 20),
              if (weekly.isNotEmpty) ...[
                const SectionHeader('مبيعات آخر 7 أيام'),
                BrandedCard(
                  child: Column(
                    children: weekly.take(7).map((w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(J.str(w['order_date']), style: const TextStyle(fontSize: 13)),
                          Text(J.str(w['total_sale']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (statusCounts.isNotEmpty) ...[
                const SectionHeader('الطلبات حسب الحالة'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: statusCounts.map((s) => Chip(
                    label: Text('${J.str(s['status'])}: ${J.str(s['order_count'], '0')}'),
                  )).toList(),
                ),
                const SizedBox(height: 20),
              ],
              if (catCounts.isNotEmpty) ...[
                const SectionHeader('منتجات حسب التصنيف'),
                BrandedCard(
                  child: Column(
                    children: catCounts.take(8).map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(J.str(c['name']), style: const TextStyle(fontSize: 13))),
                          Text(J.str(c['product_count'], '0'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> statuses = [];
  Map<String, dynamic>? statusCounts;
  bool loading = true;
  String? error;
  bool gridView = false;
  final searchCtrl = TextEditingController();
  int? statusId;
  String startDate = '';
  String endDate = '';

  @override
  void initState() {
    super.initState();
    _load();
    app.api.orderStatuses().then((r) {
      if (mounted && r.ok) setState(() => statuses = r.dataMaps);
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    // مطابق SellerController@getOrders: search/status/startDate/endDate
    final result = await app.api.orders(
      search: searchCtrl.text.trim(),
      statusId: statusId,
      startDate: startDate,
      endDate: endDate,
    );
    if (!mounted) return;
    setState(() {
      final list = result.list('orders');
      items = list.isNotEmpty ? list : result.dataMaps;
      final counts = J.maps(result.dataMap['status_order_count']);
      if (counts.isNotEmpty) {
        statusCounts = {for (final c in counts) '${c['id']}': c};
      }
      loading = false;
      error = result.ok ? null : result.failMessage;
    });
  }

  int get _newCount => items.where((o) {
        final s = J.str(o['order_status'] ?? o['active_status']).toLowerCase();
        return s.contains('جديد') || s.contains('new') || s.contains('pending') || s.contains('انتظار');
      }).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات'),
        actions: [
          if (_newCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(20)),
                  child: Text('$_newCount جديد', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          IconButton(
            tooltip: gridView ? 'عرض قائمة' : 'عرض شبكة',
            onPressed: () => setState(() => gridView = !gridView),
            icon: Icon(gridView ? Icons.view_list : Icons.grid_view),
          ),
        ],
      ),
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
                      hintText: 'بحث برقم الطلب/العميل',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                if (statuses.isNotEmpty)
                  DropdownButton<int?>(
                    value: statusId,
                    hint: const Text('الحالة'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('الكل')),
                      ...statuses.map((s) => DropdownMenuItem(
                            value: J.i(s['id']),
                            child: Text(J.str(s['status'] ?? s['name'])),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => statusId = v);
                      _load();
                    },
                  ),
                IconButton(
                  tooltip: 'الفترة',
                  onPressed: () async {
                    final s = await pickDate(context);
                    if (s == null || !context.mounted) return;
                    final e = await pickDate(context);
                    if (e == null) return;
                    setState(() {
                      startDate = s;
                      endDate = e;
                    });
                    _load();
                  },
                  icon: Icon(Icons.date_range, color: (startDate.isNotEmpty) ? AppColors.orange : null),
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
              emptyText: 'لا توجد طلبات حالياً',
              child: gridView ? _buildGrid() : _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _orderCard(items[i]),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 3 : 2;
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: cols > 2 ? 1.0 : 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _orderCard(items[i], compact: true),
      );
    });
  }

  Widget _orderCard(Map<String, dynamic> order, {bool compact = false}) {
    final status = J.str(order['order_status'] ?? order['active_status']);
    final id = order['order_id'] ?? order['id'];
    // إصلاح Spacer الذي كان يسبب overflow في ListView غير محدود الارتفاع
    return BrandedCard(
      padding: EdgeInsets.all(compact ? 12 : 16),
      onTap: () => context.push('/orders/$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long, color: AppColors.orange, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#$id', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(J.str(order['user_name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OrderStatusBadge(status: status),
          const SizedBox(height: 8),
          Text(
            '${order['final_total'] ?? order['total'] ?? '—'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.id});
  final String id;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> statuses = [];
  List<Map<String, dynamic>> boys = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await app.api.orderById(widget.id);
    final st = await app.api.orderStatuses();
    final db = await app.api.deliveryBoys();
    if (!mounted) return;
    setState(() {
      order = result.dataMaps.isNotEmpty ? result.dataMaps.first : result.dataMap;
      statuses = st.dataMaps;
      boys = db.dataMaps;
      loading = false;
      error = result.ok || (order != null && order!.isNotEmpty) ? null : result.failMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: BrandedSkeletonList(brand: app.brand),
      );
    }
    if (error != null || order == null || order!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('طلب ${widget.id}')),
        body: FetchBody(
          loading: false,
          onRefresh: _load,
          error: error ?? 'تعذر عرض الطلب',
          isEmpty: true,
          child: const SizedBox.shrink(),
        ),
      );
    }
    final items = J.maps(order?['items'] ?? order?['order_items']);
    final currentStatus = J.str(order?['order_status'] ?? order?['active_status']);
    return Scaffold(
      appBar: AppBar(
        title: Text('طلب ${widget.id}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(child: OrderStatusBadge(status: currentStatus)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrandedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (app.canViewCustomerDetail)
                  Text(J.str(order?['user_name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                else
                  Text('العميل محجوب حسب إعدادات الخصوصية', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                if (app.canViewCustomerDetail)
                  Text(J.str(order?['address'] ?? order?['mobile']), style: TextStyle(color: AppColors.textSecondary))
                else
                  Text('العنوان محجوب', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                if (app.canViewCustomerDetail && J.str(order?['mobile']).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => openTel(J.str(order?['mobile'])),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: const Text('اتصال'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => openSms(J.str(order?['mobile'])),
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: const Text('رسالة'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => copyText(context, J.str(order?['mobile'])),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('نسخ'),
                      ),
                    ],
                  ),
                ],
                if (!app.canViewCustomerDetail)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('إظهار بيانات العميل معطل من الإدارة (customer_privacy)', style: TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
                if (J.str(order?['otp'] ?? order?['order_otp']).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (app.canViewOrderOtp)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(8)),
                      child: Text('OTP: ${J.str(order?['otp'] ?? order?['order_otp'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else
                    Text('رمز OTP محجوب حسب الصلاحيات', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('تحديث الحالة'),
          if (!app.canChangeOrderStatusDelivered)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('تنبيه: تغيير الحالة إلى "تم التوصيل" يتطلب صلاحية خاصة من الإدارة', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((s) {
              final name = J.str(s['status'] ?? s['name']);
              final sl = name.toLowerCase();
              final isDelivered = sl.contains('deliver') || sl.contains('تم التوصيل') || sl.contains('delivered');
              final blockedDelivered = isDelivered && !app.canChangeOrderStatusDelivered;
              final isActive = currentStatus.toLowerCase() == name.toLowerCase();
              return StageActionButton(
                label: name,
                icon: _statusIcon(name),
                active: isActive,
                enabled: app.canWrite && !blockedDelivered,
                onTap: app.canWrite && !blockedDelivered
                    ? () async {
                        final ok = await confirmAction(
                          context,
                          title: 'تحديث الحالة',
                          body: 'تغيير حالة الطلب إلى $name؟',
                        );
                        if (!ok || !context.mounted) return;
                        final result = await app.api.updateStatus(orderId: widget.id, statusId: s['id']);
                        if (!context.mounted) return;
                        toast(context, result.ok ? 'تم التحديث' : result.message);
                        if (result.ok) _load();
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const SectionHeader('الأصناف'),
          if (items.isEmpty)
            BrandedCard(
              child: Text('لا توجد أصناف في هذا الطلب', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...items.map((item) => BrandedCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(J.str(item['product_name'] ?? item['name']), style: const TextStyle(fontWeight: FontWeight.w500))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.greyBg, borderRadius: BorderRadius.circular(8)),
                        child: Text('x${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 8),
          BrandedCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  '${order?['final_total']}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BrandedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('فاتورة الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                _invoiceRow('العميل', app.canViewCustomerDetail ? J.str(order?['user_name']) : '— محجوب —'),
                _invoiceRow('الجوال', app.canViewCustomerDetail ? J.str(order?['mobile']) : '— محجوب —'),
                _invoiceRow('العنوان', app.canViewCustomerDetail ? J.str(order?['address']) : '— محجوب —'),
                if (app.canViewCustomerDetail && app.canViewOrderOtp && J.str(order?['otp'] ?? order?['order_otp']).isNotEmpty)
                  _invoiceRow('OTP', J.str(order?['otp'] ?? order?['order_otp'])),
                _invoiceRow('الدفع', J.str(order?['payment_method'])),
                _invoiceRow('المجموع', '${order?['total']}'),
                _invoiceRow('النهائي', '${order?['final_total']}', bold: true),
                if (app.isHomeSeller) _invoiceRow('نوع المتجر', 'منتج منزلي'),
                if (app.requireProductsApproval) Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('ملاحظة: منتجاتك تتطلب موافقة الإدارة قبل الظهور', style: TextStyle(fontSize: 12, color: AppColors.orange)),
                ),
              ],
            ),
          ),
          if (app.canAssignDelivery) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      boys.isEmpty
                          ? 'لا يوجد مناديب متاحون حالياً — التعيين يتم من الإدارة.'
                          : 'المناديب المتاحون (${boys.length}) — التعيين يتم من الإدارة.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (boys.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...boys.take(5).map((b) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(J.str(b['name'])),
                    subtitle: Text(J.str(b['mobile'] ?? '')),
                  )),
            ],
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('جديد') || s.contains('new') || s.contains('received')) return Icons.inbox;
    if (s.contains('تحضير') || s.contains('prepar')) return Icons.restaurant;
    if (s.contains('جاهز') || s.contains('pickup') || s.contains('ready')) return Icons.check_circle_outline;
    if (s.contains('dispatch') || s.contains('deliver')) return Icons.local_shipping_outlined;
    return Icons.sync;
  }
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await app.api.products(sellerId: app.sellerId);
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
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'active') {
                final r = await app.api.activeProducts();
                if (!mounted) return; toast(context, r.ok ? 'النشطة: ${r.dataMaps.length}' : r.message);
                if (r.ok) setState(() { items = r.dataMaps; });
              } else if (v == 'offers') {
                final r = await app.api.productsOffers();
                if (!mounted) return; toast(context, r.ok ? 'العروض: ${r.dataMaps.length}' : r.message);
              } else if (v == 'sold_out' || v == 'low_stock') {
                await context.push('/stock/$v');
                if (mounted) _load();
              } else if (v == 'delete_bulk') {
                if (!await confirmWrite(context)) return;
                final ok = await confirmAction(context, title: 'حذف جماعي', body: 'حذف كل المنتجات الظاهرة (${items.length})؟', confirmLabel: 'حذف');
                if (!ok || !context.mounted) return;
                final ids = items.map((e) => e['id']).toList();
                final r = await app.api.deleteProductsBulk(ids);
                if (!context.mounted) return; toast(context, r.ok ? 'تم الحذف الجماعي' : r.message); if (r.ok) _load();
              } else if (v == 'tags') {
                final r = await app.api.productTags('a');
                if (!mounted) return; toast(context, r.ok ? 'الوسوم: ${r.dataMaps.length}' : r.message);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'active', child: Text('المنتجات النشطة (getActive)')),
              PopupMenuItem(value: 'offers', child: Text('منتجات العروض (offers)')),
              PopupMenuItem(value: 'tags', child: Text('الوسوم (tags)')),
              PopupMenuItem(value: 'sold_out', child: Text('منتجات نافدة')),
              PopupMenuItem(value: 'low_stock', child: Text('منتجات منخفضة المخزون')),
              PopupMenuItem(value: 'delete_bulk', child: Text('حذف جماعي (multiple_delete)')),
            ],
          ),
          if (app.canWrite)
            IconButton(
              tooltip: 'إضافة منتج',
              onPressed: () async {
                await context.push('/products/create');
                if (mounted) _load();
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      floatingActionButton: app.canWrite
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/products/create');
                if (mounted) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('منتج جديد'),
            )
          : null,
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: items.isEmpty,
        emptyText: 'لا توجد منتجات',
        emptyActionLabel: app.canWrite ? 'إضافة منتج' : null,
        onEmptyAction: app.canWrite
            ? () async {
                await context.push('/products/create');
                if (mounted) _load();
              }
            : null,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final p = items[i];
            final visible = p['status'] == 1 || p['status'] == '1';
            final stock = p['stock'];
            final lowStock = stock != null && J.i(stock) <= 5;
            return BrandedCard(
              onTap: () async {
                await context.push('/products/view/${p['id']}');
                if (mounted) _load();
              },
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.greyBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(Icons.inventory_2_outlined, color: AppColors.navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(J.str(p['name']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: visible ? AppColors.success.withValues(alpha: 0.1) : AppColors.greyBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                visible ? 'ظاهر' : 'مخفي',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: visible ? AppColors.success : AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'مخزون ${stock ?? '—'}',
                              style: TextStyle(fontSize: 12, color: lowStock ? AppColors.orange : AppColors.textSecondary, fontWeight: lowStock ? FontWeight.w600 : FontWeight.normal),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (app.canWrite)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تعديل',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            await context.push('/products/edit/${p['id']}');
                            if (context.mounted) _load();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () async {
                        final ok = await confirmAction(
                          context,
                          title: 'حذف المنتج',
                          body: 'سيتم حذف المنتج. هل أنت متأكد؟',
                          confirmLabel: 'حذف',
                        );
                        if (!ok || !context.mounted) return;
                        final result = await app.api.deleteProduct(p['id']);
                        if (!context.mounted) return;
                        toast(context, result.ok ? 'تم الحذف' : result.message);
                        if (result.ok) _load();
                      },
                    ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ───────── عرض المنتج (قراءة فقط) ─────────
// Web parity: views/Product/ViewProduct.vue — GET seller/products/edit/:id
class ProductViewScreen extends StatefulWidget {
  const ProductViewScreen({super.key, required this.id});
  final String id;
  @override
  State<ProductViewScreen> createState() => _ProductViewScreenState();
}

class _ProductViewScreenState extends State<ProductViewScreen> {
  Map<String, dynamic> record = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final r = await app.api.productEdit(widget.id);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (r.ok) {
        record = r.dataMap;
      } else {
        error = r.failMessage;
      }
    });
  }

  Widget _row(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: trailing ?? Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _badge(String text, bool good) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: good ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  static String plain(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  @override
  Widget build(BuildContext context) {
    final variants = J.maps(record['variants']);
    final others = J.maps(record['images']);
    final img = AppConfig.fileUrl(app.apiUrl, record['image']);
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المنتج'),
        actions: [
          if (app.canWrite && record.isNotEmpty)
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push('/products/edit/${widget.id}');
                if (mounted) _load();
              },
            ),
        ],
      ),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: record.isEmpty,
        emptyText: 'تعذر تحميل المنتج',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (J.str(record['image']).isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(img, height: 200, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 120, color: AppColors.greyBg, child: Icon(Icons.image, color: AppColors.textSecondary))),
              ),
            const SizedBox(height: 12),
            BrandedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(J.str(record['name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _row('البائع', J.str(J.map(record['seller'])['name'])),
                  _row('المعرف', J.str(record['id'])),
                  _row('الحالة', '', trailing: _badge(J.i(record['status']) == 1 ? 'نشط' : 'مخفي', J.i(record['status']) == 1)),
                  _row('الموافقة', '', trailing: _badge(J.i(record['is_approved']) == 1 ? 'معتمد' : 'غير معتمد', J.i(record['is_approved']) == 1)),
                  _row('الإرجاع', J.i(record['return_status']) == 1 ? 'مسموح' : 'غير مسموح'),
                  _row('الإلغاء', J.i(record['cancelable_status']) == 1 ? 'مسموح' : 'غير مسموح'),
                  _row('التصنيف', J.str(J.map(record['category'])['name'])),
                  _row('الضريبة', J.map(record['tax']).isEmpty ? '—' : '${J.str(J.map(record['tax'])['title'])} ${J.str(J.map(record['tax'])['percentage'])}%'),
                  _row('بلد الصنع', J.str(J.map(record['made_in_country'])['name'])),
                  _row('الشركة', J.str(record['manufacturer'])),
                ],
              ),
            ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 12),
              const SectionHeader('صور إضافية'),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: others.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(AppConfig.fileUrl(app.apiUrl, others[i]['image']),
                        width: 90, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 90, color: AppColors.greyBg)),
                  ),
                ),
              ),
            ],
            if (plain(J.str(record['description'])).isNotEmpty) ...[
              const SizedBox(height: 12),
              const SectionHeader('الوصف'),
              BrandedCard(child: Text(plain(J.str(record['description'])))),
            ],
            const SizedBox(height: 12),
            SectionHeader('الخيارات (${variants.length})'),
            ...variants.map((v) {
              final unit = J.map(v['unit']);
              final uname = unit.isEmpty ? '' : J.str(unit['short_code']);
              return BrandedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${J.str(record['name'])} ${J.str(v['measurement'])} $uname'.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 12, runSpacing: 4, children: [
                      Text('المخزون: ${J.str(v['stock'])}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('السعر: ${J.str(v['price'])}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('المخفض: ${J.str(v['discounted_price'])}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ───────── تنبيهات المخزون (نافد / منخفض) ─────────
// Web parity: views/Sellers/ProductInfo.vue — GET seller/products/product_info?type=
class StockAlertsScreen extends StatefulWidget {
  const StockAlertsScreen({super.key, required this.type});
  final String type; // sold_out | low_stock
  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  String query = '';
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final r = await app.api.productInfo(type: widget.type);
    if (!mounted) return;
    setState(() {
      items = r.dataMaps;
      loading = false;
      error = r.ok ? null : r.failMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'sold_out' ? 'منتجات نافدة' : 'منتجات منخفضة المخزون';
    final q = query.trim();
    final shown = q.isEmpty
        ? items
        : items.where((p) => J.str(p['name']).contains(q) || J.str(p['product_variant_id']).contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: shown.isEmpty,
        emptyText: 'لا توجد منتجات هنا',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: search,
                decoration: const InputDecoration(
                    labelText: 'بحث', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: shown.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = shown[i];
                  final active = J.i(p['status']) == 1;
                  final img = J.str(p['image']);
                  return BrandedCard(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: img.isEmpty
                              ? Container(width: 56, height: 56, color: AppColors.greyBg,
                                  child: Icon(Icons.image, color: AppColors.textSecondary))
                              : Image.network(AppConfig.fileUrl(app.apiUrl, img),
                                  width: 56, height: 56, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      width: 56, height: 56, color: AppColors.greyBg)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(J.str(p['name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                'السعر: ${J.str(p['price'])} • المخزون: ${J.str(p['stock'])}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'عرض',
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => context.push('/products/view/${p['product_id'] ?? p['id']}'),
                        ),
                        if (app.canWrite) ...[
                          IconButton(
                            tooltip: active ? 'إخفاء' : 'إظهار',
                            icon: Icon(active ? Icons.toggle_on : Icons.toggle_off,
                                color: active ? Colors.green : Colors.grey, size: 30),
                            onPressed: () async {
                              if (!await confirmWrite(context)) return;
                              final r = await app.api.changeProductStatus(p['product_variant_id']);
                              if (!context.mounted) return;
                              toast(context, r.ok ? 'تم التحديث' : r.message);
                              if (r.ok) _load();
                            },
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            icon: Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () async {
                              final ok = await confirmAction(context,
                                  title: 'حذف المنتج', body: 'سيتم حذف الصنف. هل أنت متأكد؟', confirmLabel: 'حذف');
                              if (!ok || !context.mounted) return;
                              final r = await app.api.deleteProduct(p['product_variant_id']);
                              if (!context.mounted) return;
                              toast(context, r.ok ? 'تم الحذف' : r.message);
                              if (r.ok) _load();
                            },
                          ),
                        ],
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

class ProductEditScreen extends StatefulWidget {
  const ProductEditScreen({super.key, this.id});
  final String? id;

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _VariantEdit {
  dynamic id;
  final measurement = TextEditingController(text: '1');
  final price = TextEditingController();
  final discounted = TextEditingController(text: '0');
  final stock = TextEditingController();
  String? unitId;
  bool active = true;
  bool isNew = true;
  void dispose() {
    measurement.dispose();
    price.dispose();
    discounted.dispose();
    stock.dispose();
  }
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final manufacturer = TextEditingController();
  final madeIn = TextEditingController();
  final returnDays = TextEditingController(text: '0');
  final deliveryCharge = TextEditingController();
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> taxes = [];
  List<Map<String, dynamic>> brands = [];
  List<Map<String, dynamic>> allTags = [];
  String? categoryId;
  String? sectionId;
  String? unitId;
  String? taxId;
  String? brandId;
  final tagIds = <int>{};
  String? imagePath;
  List<Map<String, dynamic>> existingImages = [];
  final deleteImageIds = <dynamic>[];
  final List<String> otherPaths = [];
  final List<_VariantEdit> variants = [];
  bool unlimited = false;
  bool returnable = false;
  bool taxIncluded = true;
  bool active = true;
  bool sellerDelivery = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    app.api.categories().then((res) {
      if (!mounted) return;
      categories = res.dataMaps;
      categoryId ??= categories.isNotEmpty ? '${categories.first['id']}' : null;
      setState(() {});
    });
    app.api.sellerSections().then((res) {
      if (mounted) setState(() => sections = res.dataMaps);
    });
    app.api.units().then((res) {
      if (!mounted) return;
      units = res.dataMaps;
      unitId ??= units.isNotEmpty ? '${units.first['id']}' : '1';
      setState(() {});
    });
    app.api.taxes().then((res) {
      if (mounted) setState(() => taxes = res.dataMaps);
    });
    app.api.productBrandsIndex().then((res) {
      if (mounted) setState(() => brands = res.dataMaps);
    });
    app.api.productTags('').then((res) {
      if (mounted) setState(() => allTags = res.dataMaps);
    });
    _addVariant();
    if (widget.id != null) {
      app.api.productById(widget.id).then((res) {
        if (!mounted) return;
        final p = res.dataMap;
        name.text = J.str(p['name']);
        description.text = J.str(p['description']);
        categoryId = '${p['category_id'] ?? ''}';
        sectionId = p['seller_section_id'] == null || '${p['seller_section_id']}' == '0'
            ? null
            : '${p['seller_section_id']}';
        taxId = p['tax_id'] == null || '${p['tax_id']}' == '0' ? null : '${p['tax_id']}';
        final bId = '${p['brand_id'] ?? ''}';
        brandId = (bId.isEmpty || bId == '0') ? null : bId;
        manufacturer.text = J.str(p['manufacturer']);
        madeIn.text = J.str(p['made_in']);
        returnDays.text = J.str(p['return_days'], '0');
        unlimited = J.flag(p['is_unlimited_stock']);
        returnable = J.flag(p['return_status']);
        taxIncluded = J.flag(p['tax_included_in_price'] ?? 1);
        active = J.i(p['status'], 1) == 1;
        sellerDelivery = J.flag(p['seller_delivery_enabled']);
        deliveryCharge.text = J.str(p['seller_delivery_charge']);
        for (final t in J.maps(p['tags'])) {
          final id = J.i(t['id']);
          if (id > 0) tagIds.add(id);
        }
        existingImages = J.maps(p['images']);
        final vs = J.maps(p['variants']);
        for (final v in variants) {
          v.dispose();
        }
        variants.clear();
        if (vs.isEmpty) {
          _addVariant();
        } else {
          for (final v in vs) {
            final e = _VariantEdit()
              ..id = v['id']
              ..isNew = false
              ..active = J.i(v['status'], 1) == 1;
            e.measurement.text = J.str(v['measurement'], '1');
            e.price.text = J.str(v['price']);
            e.discounted.text = J.str(v['discounted_price'], '0');
            e.stock.text = J.str(v['stock']);
            e.unitId = '${v['stock_unit_id'] ?? ''}';
            variants.add(e);
          }
        }
        setState(() {});
      });
    }
  }

  void _addVariant() => variants.add(_VariantEdit());

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    manufacturer.dispose();
    madeIn.dispose();
    returnDays.dispose();
    deliveryCharge.dispose();
    for (final v in variants) {
      v.dispose();
    }
    super.dispose();
  }

  Widget _variantCard(int index, _VariantEdit v) {
    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('خيار ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (v.isNew && variants.length > 1)
                IconButton(
                  tooltip: 'حذف الخيار',
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => setState(() {
                    v.dispose();
                    variants.removeAt(index);
                  }),
                ),
            ],
          ),
          labeledField(v.measurement, 'القياس', type: TextInputType.number),
          labeledField(v.price, 'السعر', type: TextInputType.number),
          labeledField(v.discounted, 'سعر بعد الخصم', type: TextInputType.number),
          DropdownButtonFormField<String>(
            key: ValueKey('vunit-${units.length}-${v.unitId}'),
            initialValue: units.any((u) => '${u['id']}' == v.unitId) ? v.unitId : (units.isNotEmpty ? '${units.first['id']}' : null),
            items: units.map((u) => DropdownMenuItem(value: '${u['id']}', child: Text(J.str(u['name'] ?? u['short_code'])))).toList(),
            onChanged: (val) => setState(() => v.unitId = val),
            decoration: const InputDecoration(labelText: 'وحدة المخزون'),
          ),
          const SizedBox(height: 10),
          if (!unlimited) labeledField(v.stock, 'المخزون', type: TextInputType.number),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('نشط'),
            value: v.active,
            activeThumbColor: AppColors.orange,
            onChanged: (val) => setState(() => v.active = val),
          ),
        ],
      ),
    );
  }

  Future<void> _pickOthers() async {
    final picked = await pickStoreFiles(
      context,
      reason: 'سنفتح المعرض لاختيار صور إضافية للمنتج فقط.',
      multiple: true,
    );
    if (picked == null || !mounted) return;
    setState(() {
      for (final f in picked.files) {
        if (f.path != null) otherPaths.add(f.path!);
      }
    });
  }

  static String slugify(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w ]+'), '')
      .trim()
      .replaceAll(RegExp(r' +'), '-');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'منتج جديد' : 'تعديل منتج')),
      body: SafeArea(
        child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        children: [
          const SectionHeader('معلومات المنتج'),
          BrandedCard(
            child: Column(
              children: [
                labeledField(name, 'اسم المنتج'),
                labeledField(description, 'الوصف', maxLines: 3),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('cat-${categories.length}-$categoryId'),
                  initialValue: categories.any((c) => '${c['id']}' == categoryId) ? categoryId : null,
                  items: categories.map((c) => DropdownMenuItem(value: '${c['id']}', child: Text(J.str(c['name'])))).toList(),
                  onChanged: (v) => setState(() => categoryId = v),
                  decoration: const InputDecoration(labelText: 'التصنيف *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('brand-${brands.length}-$brandId'),
                  initialValue: brands.any((b) => '${b['id']}' == brandId) ? brandId : '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('بدون ماركة')),
                    ...brands.map((b) => DropdownMenuItem(value: '${b['id']}', child: Text(J.str(b['name'])))),
                  ],
                  onChanged: (v) => setState(() => brandId = (v == null || v.isEmpty) ? null : v),
                  decoration: const InputDecoration(labelText: 'الماركة'),
                ),
                if (allTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: Text('الوسوم', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                  Wrap(
                    spacing: 6,
                    children: allTags.map((t) {
                      final id = J.i(t['id']);
                      final on = tagIds.contains(id);
                      return FilterChip(
                        label: Text(J.str(t['name'] ?? t['title'])),
                        selected: on,
                        onSelected: (_) => setState(() => on ? tagIds.remove(id) : tagIds.add(id)),
                      );
                    }).toList(),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('نشط'),
                  value: active,
                  activeThumbColor: AppColors.orange,
                  onChanged: (v) => setState(() => active = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SectionHeader('الخيارات'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(_addVariant),
                icon: const Icon(Icons.add),
                label: const Text('إضافة خيار'),
              ),
            ],
          ),
          ...variants.asMap().entries.map((e) => _variantCard(e.key, e.value)),
          const SizedBox(height: 12),
          const SectionHeader('التسعير والمخزون (عام)'),
          BrandedCard(
            child: Column(
              children: [
                if (sections.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('sec-${sections.length}-$sectionId'),
                    initialValue: sections.any((s) => '${s['id']}' == sectionId) ? sectionId : '',
                    items: [
                      const DropdownMenuItem(value: '', child: Text('بدون قسم')),
                      ...sections.map((s) => DropdownMenuItem(value: '${s['id']}', child: Text(J.str(s['name'])))),
                    ],
                    onChanged: (v) => setState(() => sectionId = (v == null || v.isEmpty) ? null : v),
                    decoration: const InputDecoration(labelText: 'قسم المتجر (اختياري)'),
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<String>(
                  key: ValueKey('tax-${taxes.length}-$taxId'),
                  initialValue: taxes.any((t) => '${t['id']}' == taxId) ? taxId : '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('بدون ضريبة')),
                    ...taxes.map((t) => DropdownMenuItem(value: '${t['id']}', child: Text(J.str(t['title'] ?? t['name'])))),
                  ],
                  onChanged: (v) => setState(() => taxId = (v == null || v.isEmpty) ? null : v),
                  decoration: const InputDecoration(labelText: 'الضريبة'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مخزون غير محدود'),
                  value: unlimited,
                  activeThumbColor: AppColors.orange,
                  onChanged: (v) => setState(() => unlimited = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الضريبة ضمن السعر'),
                  value: taxIncluded,
                  activeThumbColor: AppColors.orange,
                  onChanged: (v) => setState(() => taxIncluded = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('قابل للإرجاع'),
                  value: returnable,
                  activeThumbColor: AppColors.orange,
                  onChanged: (v) => setState(() => returnable = v),
                ),
                if (returnable) labeledField(returnDays, 'أيام الإرجاع', type: TextInputType.number),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('توصيل عبر المتجر'),
                  value: sellerDelivery,
                  activeThumbColor: AppColors.orange,
                  onChanged: (v) => setState(() => sellerDelivery = v),
                ),
                if (sellerDelivery) labeledField(deliveryCharge, 'أجرة توصيل المتجر', type: TextInputType.number),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader('تفاصيل إضافية'),
          BrandedCard(
            child: Column(
              children: [
                labeledField(manufacturer, 'الشركة المصنعة'),
                labeledField(madeIn, 'صنع في'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader('صور المنتج'),
          UploadDropZone(
            label: imagePath == null ? 'رفع الصورة الرئيسية' : 'تم اختيار الصورة ✓',
            selected: imagePath != null,
            subtitle: 'PNG أو JPG — حتى 5 م.ب',
            onTap: () async {
              final file = await pickStoreImage(
                context,
                reason: 'سنفتح المعرض لاختيار صورة المنتج فقط. لا نصل إلى صورك الأخرى.',
              );
              if (file != null && mounted) setState(() => imagePath = file.path);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickOthers,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(otherPaths.isEmpty ? 'إضافة صور إضافية' : 'صور إضافية (${otherPaths.length})'),
          ),
          if (otherPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: otherPaths.asMap().entries.map((e) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(e.value,
                          width: 72, height: 72, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 72, height: 72, color: AppColors.greyBg,
                              child: Icon(Icons.image, color: AppColors.textSecondary))),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: InkWell(
                        onTap: () => setState(() => otherPaths.removeAt(e.key)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
          if (existingImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerRight,
                child: Text('الصور الحالية', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: existingImages.map((im) {
                final gone = deleteImageIds.contains(im['id']);
                final url = AppConfig.fileUrl(app.apiUrl, im['image']);
                return Opacity(
                  opacity: gone ? 0.35 : 1,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(url,
                            width: 72, height: 72, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                width: 72, height: 72, color: AppColors.greyBg,
                                child: Icon(Icons.image, color: AppColors.textSecondary))),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: InkWell(
                          onTap: () => setState(() {
                            if (gone) {
                              deleteImageIds.remove(im['id']);
                            } else if (im['id'] != null) {
                              deleteImageIds.add(im['id']);
                            }
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                                color: gone ? Colors.green : Colors.red, shape: BoxShape.circle),
                            child: Icon(gone ? Icons.undo : Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await confirmWrite(context)) return;
                    if (name.text.trim().isEmpty) {
                      toast(context, 'أدخل اسم المنتج');
                      return;
                    }
                    if (categoryId == null || categoryId!.isEmpty) {
                      toast(context, 'اختر التصنيف');
                      return;
                    }
                    final priced = variants.where((v) => v.price.text.trim().isNotEmpty).toList();
                    if (priced.isEmpty) {
                      toast(context, 'أدخل سعر خيار واحد على الأقل');
                      return;
                    }
                    if (widget.id == null && imagePath == null) {
                      toast(context, 'صورة المنتج مطلوبة');
                      return;
                    }
                    setState(() => busy = true);
                    final map = <String, dynamic>{
                      'name': name.text.trim(),
                      'slug': slugify(name.text),
                      'description': description.text.isEmpty ? name.text.trim() : description.text,
                      'seller_id': app.sellerId,
                      'category_id': categoryId,
                      'seller_section_id': sectionId ?? '',
                      'tax_id': (taxId == null || taxId!.isEmpty) ? 0 : taxId,
                      'brand_id': (brandId == null || brandId!.isEmpty) ? 0 : brandId,
                      'tag_ids': tagIds.join(','),
                      'type': 'packet',
                      'is_unlimited_stock': unlimited ? 1 : 0,
                      'tax_included_in_price': taxIncluded ? 1 : 0,
                      'return_status': returnable ? 1 : 0,
                      'return_days': returnable ? returnDays.text : 0,
                      'cancelable_status': 0,
                      'till_status': '',
                      'cod_allowed_status': 1,
                      'can_deliver': 1,
                      'product_type': 0,
                      'manufacturer': manufacturer.text,
                      'made_in': madeIn.text,
                      'seller_delivery_enabled': sellerDelivery ? 1 : 0,
                      'delivery_by': sellerDelivery ? 'seller' : 'platform',
                      'seller_delivery_charge': sellerDelivery ? deliveryCharge.text : '',
                      'min_order_qty': 1,
                      'is_approved': app.requireProductsApproval ? 0 : 1,
                      'status': active ? 1 : 0,
                      'fssai_lic_no': '',
                      'variant_id[]': priced.map((v) => v.id ?? '').toList(),
                      'packet_measurement[]':
                          priced.map((v) => v.measurement.text.isEmpty ? '1' : v.measurement.text).toList(),
                      'packet_price[]': priced.map((v) => v.price.text).toList(),
                      'discounted_price[]':
                          priced.map((v) => v.discounted.text.isEmpty ? '0' : v.discounted.text).toList(),
                      'packet_stock[]':
                          priced.map((v) => unlimited ? '0' : (v.stock.text.isEmpty ? '0' : v.stock.text)).toList(),
                      'packet_stock_unit_id[]': priced
                          .map((v) => (v.unitId == null || v.unitId!.isEmpty)
                              ? (units.isNotEmpty ? '${units.first['id']}' : '1')
                              : v.unitId)
                          .toList(),
                      'packet_status[]': priced.map((v) => v.active ? '1' : '0').toList(),
                      if (widget.id != null) 'id': widget.id,
                    };
                    if (deleteImageIds.isNotEmpty) {
                      map['deleteImageIds'] = '[${deleteImageIds.join(',')}]';
                    }
                    if (imagePath != null) {
                      map['image'] = await MultipartFile.fromFile(imagePath!, filename: 'product.jpg');
                    }
                    for (var i = 0; i < otherPaths.length; i++) {
                      map['other_images[$i]'] =
                          await MultipartFile.fromFile(otherPaths[i], filename: 'other_$i.jpg');
                    }
                    final data = FormData.fromMap(map);
                    final result = widget.id == null ? await app.api.saveProductForm(data) : await app.api.updateProductForm(data);
                    if (!mounted) return;
                    setState(() => busy = false);
                    if (!context.mounted) return;
                    toast(context, result.ok ? 'تم الحفظ' : result.message);
                    if (result.ok) context.pop();
                  },
            child: busy ? const BusySpinner() : const Text('حفظ'),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      )),
    );
  }
}

class WithdrawalsScreen extends StatefulWidget {
  const WithdrawalsScreen({super.key});

  @override
  State<WithdrawalsScreen> createState() => _WithdrawalsScreenState();
}

class _WithdrawalsScreenState extends State<WithdrawalsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  String balance = '—';
  String rawBalance = '—';
  String pending = '0';
  // Web parity: filter pending/approved/rejected (views/Sellers/WithdrawalRequests)
  String filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await app.api.getWithdrawals();
    if (!mounted) return;
    setState(() {
      final list = result.list('withdraw_requests');
      items = list.isNotEmpty ? list : result.dataMaps;
      final d = result.dataMap;
      balance = J.str(d['balance'], balance);
      rawBalance = J.str(d['raw_balance'] ?? d['balance'], rawBalance);
      pending = J.str(d['pending'], pending);
      loading = false;
      error = result.ok ? null : result.failMessage;
    });
  }

  String _img(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    return AppConfig.fileUrl(app.apiUrl, s);
  }

  void _preview(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('صورة الإيصال'),
        content: SizedBox(
          width: double.maxFinite,
          child: Image.network(url, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('تعذر تحميل الصورة')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final amount = TextEditingController();
    final message = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب سحب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
            TextField(controller: message, decoration: const InputDecoration(labelText: 'ملاحظة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
        ],
      ),
    );
    final value = double.tryParse(amount.text.trim()) ?? 0;
    final note = message.text;
    amount.dispose();
    message.dispose();
    if (ok != true) return;
    if (value <= 0) {
      if (mounted) toast(context, 'أدخل مبلغاً أكبر من صفر');
      return;
    }
    final result = await app.api.addWithdrawal(amount: value.toString(), message: note);
    if (!mounted) return;
    toast(context, result.ok ? 'تم إرسال الطلب' : result.message);
    if (result.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final shown = filter.isEmpty ? items : items.where((e) => J.str(e['status']) == filter).toList();
    Widget stat(String label, String value, Color color, IconData icon) {
      return Expanded(
        child: BrandedCard(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('طلبات السحب')),
      floatingActionButton: app.canWrite
          ? FloatingActionButton(onPressed: _add, child: const Icon(Icons.add))
          : null,
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: shown.isEmpty,
        emptyText: 'لا توجد طلبات سحب',
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(children: [
              stat('الرصيد المتاح', balance, AppColors.success, Icons.account_balance_wallet_outlined),
              const SizedBox(width: 8),
              stat('قيد الانتظار', pending, AppColors.orange, Icons.hourglass_empty),
              const SizedBox(width: 8),
              stat('إجمالي الرصيد', rawBalance, AppColors.navy, Icons.account_balance),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('', 'الكل'),
                  const SizedBox(width: 6),
                  _chip('0', 'قيد الانتظار'),
                  const SizedBox(width: 6),
                  _chip('1', 'معتمدة'),
                  const SizedBox(width: 6),
                  _chip('2', 'مرفوضة'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...shown.map((item) {
              final st = J.str(item['status']);
              final stLabel = st == '1' ? 'معتمد' : st == '2' ? 'مرفوض' : 'قيد الانتظار';
              final stColor = st == '1' ? AppColors.success : st == '2' ? AppColors.error : AppColors.orange;
              final receipt = _img(J.str(item['receipt_image_url'].toString().isNotEmpty
                  ? item['receipt_image_url']
                  : item['receipt_image']));
              return BrandedCard(
                child: Row(children: [
                  if (receipt.isNotEmpty)
                    InkWell(
                      onTap: () => _preview(receipt),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(receipt, width: 56, height: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                width: 56, height: 56, color: AppColors.greyBg,
                                child: Icon(Icons.receipt_outlined, color: AppColors.textSecondary))),
                      ),
                    )
                  else
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: AppColors.greyBg, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.receipt_outlined, color: AppColors.textSecondary),
                    ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(J.str(item['amount']), style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(J.str(item['message']).isEmpty ? J.str(item['created_at']) : J.str(item['message']),
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(stLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stColor)),
                  ])),
                  if (app.canWrite) PopupMenuButton<String>(onSelected: (v) async {
                    if (v == 'delete') {
                      final ok = await confirmAction(context, title: 'حذف الطلب', body: 'حذف طلب السحب؟', confirmLabel: 'حذف');
                      if (!ok || !context.mounted) return;
                      final r = await app.api.deleteWithdrawal(item['id']);
                      if (!context.mounted) return; toast(context, r.ok ? 'تم الحذف' : r.message); if (r.ok) _load();
                    }
                  }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف'))]),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => filter = value),
    );
  }
}

class SimpleApiList extends StatefulWidget {
  const SimpleApiList({super.key, required this.title, required this.loader});
  final String title;
  final Future<ApiResult> Function() loader;

  @override
  State<SimpleApiList> createState() => _SimpleApiListState();
}

class _SimpleApiListState extends State<SimpleApiList> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: items.isEmpty,
        child: ListView(
          children: items
              .map((item) => ListTile(
                    title: Text(J.str(item['name'] ?? item['promo_code'] ?? item['title'] ?? item['id'])),
                    subtitle: Text(J.str(item['message'] ?? item['status'] ?? item['created_at'])),
                    trailing: Text(J.str(item['amount'] ?? item['total'] ?? '')),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

/// حالة إشعارات الجهاز الفورية (FCM) — تصل حتى والتطبيق مغلق.
/// الضغط عليها يعيد طلب الإذن إن كان معطلاً من الجهاز.
class _PushStatusTile extends StatefulWidget {
  const _PushStatusTile();

  @override
  State<_PushStatusTile> createState() => _PushStatusTileState();
}

class _PushStatusTileState extends State<_PushStatusTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ok = PushService.supported && PushService.permissionGranted;
    return BrandedCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: _busy
          ? () {}
          : () async {
              setState(() => _busy = true);
              final granted = await PushService.requestPermission();
              if (!mounted) return;
              setState(() => _busy = false);
              toast(
                context,
                granted
                    ? 'تم تفعيل الإشعارات الفورية'
                    : 'تعذّر التفعيل — تحقق من إعدادات الجهاز وFirebase',
              );
            },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
              ok
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: AppColors.navy,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إشعارات الجهاز الفورية',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  _busy ? 'جاري الطلب...' : PushService.statusText,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  Widget _sectionTile(BuildContext context, {required IconData icon, required String title, required String path, String? subtitle}) {
    return BrandedCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: () => context.push(path),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_left, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: RefreshIndicator(
        onRefresh: app.refreshSession,
        color: AppColors.orange,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.orange.withValues(alpha: 0.2),
                    child: Icon(Icons.storefront, color: AppColors.orange, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.storeName, style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(J.str(app.user?['email'] ?? app.seller['mobile']), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/profile'),
                    icon: Icon(Icons.edit_outlined, color: AppColors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader('إعدادات المتجر'),
            _sectionTile(context, icon: Icons.settings_outlined, title: 'الإعدادات', subtitle: 'ساعات العمل وكلمة المرور', path: '/settings'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.badge_outlined, title: 'ملف المتجر', path: '/profile'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.category_outlined, title: 'تصنيفاتي', path: '/categories'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.layers_outlined, title: 'أقسام المتجر', subtitle: 'أوقات العمل والترتيب', path: '/sections'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.straighten, title: 'الوحدات', path: '/units'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.percent, title: 'الضرائب', path: '/taxes'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.sell_outlined, title: 'الماركات', path: '/brands'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.photo_library_outlined, title: 'الميديا', path: '/media'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.star_outline, title: 'تقييمات المنتجات', path: '/ratings'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.upload_file, title: 'رفع منتجات جماعي', path: '/bulk'),
            const SizedBox(height: 20),
            const SectionHeader('المالية'),
            _sectionTile(context, icon: Icons.account_balance, title: 'المحاسبة', path: '/accounting'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.account_balance_wallet_outlined, title: 'المحفظة', path: '/wallet'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.payments_outlined, title: 'طلبات السحب', path: '/withdrawals'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.bar_chart, title: 'التقارير', path: '/reports'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.assignment_return, title: 'طلبات الإرجاع', path: '/returns'),
            const SizedBox(height: 20),
            const SectionHeader('العروض'),
            _sectionTile(context, icon: Icons.local_offer_outlined, title: 'أكواد الخصم', path: '/promos'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.flash_on_outlined, title: 'عروض فلاش', path: '/flash'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.card_giftcard, title: 'اشترِ واحصل', path: '/bxgy'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.discount_outlined, title: 'خصم التصنيف', path: '/category-discounts'),
            if (app.campaignsEnabled) ...[
              const SizedBox(height: 8),
              _sectionTile(context, icon: Icons.campaign_outlined, title: 'الحملات', path: '/campaigns'),
            ],
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.storefront_outlined, title: 'واجهة المتجر', path: '/storefront'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.shopping_bag_outlined, title: 'طلبات التجارة الجديدة', path: '/seller-orders'),
            const SizedBox(height: 20),
            const SectionHeader('الدعم'),
            _sectionTile(context, icon: Icons.notifications_outlined, title: 'إشعارات الطلبات', path: '/mail'),
            const SizedBox(height: 8),
            const _PushStatusTile(),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.privacy_tip_outlined, title: 'السياسات', path: '/privacy'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.description_outlined, title: 'الشروط والأحكام', path: '/terms'),
            if (app.supportPhone.isNotEmpty) ...[
              const SizedBox(height: 8),
              BrandedCard(
                onTap: () => openTel(app.supportPhone),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.call_outlined, color: AppColors.navy, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('اتصال بالدعم', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(app.supportPhone, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_left, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            BrandedCard(
              onTap: () async {
                final ok = await confirmAction(context, title: 'تسجيل الخروج', body: 'هل تريد تسجيل الخروج؟');
                if (!ok || !context.mounted) return;
                await app.logout();
                if (context.mounted) context.go('/login');
              },
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppColors.error),
                  SizedBox(width: 12),
                  Text('خروج', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            BrandedCard(
              onTap: () async {
                // الباكند يشترط POST + كلمة المرور + confirmation=DELETE.
                final passwordCtrl = TextEditingController();
                var busy = false;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setDlg) => AlertDialog(
                      title: const Text('حذف الحساب'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                              'سيتم حذف المتجر نهائياً ولا يمكن التراجع. أدخل كلمة المرور للتأكيد.'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.pop(ctx, false),
                          child: const Text('تراجع'),
                        ),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (passwordCtrl.text.isEmpty) {
                                    toast(context, 'أدخل كلمة المرور');
                                    return;
                                  }
                                  setDlg(() => busy = true);
                                  final result =
                                      await app.api.deleteAccount(
                                          password: passwordCtrl.text);
                                  if (!ctx.mounted) return;
                                  setDlg(() => busy = false);
                                  if (!result.ok) {
                                    toast(context, result.message);
                                    return;
                                  }
                                  Navigator.pop(ctx, true);
                                },
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text('حذف نهائي'),
                        ),
                      ],
                    ),
                  ),
                );
                passwordCtrl.dispose();
                if (!context.mounted) return;
                if (ok == true) {
                  toast(context, 'تم حذف الحساب');
                  await app.logout();
                  if (context.mounted) context.go('/login');
                }
              },
              child: Row(
                children: [
                  Icon(Icons.delete_forever_outlined, color: AppColors.error),
                  SizedBox(width: 12),
                  Text('حذف الحساب', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}