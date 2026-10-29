import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../core/app_controller.dart';
import '../core/config.dart';
import '../core/formatters.dart';
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
      var n = J.str(d['next_opening_at']);
      if (n.length > 5 && n.contains(':')) n = n.substring(0, 5);
      final date = Fmt.date(d['next_opening_date']);
      storeHoursNote = n.isEmpty
          ? ''
          : '$n${date.isNotEmpty ? ' ($date)' : ''}';
    });
  }

  String _dashValue(
    Map<String, dynamic> d,
    List<String> keys, [
    String fallback = '0',
  ]) {
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
                    Icon(
                      Icons.block,
                      size: 48,
                      color: AppColors.error.withValues(alpha: 0.8),
                    ),
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
        final completedOrders = (totalOrders - pendingOrders).clamp(
          0,
          totalOrders,
        );
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
        final totalSales = Fmt.money(
          _dashValue(
            d,
            ['total_sales', 'sales', 'gross_sales'],
            weeklyTotal.isNotEmpty
                ? weeklyTotal
                : _dashValue(d, ['balance'], '0'),
          ),
        );
        final balance = Fmt.money(_dashValue(d, ['balance'], '0'));
        final lowStock = _dashValue(d, ['low_stock_count'], '0');
        final soldOut = _dashValue(d, ['sold_out_count'], '0');
        final productCount = _dashValue(d, ['product_count'], '0');
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
                      TextButton(
                        onPressed: app.refreshDashboard,
                        child: Text(
                          'إعادة',
                          style: TextStyle(color: AppColors.orange),
                        ),
                      ),
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
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_top,
                        color: AppColors.orange,
                        size: 20,
                      ),
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
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
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
                ),
              LayoutBuilder(
                builder: (ctx, c) {
                  final cols = c.maxWidth > 900
                      ? 4
                      : c.maxWidth > 600
                      ? 3
                      : 2;
                  final aspect = c.maxWidth > 600 ? 1.3 : 1.0;
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
                        subtitle:
                            'عدد المقيمين: ${_dashValue(d, ['rating_count'], '0')}',
                        iconColor: AppColors.orange,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const SectionHeader('إجراءات سريعة'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    QuickActionButton(
                      icon: Icons.add_shopping_cart,
                      label: 'إضافة منتج',
                      onTap: app.canWrite
                          ? () => context.push('/products/create')
                          : () => toast(
                              context,
                              'لا يمكن التعديل قبل موافقة الإدارة',
                            ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  storeHoursNote.isEmpty
                                      ? 'الإعدادات'
                                      : storeHoursNote,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
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
              LayoutBuilder(
                builder: (ctx, c) {
                  final cols = c.maxWidth > 900
                      ? 4
                      : c.maxWidth > 600
                      ? 3
                      : 2;
                  final aspect = c.maxWidth > 600 ? 1.2 : 1.05;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: aspect,
                    children: [
                      DashboardShortcutCard(
                        icon: Icons.receipt_long,
                        title: 'الطلبات',
                        value: '$totalOrders',
                        path: '/orders',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.inventory_2,
                        title: 'المنتجات',
                        value: productCount,
                        path: '/products',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.warning_amber,
                        title: 'نفد المخزون',
                        value: soldOut,
                        path: '/stock/sold_out',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.account_balance,
                        title: 'المحاسبة',
                        path: '/accounting',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.account_balance_wallet,
                        title: 'المحفظة',
                        value: balance,
                        path: '/wallet',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.payments_outlined,
                        title: 'السحب',
                        path: '/withdrawals',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.bar_chart,
                        title: 'التقارير',
                        path: '/reports',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.local_offer,
                        title: 'أكواد الخصم',
                        path: '/promos',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.flash_on,
                        title: 'عروض فلاش',
                        path: '/flash',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.card_giftcard,
                        title: 'اشترِ واحصل',
                        path: '/bxgy',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.discount,
                        title: 'خصم تصنيف',
                        path: '/category-discounts',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.local_shipping_outlined,
                        title: 'توصيل مجاني',
                        path: '/delivery-offers',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.layers_outlined,
                        title: 'أقسام المتجر',
                        path: '/sections',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.shopping_bag_outlined,
                        title: 'طلبات التجارة',
                        value: '$pendingOrders',
                        path: '/seller-orders',
                      ),
                      DashboardShortcutCard(
                        icon: Icons.table_chart_outlined,
                        title: 'تصدير المحاسبة',
                        path: '/accounting',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              if (weekly.isNotEmpty) ...[
                const SectionHeader('مبيعات آخر 7 أيام'),
                BrandedCard(
                  child: Column(
                    children: weekly
                        .take(7)
                        .map(
                          (w) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  Fmt.date(w['order_date']),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  Fmt.money(w['total_sale']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (statusCounts.isNotEmpty) ...[
                const SectionHeader('الطلبات حسب الحالة'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: statusCounts
                      .map(
                        (s) => Chip(
                          label: Text(
                            '${Fmt.status(s['status'])}: ${J.str(s['order_count'], '0')}',
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],
              if (catCounts.isNotEmpty) ...[
                const SectionHeader('منتجات حسب التصنيف'),
                BrandedCard(
                  child: Column(
                    children: catCounts
                        .take(8)
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    J.str(c['name']),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  J.str(c['product_count'], '0'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
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
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
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
    return s.contains('جديد') ||
        s.contains('new') ||
        s.contains('pending') ||
        s.contains('انتظار');
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_newCount جديد',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                      ...statuses.map(
                        (s) => DropdownMenuItem(
                          value: J.i(s['id']),
                          child: Text(J.str(s['status'] ?? s['name'])),
                        ),
                      ),
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
                  icon: Icon(
                    Icons.date_range,
                    color: (startDate.isNotEmpty) ? AppColors.orange : null,
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
    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = c.maxWidth > 900
            ? 4
            : c.maxWidth > 600
            ? 3
            : 2;
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
      },
    );
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
                child: Icon(
                  Icons.receipt_long,
                  color: AppColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$id',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      J.str(order['user_name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
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
    final results = await Future.wait([
      app.api.orderById(widget.id),
      app.api.orderStatuses(),
      app.api.deliveryBoys(),
    ]);
    if (!mounted) return;
    final result = results[0];
    setState(() {
      order = result.dataMaps.isNotEmpty
          ? result.dataMaps.first
          : result.dataMap;
      statuses = results[1].dataMaps;
      boys = results[2].dataMaps;
      loading = false;
      error = result.ok || (order != null && order!.isNotEmpty)
          ? null
          : result.failMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(body: BrandedSkeletonList(brand: app.brand));
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
    final currentStatus = J.str(
      order?['order_status'] ?? order?['active_status'],
    );
    final address = J.str(order?['address']);
    final mobile = J.str(order?['mobile']);
    final customerLine = address.isNotEmpty
        ? address
        : (mobile.isNotEmpty ? mobile : 'لا يوجد عنوان مسجل');
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
                  Text(
                    J.str(order?['user_name']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Text(
                    'العميل محجوب حسب إعدادات الخصوصية',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 4),
                if (app.canViewCustomerDetail)
                  Text(
                    customerLine,
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  Text(
                    'العنوان محجوب',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                if (app.canViewCustomerDetail &&
                    J.str(order?['mobile']).isNotEmpty) ...[
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
                        onPressed: () =>
                            copyText(context, J.str(order?['mobile'])),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('نسخ'),
                      ),
                    ],
                  ),
                ],
                if (!app.canViewCustomerDetail)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'بيانات العميل مخفية حسب إعدادات الخصوصية.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (J.str(order?['otp'] ?? order?['order_otp']).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (app.canViewOrderOtp)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'OTP: ${J.str(order?['otp'] ?? order?['order_otp'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Text(
                      'رمز OTP محجوب حسب الصلاحيات',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('تحديث الحالة'),
          if (!app.canChangeOrderStatusDelivered)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'تنبيه: تغيير الحالة إلى "تم التوصيل" يتطلب صلاحية خاصة من الإدارة',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((s) {
              final name = J.str(s['status'] ?? s['name']);
              final sl = name.toLowerCase();
              final isDelivered =
                  sl.contains('deliver') ||
                  sl.contains('تم التوصيل') ||
                  sl.contains('delivered');
              final blockedDelivered =
                  isDelivered && !app.canChangeOrderStatusDelivered;
              final isActive =
                  currentStatus.toLowerCase() == name.toLowerCase();
              return StageActionButton(
                label: Fmt.status(name),
                icon: _statusIcon(name),
                active: isActive,
                enabled: app.canWrite && !blockedDelivered,
                onTap: app.canWrite && !blockedDelivered
                    ? () async {
                        final ok = await confirmAction(
                          context,
                          title: 'تحديث الحالة',
                          body: 'تغيير حالة الطلب إلى ${Fmt.status(name)}؟',
                        );
                        if (!ok || !context.mounted) return;
                        final result = await app.api.updateStatus(
                          orderId: widget.id,
                          statusId: s['id'],
                        );
                        if (!context.mounted) return;
                        toast(
                          context,
                          result.ok ? 'تم التحديث' : result.message,
                        );
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
              child: Text(
                'لا توجد أصناف في هذا الطلب',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...items.map(
              (item) => BrandedCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        J.str(item['product_name'] ?? item['name']),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.greyBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'x${item['quantity']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          BrandedCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الإجمالي',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  Fmt.money(order?['final_total']),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orangeText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BrandedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فاتورة الطلب',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                _invoiceRow(
                  'التاريخ',
                  Fmt.date(order?['created_at'], withTime: true),
                ),
                _invoiceRow(
                  'العميل',
                  app.canViewCustomerDetail
                      ? J.str(order?['user_name'])
                      : '— محجوب —',
                ),
                _invoiceRow(
                  'الجوال',
                  app.canViewCustomerDetail
                      ? J.str(order?['mobile'])
                      : '— محجوب —',
                ),
                _invoiceRow(
                  'العنوان',
                  app.canViewCustomerDetail
                      ? J.str(order?['address'])
                      : '— محجوب —',
                ),
                if (app.canViewCustomerDetail &&
                    app.canViewOrderOtp &&
                    J.str(order?['otp'] ?? order?['order_otp']).isNotEmpty)
                  _invoiceRow(
                    'OTP',
                    J.str(order?['otp'] ?? order?['order_otp']),
                  ),
                _invoiceRow(
                  'الدفع',
                  '${Fmt.paymentMethod(order?['payment_method'])} (${Fmt.payment(order?['payment_status'])})',
                ),
                _invoiceRow('المجموع', Fmt.money(order?['total'])),
                _invoiceRow(
                  'النهائي',
                  Fmt.money(order?['final_total']),
                  bold: true,
                ),
                if (app.isHomeSeller) _invoiceRow('نوع المتجر', 'منتج منزلي'),
                if (app.requireProductsApproval)
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'ملاحظة: منتجاتك تتطلب موافقة الإدارة قبل الظهور',
                      style: TextStyle(fontSize: 12, color: AppColors.orange),
                    ),
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
              ...boys
                  .take(5)
                  .map(
                    (b) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline),
                      title: Text(J.str(b['name'])),
                      subtitle: Text(J.str(b['mobile'] ?? '')),
                    ),
                  ),
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
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('جديد') || s.contains('new') || s.contains('received'))
      return Icons.inbox;
    if (s.contains('تحضير') || s.contains('prepar')) return Icons.restaurant;
    if (s.contains('جاهز') || s.contains('pickup') || s.contains('ready'))
      return Icons.check_circle_outline;
    if (s.contains('dispatch') || s.contains('deliver'))
      return Icons.local_shipping_outlined;
    return Icons.sync;
  }
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const _pageSize = 30;

  List<Map<String, dynamic>> items = [];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = false;
  String? error;
  final searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      if (loadingMore || !hasMore) return;
      setState(() => loadingMore = true);
    } else if (mounted) {
      setState(() => loading = true);
    }
    final result = await app.api.products(
      limit: _pageSize,
      offset: more ? items.length : 0,
      search: searchCtrl.text.trim(),
      sellerId: app.sellerId,
    );
    if (!mounted) return;
    setState(() {
      final page = result.dataMaps;
      items = more ? [...items, ...page] : page;
      hasMore = page.length >= _pageSize;
      loading = false;
      loadingMore = false;
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
                if (!mounted) return;
                toast(
                  context,
                  r.ok ? 'النشطة: ${r.dataMaps.length}' : r.message,
                );
                if (r.ok)
                  setState(() {
                    items = r.dataMaps;
                  });
              } else if (v == 'offers') {
                final r = await app.api.productsOffers();
                if (!mounted) return;
                toast(
                  context,
                  r.ok ? 'العروض: ${r.dataMaps.length}' : r.message,
                );
              } else if (v == 'sold_out' || v == 'low_stock') {
                await context.push('/stock/$v');
                if (mounted) _load();
              } else if (v == 'delete_bulk') {
                if (!await confirmWrite(context)) return;
                final ok = await confirmAction(
                  context,
                  title: 'حذف جماعي',
                  body: 'حذف كل المنتجات الظاهرة (${items.length})؟',
                  confirmLabel: 'حذف',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                final ids = items.map((e) => e['id']).toList();
                final r = await app.api.deleteProductsBulk(ids);
                if (!context.mounted) return;
                toast(context, r.ok ? 'تم الحذف الجماعي' : r.message);
                if (r.ok) _load();
              } else if (v == 'tags') {
                final r = await app.api.productTags('a');
                if (!mounted) return;
                toast(
                  context,
                  r.ok ? 'الوسوم: ${r.dataMaps.length}' : r.message,
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'active', child: Text('المنتجات النشطة')),
              PopupMenuItem(value: 'offers', child: Text('منتجات العروض')),
              PopupMenuItem(value: 'tags', child: Text('الوسوم')),
              PopupMenuItem(value: 'sold_out', child: Text('منتجات نافدة')),
              PopupMenuItem(
                value: 'low_stock',
                child: Text('منتجات منخفضة المخزون'),
              ),
              PopupMenuItem(value: 'delete_bulk', child: Text('حذف جماعي')),
            ],
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'بحث باسم المنتج',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchCtrl.clear();
                          _load();
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: FetchBody(
              loading: loading,
              onRefresh: () => _load(),
              error: error,
              isEmpty: items.isEmpty,
              emptyText: searchCtrl.text.trim().isEmpty
                  ? 'لا توجد منتجات بعد'
                  : 'لا توجد منتجات مطابقة للبحث',
              emptyActionLabel: app.canWrite && searchCtrl.text.trim().isEmpty
                  ? 'إضافة منتج'
                  : null,
              onEmptyAction: app.canWrite && searchCtrl.text.trim().isEmpty
                  ? () async {
                      await context.push('/products/create');
                      if (mounted) _load();
                    }
                  : null,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i >= items.length) {
                    return Center(
                      child: loadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            )
                          : OutlinedButton(
                              onPressed: () => _load(more: true),
                              child: const Text('عرض المزيد'),
                            ),
                    );
                  }
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
                        NetImage(
                          AppConfig.fileUrl(app.apiUrl, p['image']),
                          width: 52,
                          height: 52,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                J.str(p['name']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                Fmt.money(
                                  p['unit_price'] ??
                                      p['price'] ??
                                      p['final_price'],
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: visible
                                          ? AppColors.success.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppColors.greyBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      visible ? 'ظاهر' : 'مخفي',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: visible
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'مخزون ${stock ?? '—'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: lowStock
                                          ? AppColors.orange
                                          : AppColors.textSecondary,
                                      fontWeight: lowStock
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
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
                                  await context.push(
                                    '/products/edit/${p['id']}',
                                  );
                                  if (context.mounted) _load();
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () async {
                                  final ok = await confirmAction(
                                    context,
                                    title: 'حذف المنتج',
                                    body: 'سيتم حذف المنتج. هل أنت متأكد؟',
                                    confirmLabel: 'حذف',
                                    destructive: true,
                                  );
                                  if (!ok || !context.mounted) return;
                                  final result = await app.api.deleteProduct(
                                    p['id'],
                                  );
                                  if (!context.mounted) return;
                                  toast(
                                    context,
                                    result.ok ? 'تم الحذف' : result.message,
                                  );
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
          ),
        ],
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
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child:
                trailing ??
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
          ),
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
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  static String plain(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

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
              SizedBox(
                width: double.infinity,
                child: NetImage(
                  img,
                  height: 200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            const SizedBox(height: 12),
            BrandedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    J.str(record['name']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'السعر',
                    Fmt.money(record['unit_price'] ?? record['price']),
                  ),
                  _row('المخزون', J.str(record['stock'], '—')),
                  _row('رمز المنتج', J.str(record['sku'])),
                  _row('البائع', J.str(J.map(record['seller'])['name'])),
                  _row('المعرف', J.str(record['id'])),
                  _row(
                    'الحالة',
                    '',
                    trailing: _badge(
                      J.i(record['status']) == 1 ? 'نشط' : 'مخفي',
                      J.i(record['status']) == 1,
                    ),
                  ),
                  _row(
                    'الموافقة',
                    '',
                    trailing: _badge(
                      J.i(record['is_approved']) == 1 ? 'معتمد' : 'غير معتمد',
                      J.i(record['is_approved']) == 1,
                    ),
                  ),
                  _row(
                    'الإرجاع',
                    J.i(record['return_status']) == 1 ? 'مسموح' : 'غير مسموح',
                  ),
                  _row(
                    'الإلغاء',
                    J.i(record['cancelable_status']) == 1
                        ? 'مسموح'
                        : 'غير مسموح',
                  ),
                  _row('التصنيف', J.str(J.map(record['category'])['name'])),
                  _row(
                    'الضريبة',
                    J.map(record['tax']).isEmpty
                        ? '—'
                        : '${J.str(J.map(record['tax'])['title'])} ${J.str(J.map(record['tax'])['percentage'])}%',
                  ),
                  _row(
                    'بلد الصنع',
                    J.str(J.map(record['made_in_country'])['name']),
                  ),
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
                  itemBuilder: (_, i) => NetImage(
                    AppConfig.fileUrl(app.apiUrl, others[i]['image']),
                    width: 90,
                    height: 90,
                    borderRadius: BorderRadius.circular(8),
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
                    Text(
                      '${J.str(record['name'])} ${J.str(v['measurement'])} $uname'
                          .trim(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'المخزون: ${J.str(v['stock'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'السعر: ${J.str(v['price'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'المخفض: ${J.str(v['discounted_price'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
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
    final title = widget.type == 'sold_out'
        ? 'منتجات نافدة'
        : 'منتجات منخفضة المخزون';
    final q = query.trim();
    final shown = q.isEmpty
        ? items
        : items
              .where(
                (p) =>
                    J.str(p['name']).contains(q) ||
                    J.str(p['product_variant_id']).contains(q),
              )
              .toList();
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
                  labelText: 'بحث',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
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
                        NetImage(
                          AppConfig.fileUrl(app.apiUrl, img),
                          width: 56,
                          height: 56,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                J.str(p['name']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'السعر: ${Fmt.money(p['price'])} • المخزون: ${J.str(p['stock'], '0')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'إجراءات المنتج',
                          onSelected: (action) async {
                            final productId = p['product_id'] ?? p['id'];
                            if (action == 'view') {
                              context.push('/products/view/$productId');
                            } else if (action == 'edit') {
                              context.push('/products/edit/$productId');
                            } else if (action == 'toggle') {
                              if (!await confirmWrite(context)) return;
                              final r = await app.api.changeProductStatus(
                                productId,
                              );
                              if (!context.mounted) return;
                              toast(context, r.ok ? 'تم التحديث' : r.message);
                              if (r.ok) _load();
                            } else if (action == 'delete') {
                              final ok = await confirmAction(
                                context,
                                title: 'حذف المنتج',
                                body: 'سيتم حذف المنتج نهائياً. هل أنت متأكد؟',
                                confirmLabel: 'حذف',
                                destructive: true,
                              );
                              if (!ok || !context.mounted) return;
                              final r = await app.api.deleteProduct(productId);
                              if (!context.mounted) return;
                              toast(context, r.ok ? 'تم الحذف' : r.message);
                              if (r.ok) _load();
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Text('عرض التفاصيل'),
                            ),
                            if (app.canWrite) ...[
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('تعديل المخزون'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  active ? 'إخفاء المنتج' : 'إظهار المنتج',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف المنتج'),
                              ),
                            ],
                          ],
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

class _OptData<T> {
  const _OptData({
    required this.value,
    required this.icon,
    required this.title,
    this.iconBg = const Color(0xFFFFF1E6),
    this.iconFg = const Color(0xFFE05E00),
  });
  final T value;
  final IconData icon;
  final String title;
  final Color iconBg;
  final Color iconFg;
}

// ── لغة تصميم صفحة البائع في saree_back (EditProduct.vue) ──
// بطاقة خيار مضغوطة (مطابق .compact-seg .option-card): عمودية، أيقونة + عنوان فقط.
class _OptCard extends StatelessWidget {
  const _OptCard({
    required this.active,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconBg = const Color(0xFFFFF1E6),
    this.iconFg = const Color(0xFFE05E00),
  });
  final bool active;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconBg;
  final Color iconFg;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.orange : AppColors.border,
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.14),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: iconFg),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// صندوق متقطع الحدود (مطابق .product-adv-shortcuts / .delivery-charge-box / .return-days-box)
class _DashedBox extends StatelessWidget {
  const _DashedBox({
    required this.child,
    this.color = AppColors.border,
    this.bg = const Color(0xFFFAFBFC),
  });
  final Widget child;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashPainter(color: color),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    double d = 0;
    while (d < metrics.length) {
      final next = (d + dash).clamp(0.0, metrics.length);
      canvas.drawPath(metrics.extractPath(d, next), paint);
      d = next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// زر اختصار (مطابق .product-adv-shortcut): أيقونة ملوّنة + عنوان ووصف + سهم
class _AdvShortcut extends StatelessWidget {
  const _AdvShortcut({
    required this.icon,
    required this.title,
    required this.desc,
    required this.active,
    required this.onTap,
    this.iconBg = const Color(0xFFFFF1E6),
    this.iconFg = const Color(0xFFE05E00),
  });
  final IconData icon;
  final String title;
  final String desc;
  final bool active;
  final VoidCallback onTap;
  final Color iconBg;
  final Color iconFg;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFFAF5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.orange : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: iconFg),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// زر تبويب اللوحة (مطابق .product-adv-tab): عمودي بأيقونة وعنوان
class _AdvTabBtn extends StatelessWidget {
  const _AdvTabBtn({
    required this.icon,
    required this.title,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppColors.orange.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? AppColors.orange : Colors.grey,
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.orange : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// عنوان قسم داخل اللوحة (مطابق .product-adv-section-title)
class _AdvSectionTitle extends StatelessWidget {
  const _AdvSectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
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

class _SimpleVariant {
  dynamic id;
  final packetMeasurement = TextEditingController();
  final packetPrice = TextEditingController();
  final discountedPrice = TextEditingController();
  final packetStock = TextEditingController();
  String? packetStockUnitId;
  final looseMeasurement = TextEditingController();
  final loosePrice = TextEditingController();
  final looseDiscounted = TextEditingController();
  String? discountError;
  String? discountErrorLoose;
  void dispose() {
    packetMeasurement.dispose();
    packetPrice.dispose();
    discountedPrice.dispose();
    packetStock.dispose();
    looseMeasurement.dispose();
    loosePrice.dispose();
    looseDiscounted.dispose();
  }
}

// ───────── إضافة/تعديل منتج — مطابق تماماً لـ resources/js/views/Product/EditProduct.vue (مسار البائع) ─────────
// النموذج المبسّط للبائع: الاسم + قسم المتجر + السعر + الخصم + المخزون + الصورة + الوصف (اختياري).
// المتقدمة في 3 تبويبات: البيع (النوع loose/packet + غير محدود/محدود + الخيارات)، التوصيل (المنصة/المتجر + الضريبة + الوسوم)، السياسات (إرجاع + مصنع + بلد).
class _ProductEditScreenState extends State<ProductEditScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final manufacturer = TextEditingController();
  final returnDays = TextEditingController(text: '0');
  final deliveryCharge = TextEditingController();
  final newTagsCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final discountCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
  final looseStockCtrl = TextEditingController();
  String? discountError;
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> taxes = [];
  List<Map<String, dynamic>> allTags = [];
  List<Map<String, dynamic>> countries = [];
  String categoryId = '';
  String? sectionId;
  String? taxId;
  String? madeInId;
  final tagIds = <int>{};
  final newTagNames = <String>[];
  String? imagePath;
  List<Map<String, dynamic>> existingImages = [];
  final deleteImageIds = <dynamic>[];
  final List<String> otherPaths = [];
  final List<_SimpleVariant> inputs = [];
  String type = 'loose';
  int isUnlimited = 1;
  String looseStock = '';
  String? looseUnitId;
  int status = 1;
  int returnStatus = 0;
  int taxIncluded = 0;
  int isApproved = 1;
  bool sellerDelivery = false;
  bool busy = false;
  bool loadingEdit = false;
  bool _dirty = false;
  bool _allowPop = false;
  String advTab = 'sale';
  bool showAdvanced = false;
  bool isHomeSeller = false;
  final prepCtrl = TextEditingController();
  final minQtyCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    // الفئة على مستوى المتجر (مطابق setStoreTypeCategory): أول فئة من seller.categories
    final cats = J.str(app.seller['categories']);
    final catList = cats
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (catList.isNotEmpty) categoryId = catList.first;
    isApproved = app.requireProductsApproval ? 0 : 1;
    isHomeSeller = J.flag(app.seller['is_home_seller']);
    for (final c in [
      name,
      description,
      manufacturer,
      returnDays,
      deliveryCharge,
      newTagsCtrl,
      priceCtrl,
      discountCtrl,
      stockCtrl,
      looseStockCtrl,
      prepCtrl,
      minQtyCtrl,
    ]) {
      c.addListener(_markDirty);
    }
    _ensureVariant();
    app.api.sellerSections().then((res) {
      if (!mounted) return;
      sections = res.dataMaps;
      if (sectionId == null && sections.length == 1)
        sectionId = '${sections.first['id']}';
      setState(() {});
    });
    app.api.units().then((res) {
      if (!mounted) return;
      units = res.dataMaps;
      _applyDefaultUnit();
      setState(() {});
    });
    app.api.taxes().then((res) {
      if (mounted) setState(() => taxes = res.dataMaps);
    });
    app.api.productTags('').then((res) {
      if (mounted) setState(() => allTags = res.dataMaps);
    });
    app.api.countries().then((res) {
      if (mounted) setState(() => countries = res.dataMaps);
    });
    if (widget.id != null) _loadProduct();
  }

  String get _defaultUnitId => units.isNotEmpty ? '${units.first['id']}' : '1';

  void _markDirty() {
    if (!mounted || _dirty) return;
    setState(() => _dirty = true);
  }

  void _trackVariant(_SimpleVariant v) {
    for (final c in [
      v.packetMeasurement,
      v.packetPrice,
      v.discountedPrice,
      v.packetStock,
      v.looseMeasurement,
      v.loosePrice,
      v.looseDiscounted,
    ]) {
      c.addListener(_markDirty);
    }
  }

  Future<void> _leaveWithoutSaving() async {
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  void _ensureVariant() {
    if (inputs.isEmpty) {
      final v = _SimpleVariant()..packetStockUnitId = _defaultUnitId;
      _trackVariant(v);
      inputs.add(v);
    }
    final row = inputs.first;
    row.packetStockUnitId ??= _defaultUnitId;
    looseUnitId ??= _defaultUnitId;
  }

  void _applyDefaultUnit() {
    if (units.isEmpty) return;
    final id = _defaultUnitId;
    _ensureVariant();
    if (inputs.first.packetStockUnitId == null ||
        inputs.first.packetStockUnitId!.isEmpty) {
      inputs.first.packetStockUnitId = id;
    }
    looseUnitId ??= id;
  }

  bool _isEmptyStock(String? v) => v == null || v.trim().isEmpty;

  // ── مطابق Vue: setSaleType / setStockMode / onSimpleStockInput / resolveStockForSave ──
  void _setSaleType(String next) {
    final prev = type;
    setState(() {
      type = next;
      _dirty = true;
    });
    if (inputs.isEmpty) return;
    final row = inputs.first;
    if (next == 'loose') {
      if (!_isEmptyStock(row.packetPrice.text))
        row.loosePrice.text = row.packetPrice.text;
      else if (!_isEmptyStock(row.loosePrice.text))
        row.packetPrice.text = row.loosePrice.text;
      if (row.discountedPrice.text.isNotEmpty) {
        row.looseDiscounted.text = row.discountedPrice.text;
      } else if (row.looseDiscounted.text.isNotEmpty) {
        row.discountedPrice.text = row.looseDiscounted.text;
      }
      if (_isEmptyStock(row.looseMeasurement.text) &&
          !_isEmptyStock(row.packetMeasurement.text)) {
        row.looseMeasurement.text = row.packetMeasurement.text;
      } else if (_isEmptyStock(row.packetMeasurement.text) &&
          !_isEmptyStock(row.looseMeasurement.text)) {
        row.packetMeasurement.text = row.looseMeasurement.text;
      }
      if (isUnlimited != 1 && !_isEmptyStock(row.packetStock.text))
        looseStock = row.packetStock.text;
      discountCtrl.text = row.discountedPrice.text;
      priceCtrl.text = row.packetPrice.text;
    } else if (next == 'packet' && prev == 'loose') {
      if (!_isEmptyStock(row.loosePrice.text))
        row.packetPrice.text = row.loosePrice.text;
      if (row.looseDiscounted.text.isNotEmpty)
        row.discountedPrice.text = row.looseDiscounted.text;
      if (_isEmptyStock(row.packetMeasurement.text) &&
          !_isEmptyStock(row.looseMeasurement.text)) {
        row.packetMeasurement.text = row.looseMeasurement.text;
      }
      if (isUnlimited != 1 && !_isEmptyStock(looseStock))
        row.packetStock.text = looseStock;
      priceCtrl.text = row.packetPrice.text;
      discountCtrl.text = row.discountedPrice.text;
    }
  }

  void _setStockMode(bool unlimitedMode) {
    setState(() {
      _dirty = true;
      if (unlimitedMode) {
        isUnlimited = 1;
        looseStock = '';
        looseStockCtrl.text = '';
        for (final r in inputs) {
          r.packetStock.text = '';
        }
        stockCtrl.text = '';
      } else {
        isUnlimited = 0;
        final existing =
            (!_isEmptyStock(looseStock) &&
                (double.tryParse(looseStock) ?? 0) > 0)
            ? looseStock
            : (!_isEmptyStock(inputs.first.packetStock.text)
                  ? inputs.first.packetStock.text
                  : '');
        if (type == 'loose') {
          looseStock = existing;
          looseStockCtrl.text = existing;
          stockCtrl.text = existing;
          inputs.first.packetStock.text = existing;
        } else if (_isEmptyStock(inputs.first.packetStock.text)) {
          inputs.first.packetStock.text = existing;
          stockCtrl.text = existing;
        }
      }
    });
  }

  void _onSimpleStockInput(String value) {
    if (_isEmptyStock(value)) {
      _setStockMode(true);
      return;
    }
    setState(() {
      isUnlimited = 0;
      stockCtrl.text = value;
      inputs.first.packetStock.text = value;
      if (type == 'loose') {
        looseStock = value;
        looseStockCtrl.text = value;
      }
    });
  }

  void _syncBaseToControllers() {
    if (inputs.isEmpty) return;
    final row = inputs.first;
    priceCtrl.text = type == 'loose' && row.loosePrice.text.isNotEmpty
        ? row.loosePrice.text
        : row.packetPrice.text;
    discountCtrl.text = type == 'loose' && row.looseDiscounted.text.isNotEmpty
        ? row.looseDiscounted.text
        : row.discountedPrice.text;
    stockCtrl.text = isUnlimited == 1
        ? ''
        : (type == 'loose' ? looseStock : row.packetStock.text);
    if (isUnlimited != 1) looseStockCtrl.text = looseStock;
  }

  void _syncControllersToBase() {
    if (inputs.isEmpty) return;
    final row = inputs.first;
    row.packetPrice.text = priceCtrl.text;
    row.discountedPrice.text = discountCtrl.text;
    row.loosePrice.text = priceCtrl.text;
    row.looseDiscounted.text = discountCtrl.text;
    if (isUnlimited == 1) {
      row.packetStock.text = '';
      looseStock = '';
    } else {
      row.packetStock.text = stockCtrl.text;
      looseStock = stockCtrl.text;
      looseStockCtrl.text = stockCtrl.text;
    }
  }

  void _validateDiscount(String discounted, String price) {
    final d = double.tryParse(discounted);
    final p = double.tryParse(price);
    if (discounted.isNotEmpty && d != null && p != null && d >= p) {
      setState(() {
        discountError = 'سعر الخصم يجب أن يكون أقل من السعر';
        if (inputs.isNotEmpty) {
          inputs.first.discountError = discountError;
        }
      });
    } else {
      setState(() {
        discountError = null;
        if (inputs.isNotEmpty) inputs.first.discountError = null;
      });
    }
  }

  String _resolvedMeasurement(TextEditingController c) {
    final v = c.text.trim();
    if (v.isEmpty || v == '0') return '1';
    return v;
  }

  Future<void> _loadProduct() async {
    setState(() => loadingEdit = true);
    ApiResult res = await app.api.productEdit(widget.id);
    if (!res.ok) res = await app.api.productById(widget.id);
    if (!mounted) return;
    setState(() => loadingEdit = false);
    if (!res.ok) {
      toast(context, res.message);
      return;
    }
    final p = res.dataMap;
    name.text = J.str(p['name']);
    description.text = J.str(p['description']);
    final cats = J.str(app.seller['categories']);
    final storeFirst =
        cats.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).isEmpty
        ? ''
        : cats.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).first;
    categoryId = J.str(p['category_id'], storeFirst);
    sectionId =
        p['seller_section_id'] == null ||
            '${p['seller_section_id']}' == '0' ||
            '${p['seller_section_id']}'.isEmpty
        ? null
        : '${p['seller_section_id']}';
    final tId = J.str(p['tax_id'], '0');
    taxId = (tId.isEmpty || tId == '0') ? null : tId;
    manufacturer.text = J.str(p['manufacturer']);
    final madeRaw = p['made_in'];
    madeInId = (madeRaw is Map)
        ? '${madeRaw['id']}'
        : (J.str(madeRaw).isEmpty || J.str(madeRaw) == '0'
              ? null
              : J.str(madeRaw));
    returnDays.text = J.str(p['return_days'], '0');
    returnStatus = J.flag(p['return_status']) ? 1 : 0;
    taxIncluded = J.i(p['tax_included_in_price'], 0);
    isUnlimited = J.flag(p['is_unlimited_stock']) ? 1 : 0;
    type = J.str(p['type'], 'loose').isEmpty
        ? 'loose'
        : J.str(p['type'], 'loose');
    if (type != 'packet' && type != 'loose') type = 'loose';
    sellerDelivery = J.str(p['delivery_by']) == 'seller';
    deliveryCharge.text = J.str(p['seller_delivery_charge']);
    isApproved = J.i(p['is_approved'], app.requireProductsApproval ? 0 : 1);
    final isHome = J.flag(p['is_home_product']);
    if (isHome) isHomeSeller = true;
    prepCtrl.text = J.str(p['preparation_time']);
    minQtyCtrl.text = J.str(p['min_order_qty'], '1');
    tagIds.clear();
    for (final t in J.maps(p['tags'])) {
      final id = J.i(t['id']);
      if (id > 0) tagIds.add(id);
    }
    existingImages = J.maps(p['images']);
    final vs = J.maps(p['variants']);
    for (final v in inputs) {
      v.dispose();
    }
    inputs.clear();
    if (vs.isEmpty) {
      _ensureVariant();
    } else if (type == 'packet') {
      for (final v in vs) {
        final e = _SimpleVariant()..id = v['id'];
        e.packetMeasurement.text = J.str(v['measurement']);
        e.packetPrice.text = J.str(v['price']);
        e.discountedPrice.text = J.str(v['discounted_price']);
        e.packetStock.text = isUnlimited == 1 ? '' : J.str(v['stock']);
        e.packetStockUnitId = J.str(v['stock_unit_id'] ?? v['stock_unit_id']);
        if (e.packetStockUnitId!.isEmpty) e.packetStockUnitId = _defaultUnitId;
        _trackVariant(e);
        inputs.add(e);
      }
    } else {
      for (var i = 0; i < vs.length; i++) {
        final v = vs[i];
        final e = _SimpleVariant()..id = v['id'];
        e.looseMeasurement.text = J.str(v['measurement']);
        e.loosePrice.text = J.str(v['price']);
        e.looseDiscounted.text = J.str(v['discounted_price']);
        e.packetPrice.text = i == 0 ? J.str(v['price']) : '';
        e.discountedPrice.text = i == 0 ? J.str(v['discounted_price']) : '';
        e.packetStock.text = J.str(v['stock']);
        if (i == 0) {
          looseStock = isUnlimited == 1 ? '' : J.str(v['stock']);
          looseUnitId = J.str(v['stock_unit_id']).isEmpty
              ? _defaultUnitId
              : J.str(v['stock_unit_id']);
        }
        _trackVariant(e);
        inputs.add(e);
      }
    }
    status = J.i(p['status'], status);
    _syncBaseToControllers();
    if (type == 'loose' ||
        inputs.length > 1 ||
        sellerDelivery ||
        (taxId != null)) {
      showAdvanced = true;
    } else if (isUnlimited == 1 && inputs.isNotEmpty) {
      inputs.first.packetStock.text = '';
    }
    setState(() {
      _dirty = false;
      _allowPop = false;
    });
  }

  void _addVariant() {
    setState(() {
      final e = type == 'packet'
          ? (_SimpleVariant()..packetStockUnitId = _defaultUnitId)
          : _SimpleVariant();
      _trackVariant(e);
      inputs.add(e);
      _dirty = true;
    });
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    manufacturer.dispose();
    returnDays.dispose();
    deliveryCharge.dispose();
    newTagsCtrl.dispose();
    priceCtrl.dispose();
    discountCtrl.dispose();
    stockCtrl.dispose();
    looseStockCtrl.dispose();
    prepCtrl.dispose();
    minQtyCtrl.dispose();
    for (final v in inputs) {
      v.dispose();
    }
    super.dispose();
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
      _dirty = true;
    });
  }

  static String slugify(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w ]+'), '')
      .trim()
      .replaceAll(RegExp(r' +'), '-');

  // شبكة خيارات من عمودين (مطابق .compact-seg في لوحة البائع)
  Widget _optGrid<T>({
    required String label,
    required List<_OptData<T>> options,
    required T current,
    required ValueChanged<T> onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              Expanded(
                child: _OptCard(
                  active: options[i].value == current,
                  icon: options[i].icon,
                  title: options[i].title,
                  iconBg: options[i].iconBg,
                  iconFg: options[i].iconFg,
                  onTap: () {
                    _dirty = true;
                    onPick(options[i].value);
                  },
                ),
              ),
              if (i != options.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _packetVariantCard(int k) {
    final v = inputs[k];
    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  'خيار البيع #${k + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'مغلّف',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (k != 0)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      v.dispose();
                      inputs.removeAt(k);
                    }),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('حذف'),
                  ),
              ],
            ),
          ),
          if (k == 0)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'هذا هو الخيار الأساسي للمنتج (نفس السعر في النموذج).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          TextField(
            controller: v.packetMeasurement,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'القياس',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: v.packetPrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'السعر *',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (k == 0) priceCtrl.text = v.packetPrice.text;
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: v.discountedPrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'سعر الخصم',
              border: const OutlineInputBorder(),
              errorText: v.discountError,
            ),
            onChanged: (val) {
              final p = v.packetPrice.text;
              final d = double.tryParse(val);
              final pp = double.tryParse(p);
              if (val.isNotEmpty && d != null && pp != null && d >= pp) {
                setState(() {
                  v.discountError = 'سعر الخصم يجب أن يكون أقل من السعر';
                  if (k == 0) discountError = v.discountError;
                });
              } else {
                setState(() {
                  v.discountError = null;
                  if (k == 0) discountError = null;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          if (isUnlimited != 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: v.packetStock,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'المخزون',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() => isUnlimited = 0);
                  if (k == 0) stockCtrl.text = val;
                },
              ),
            ),
          DropdownButtonFormField<String>(
            key: ValueKey('punit-${units.length}-${v.packetStockUnitId}-$k'),
            initialValue: units.any((u) => '${u['id']}' == v.packetStockUnitId)
                ? v.packetStockUnitId
                : (units.isNotEmpty ? '${units.first['id']}' : null),
            items: units
                .map(
                  (u) => DropdownMenuItem(
                    value: '${u['id']}',
                    child: Text(J.str(u['short_code'] ?? u['name'])),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() {
              v.packetStockUnitId = val;
              _dirty = true;
            }),
            decoration: const InputDecoration(
              labelText: 'الوحدة *',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _looseVariantCard(int k) {
    final v = inputs[k];
    final isBase = k == 0;
    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  'خيار البيع #${k + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.orange),
                  ),
                  child: Text(
                    'سائب',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (!isBase)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      v.dispose();
                      inputs.removeAt(k);
                    }),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('حذف'),
                  ),
              ],
            ),
          ),
          if (isBase)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'هذا هو الخيار الأساسي للمنتج (نفس السعر في النموذج).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          TextField(
            controller: v.looseMeasurement,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'القياس',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: isBase ? priceCtrl : v.loosePrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'السعر *',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (isBase) {
                v.packetPrice.text = priceCtrl.text;
                v.loosePrice.text = priceCtrl.text;
              }
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: isBase ? discountCtrl : v.looseDiscounted,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'سعر الخصم',
              border: const OutlineInputBorder(),
              errorText: isBase ? discountError : v.discountErrorLoose,
            ),
            onChanged: (val) {
              final price = (isBase ? priceCtrl.text : v.loosePrice.text);
              final d = double.tryParse(val);
              final pp = double.tryParse(price);
              if (val.isNotEmpty && d != null && pp != null && d >= pp) {
                setState(() {
                  if (isBase) {
                    discountError = 'سعر الخصم يجب أن يكون أقل من السعر';
                    v.discountError = discountError;
                  } else {
                    v.discountErrorLoose = 'سعر الخصم يجب أن يكون أقل من السعر';
                  }
                });
              } else {
                setState(() {
                  if (isBase) {
                    discountError = null;
                    v.discountError = null;
                  } else {
                    v.discountErrorLoose = null;
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingEdit) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.id == null ? 'منتج جديد' : 'تعديل منتج'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await confirmAction(
          context,
          title: 'مغادرة دون حفظ؟',
          body: 'لديك تغييرات غير محفوظة. إذا غادرت الآن ستفقدها.',
          confirmLabel: 'مغادرة',
          destructive: true,
        );
        if (leave && mounted) await _leaveWithoutSaving();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.id == null ? 'منتج جديد' : 'تعديل منتج'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── رأس البطاقة (مطابق .card-header في صفحة البائع) ──
              BrandedCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.id == null ? 'إنشاء منتج' : 'تعديل منتج',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        if (showAdvanced) {
                          showAdvanced = false;
                        } else {
                          advTab = 'sale';
                          showAdvanced = true;
                        }
                      }),
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(
                        showAdvanced ? 'إخفاء المتقدمة' : 'إعدادات إضافية',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: showAdvanced
                            ? AppColors.orange.withValues(alpha: 0.1)
                            : null,
                        side: BorderSide(
                          color: showAdvanced
                              ? AppColors.orange
                              : AppColors.border,
                        ),
                        foregroundColor: showAdvanced
                            ? AppColors.orange
                            : AppColors.navy,
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'أدخل الأساسيات فقط: الاسم، القسم، السعر، والصورة. باقي الإعدادات تُضبط تلقائياً.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              BrandedCard(
                child: Column(
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'اسم المنتج *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sec-${sections.length}-$sectionId'),
                      initialValue:
                          sections.any((s) => '${s['id']}' == sectionId)
                          ? sectionId
                          : null,
                      items: sections
                          .map(
                            (s) => DropdownMenuItem(
                              value: '${s['id']}',
                              child: Text(J.str(s['name'])),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        sectionId = v;
                        _dirty = true;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'قسم المتجر *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (sections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'لا توجد أقسام — أضف قسماً من إدارة المتجر أولاً.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'السعر *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (inputs.isNotEmpty) {
                          inputs.first.packetPrice.text = priceCtrl.text;
                          inputs.first.loosePrice.text = priceCtrl.text;
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'سعر الخصم (اختياري)',
                        border: const OutlineInputBorder(),
                        errorText: discountError,
                      ),
                      onChanged: (v) => _validateDiscount(v, priceCtrl.text),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'المخزون (فارغ = بدون حد)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _onSimpleStockInput,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isUnlimited == 1
                            ? 'المخزون غير محدود حالياً. اكتب رقماً هنا لتفعيل الحد.'
                            : 'الكمية المحدودة تُدار من هنا ومن الإعدادات المتقدمة معاً — نفس القيمة.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SectionHeader('صور المنتج'),
              UploadDropZone(
                label: imagePath == null
                    ? 'رفع الصورة الرئيسية *'
                    : 'تم اختيار الصورة ✓',
                selected: imagePath != null,
                subtitle: 'JPG/PNG — حتى 2 م.ب',
                onTap: () async {
                  final file = await pickStoreImage(
                    context,
                    reason:
                        'سنفتح المعرض لاختيار صورة المنتج فقط. لا نصل إلى صورك الأخرى.',
                  );
                  if (file != null && mounted)
                    setState(() {
                      imagePath = file.path;
                      _dirty = true;
                    });
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickOthers,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  otherPaths.isEmpty
                      ? 'صور إضافية (اختياري)'
                      : 'صور إضافية (${otherPaths.length})',
                ),
              ),
              if (otherPaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: otherPaths.asMap().entries.map((e) {
                    return Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.greyBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.image,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          child: InkWell(
                            onTap: () => setState(() {
                              otherPaths.removeAt(e.key);
                              _dirty = true;
                            }),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
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
                  child: Text(
                    'الصور الحالية',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
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
                          NetImage(
                            url,
                            width: 72,
                            height: 72,
                            borderRadius: BorderRadius.circular(8),
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
                                _dirty = true;
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: gone ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  gone ? Icons.undo : Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              const SectionHeader('الوصف (اختياري)'),
              BrandedCard(
                child: TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    hintText: 'اختياري — إن تُرك فارغاً يُستخدم اسم المنتج',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── اختصارات المتقدمة (مطابق .product-adv-shortcuts) ──
              _DashedBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إعدادات إضافية (اختياري)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'اضغط على أي جزء لفتحه مباشرة — النموذج الأساسي يبقى كما هو.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    _AdvShortcut(
                      icon: Icons.local_offer_outlined,
                      title: 'البيع',
                      desc: 'مقاسات، مخزون، خيارات',
                      active: showAdvanced && advTab == 'sale',
                      onTap: () => setState(() {
                        advTab = 'sale';
                        showAdvanced = true;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _AdvShortcut(
                      icon: Icons.local_shipping_outlined,
                      title: 'التوصيل',
                      desc: 'من يوصّل والضريبة',
                      active: showAdvanced && advTab == 'delivery',
                      onTap: () => setState(() {
                        advTab = 'delivery';
                        showAdvanced = true;
                      }),
                      iconBg: const Color(0xFFE8EEF4),
                      iconFg: const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 8),
                    _AdvShortcut(
                      icon: Icons.undo,
                      title: 'السياسات',
                      desc: 'إرجاع ومعلومات إضافية',
                      active: showAdvanced && advTab == 'policy',
                      onTap: () => setState(() {
                        advTab = 'policy';
                        showAdvanced = true;
                      }),
                      iconBg: const Color(0xFFDCFCE7),
                      iconFg: const Color(0xFF059669),
                    ),
                  ],
                ),
              ),
              if (showAdvanced) ...[
                const SizedBox(height: 12),
                // ── رأس اللوحة (مطابق .product-adv-head) ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEEF2F6)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إعدادات إضافية',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                            Text(
                              advTab == 'delivery'
                                  ? 'التوصيل والضريبة'
                                  : advTab == 'policy'
                                  ? 'سياسات المنتج'
                                  : 'خيارات البيع',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => showAdvanced = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.greyBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── تبويبات اللوحة (مطابق .product-adv-tabs) ──
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFBFC),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEEF2F6)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _AdvTabBtn(
                        icon: Icons.local_offer_outlined,
                        title: 'البيع',
                        active: advTab == 'sale',
                        onTap: () => setState(() => advTab = 'sale'),
                      ),
                      const SizedBox(width: 4),
                      _AdvTabBtn(
                        icon: Icons.local_shipping_outlined,
                        title: 'التوصيل',
                        active: advTab == 'delivery',
                        onTap: () => setState(() => advTab = 'delivery'),
                      ),
                      const SizedBox(width: 4),
                      _AdvTabBtn(
                        icon: Icons.undo,
                        title: 'السياسات',
                        active: advTab == 'policy',
                        onTap: () => setState(() => advTab = 'policy'),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F6F8),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      if (advTab == 'sale')
                        BrandedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _AdvSectionTitle('خيارات البيع'),
                              _optGrid<String>(
                                label: 'نوع البيع',
                                options: const [
                                  _OptData(
                                    value: 'loose',
                                    icon: Icons.balance,
                                    title: 'سائب',
                                  ),
                                  _OptData(
                                    value: 'packet',
                                    icon: Icons.inventory_2_outlined,
                                    title: 'مغلّف',
                                  ),
                                ],
                                current: type,
                                onPick: (v) => _setSaleType(v),
                              ),
                              _optGrid<int>(
                                label: 'حد المخزون',
                                options: const [
                                  _OptData(
                                    value: 1,
                                    icon: Icons.all_inclusive,
                                    title: 'غير محدود',
                                    iconBg: Color(0xFFDCFCE7),
                                    iconFg: Color(0xFF16A34A),
                                  ),
                                  _OptData(
                                    value: 0,
                                    icon: Icons.widgets_outlined,
                                    title: 'محدود',
                                  ),
                                ],
                                current: isUnlimited,
                                onPick: (v) => _setStockMode(v == 1),
                              ),
                              if (type == 'packet') ...[
                                ...inputs.asMap().entries.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _packetVariantCard(e.key),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _addVariant,
                                  icon: const Icon(Icons.add),
                                  label: const Text('إضافة خيار'),
                                ),
                              ] else ...[
                                ...inputs.asMap().entries.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _looseVariantCard(e.key),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _addVariant,
                                  icon: const Icon(Icons.add),
                                  label: const Text('إضافة خيار'),
                                ),
                                const SizedBox(height: 10),
                                if (isUnlimited != 1)
                                  TextField(
                                    controller: looseStockCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'مخزون السائب (مشترك) *',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => setState(() {
                                      looseStock = v;
                                      stockCtrl.text = v;
                                      if (inputs.isNotEmpty)
                                        inputs.first.packetStock.text = v;
                                    }),
                                  ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    'loose-unit-${units.length}-$looseUnitId',
                                  ),
                                  initialValue:
                                      units.any(
                                        (u) => '${u['id']}' == looseUnitId,
                                      )
                                      ? looseUnitId
                                      : (units.isNotEmpty
                                            ? '${units.first['id']}'
                                            : null),
                                  items: units
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: '${u['id']}',
                                          child: Text(
                                            J.str(u['short_code'] ?? u['name']),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    looseUnitId = v;
                                    _dirty = true;
                                  }),
                                  decoration: const InputDecoration(
                                    labelText: 'الوحدة *',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (advTab == 'delivery')
                        BrandedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _AdvSectionTitle('التوصيل والضريبة'),
                              _optGrid<bool>(
                                label: 'طريقة التوصيل • الافتراضي: المنصة',
                                options: const [
                                  _OptData(
                                    value: false,
                                    icon: Icons.local_shipping_outlined,
                                    title: 'المنصة',
                                  ),
                                  _OptData(
                                    value: true,
                                    icon: Icons.storefront,
                                    title: 'المتجر',
                                  ),
                                ],
                                current: sellerDelivery,
                                onPick: (v) =>
                                    setState(() => sellerDelivery = v),
                              ),
                              if (sellerDelivery)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _DashedBox(
                                    color: AppColors.orange,
                                    bg: const Color(0xFFFFFBF5),
                                    child: TextField(
                                      controller: deliveryCharge,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'أجرة توصيل المتجر *',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ),
                              DropdownButtonFormField<String>(
                                key: ValueKey('tax-${taxes.length}-$taxId'),
                                initialValue:
                                    taxes.any((t) => '${t['id']}' == taxId)
                                    ? taxId
                                    : null,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('بدون ضريبة'),
                                  ),
                                  ...taxes.map(
                                    (t) => DropdownMenuItem(
                                      value: '${t['id']}',
                                      child: Text(
                                        J.str(t['title'] ?? t['name']),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  taxId = v;
                                  _dirty = true;
                                }),
                                decoration: const InputDecoration(
                                  labelText: 'الضريبة',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'الوسوم',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              if (allTags.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  children: allTags.map((t) {
                                    final id = J.i(t['id']);
                                    final on = tagIds.contains(id);
                                    return FilterChip(
                                      label: Text(J.str(t['name'])),
                                      selected: on,
                                      onSelected: (_) => setState(() {
                                        if (on) {
                                          tagIds.remove(id);
                                        } else {
                                          tagIds.add(id);
                                        }
                                        _dirty = true;
                                      }),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: newTagsCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'وسوم جديدة (افصل بفاصلة)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (advTab == 'policy')
                        BrandedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _AdvSectionTitle('سياسات المنتج'),
                              _optGrid<int>(
                                label: 'قابل للإرجاع',
                                options: const [
                                  _OptData(
                                    value: 1,
                                    icon: Icons.undo,
                                    title: 'نعم',
                                    iconBg: Color(0xFFDCFCE7),
                                    iconFg: Color(0xFF16A34A),
                                  ),
                                  _OptData(
                                    value: 0,
                                    icon: Icons.block,
                                    title: 'لا',
                                    iconBg: Color(0xFFF3F4F6),
                                    iconFg: Color(0xFF6B7280),
                                  ),
                                ],
                                current: returnStatus,
                                onPick: (v) => setState(() => returnStatus = v),
                              ),
                              if (returnStatus == 1)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _DashedBox(
                                    color: AppColors.success,
                                    bg: const Color(0xFFF0FDF4),
                                    child: TextField(
                                      controller: returnDays,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'أقصى أيام الإرجاع',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ),
                              TextField(
                                controller: manufacturer,
                                decoration: const InputDecoration(
                                  labelText: 'الشركة المصنعة',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'made-${countries.length}-$madeInId',
                                ),
                                initialValue:
                                    countries.any(
                                      (c) => '${c['id']}' == madeInId,
                                    )
                                    ? madeInId
                                    : null,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('اختر البلد'),
                                  ),
                                  ...countries.map(
                                    (c) => DropdownMenuItem(
                                      value: '${c['id']}',
                                      child: Text(
                                        '${J.str(c['name'])} [${J.str(c['code'])}]',
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  madeInId = v;
                                  _dirty = true;
                                }),
                                decoration: const InputDecoration(
                                  labelText: 'صنع في',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              if (isHomeSeller) ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: prepCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'وقت التحضير',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: minQtyCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'أقل كمية للطلب',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              onPressed: busy ? null : _save,
              child: busy ? const BusySpinner() : const Text('حفظ المنتج'),
            ),
          ),
        ),
      ),
    );
  }

  // ── مطابق saveRecord في EditProduct.vue (مسار البائع) ──
  Future<void> _save() async {
    if (!await confirmWrite(context)) return;
    if (name.text.trim().isEmpty) {
      toast(context, 'أدخل اسم المنتج');
      return;
    }
    if (sectionId == null || sectionId!.isEmpty) {
      toast(context, 'قسم المتجر مطلوب');
      return;
    }
    if (widget.id == null && imagePath == null) {
      toast(context, 'الصورة الرئيسية مطلوبة');
      return;
    }
    _ensureVariant();
    _syncControllersToBase();
    // مزامنة الخيار الأساسي مع النموذج (مطابق syncLooseOptionFromBase)
    if (type == 'loose') {
      final row = inputs.first;
      row.loosePrice.text = priceCtrl.text.isNotEmpty
          ? priceCtrl.text
          : row.loosePrice.text;
      row.looseDiscounted.text = discountCtrl.text.isNotEmpty
          ? discountCtrl.text
          : row.looseDiscounted.text;
      if (row.looseMeasurement.text.trim().isEmpty &&
          row.packetMeasurement.text.trim().isNotEmpty) {
        row.looseMeasurement.text = row.packetMeasurement.text;
      }
      looseUnitId ??= _defaultUnitId;
      if (isUnlimited == 1) {
        looseStock = '0';
      } else if (_isEmptyStock(looseStock)) {
        toast(context, 'أدخل كمية المخزون');
        return;
      }
    } else {
      final row = inputs.first;
      row.packetStockUnitId ??= _defaultUnitId;
      if (isUnlimited == 1) {
        row.packetStock.text = '0';
      } else if (_isEmptyStock(row.packetStock.text)) {
        toast(context, 'أدخل كمية المخزون');
        return;
      }
    }
    final basePrice = double.tryParse(priceCtrl.text.trim()) ?? 0;
    if (basePrice <= 0) {
      toast(context, 'أدخل السعر');
      return;
    }
    final baseDisc = discountCtrl.text.trim();
    if (baseDisc.isNotEmpty) {
      final d = double.tryParse(baseDisc) ?? -1;
      if (d >= basePrice) {
        setState(() => discountError = 'سعر الخصم يجب أن يكون أقل من السعر');
        toast(context, 'سعر الخصم يجب أن يكون أقل من السعر');
        return;
      }
    }
    if (sellerDelivery) {
      final c = deliveryCharge.text.trim();
      final v = double.tryParse(c);
      if (c.isEmpty || v == null || v < 0) {
        toast(context, 'أدخل أجرة توصيل المتجر');
        return;
      }
    }
    if (description.text.trim().isEmpty) description.text = name.text.trim();
    // حل تعارض المخزون النهائي (مطابق resolveStockForSave)
    if (isUnlimited == 1) {
      looseStock = '0';
      for (final r in inputs) {
        r.packetStock.text = '0';
      }
    } else if (type == 'loose' &&
        _isEmptyStock(looseStock) &&
        !_isEmptyStock(inputs.first.packetStock.text)) {
      looseStock = inputs.first.packetStock.text;
    }
    setState(() => busy = true);
    try {
      final map = <String, dynamic>{
        'name': name.text.trim(),
        'slug': slugify(name.text),
        'seller_id': app.sellerId,
        'tax_id': (taxId == null || taxId!.isEmpty) ? 0 : taxId,
        'brand_id': 0,
        'description': description.text.isEmpty
            ? name.text.trim()
            : description.text,
        'type': type,
        'is_unlimited_stock': isUnlimited,
        'fssai_lic_no': '',
        'category_id': categoryId,
        'seller_section_id': sectionId ?? '',
        'product_type': 0,
        'manufacturer': manufacturer.text.trim(),
        'made_in': (madeInId == null || madeInId!.isEmpty) ? 0 : madeInId,
        'return_status': returnStatus,
        'return_days': returnStatus == 1
            ? (returnDays.text.isEmpty ? '0' : returnDays.text)
            : 0,
        'cancelable_status': 0,
        'till_status': '',
        'cod_allowed_status': 1,
        'seller_delivery_enabled': sellerDelivery ? 1 : 0,
        'delivery_by': sellerDelivery ? 'seller' : 'platform',
        'seller_delivery_charge': sellerDelivery
            ? deliveryCharge.text.trim()
            : '',
        'can_deliver': 1,
        'max_allowed_quantity': '',
        'is_home_product': isHomeSeller ? 1 : 0,
        'preparation_time': prepCtrl.text.trim(),
        'min_order_qty': minQtyCtrl.text.trim().isEmpty
            ? 1
            : minQtyCtrl.text.trim(),
        'old_price': '',
        'is_approved': isApproved,
        'tax_included_in_price': taxIncluded,
        'status': widget.id == null ? 1 : status,
        'loose_stock': looseStock.isEmpty ? '0' : looseStock,
        'loose_stock_unit_id': looseUnitId ?? _defaultUnitId,
      };
      final allTagNames = <String>[
        ...tagIds.map((e) => '$e'),
        ...newTagsCtrl.text
            .split(RegExp(r'[,;]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      ];
      map['tag_ids'] = allTagNames.join(',');
      if (type == 'packet') {
        map['variant_id[]'] = inputs.map((e) => e.id ?? '').toList();
        map['packet_measurement[]'] = inputs
            .map((e) => _resolvedMeasurement(e.packetMeasurement))
            .toList();
        map['packet_price[]'] = inputs
            .map((e) => e.packetPrice.text.isEmpty ? '0' : e.packetPrice.text)
            .toList();
        map['discounted_price[]'] = inputs
            .map(
              (e) =>
                  e.discountedPrice.text.isEmpty ? '0' : e.discountedPrice.text,
            )
            .toList();
        map['packet_stock[]'] = inputs
            .map((e) => (e.packetStock.text.isEmpty ? '0' : e.packetStock.text))
            .toList();
        map['packet_stock_unit_id[]'] = inputs
            .map(
              (e) =>
                  (e.packetStockUnitId == null || e.packetStockUnitId!.isEmpty)
                  ? _defaultUnitId
                  : e.packetStockUnitId,
            )
            .toList();
        map['packet_status[]'] = inputs.map((e) => '1').toList();
      } else {
        map['variant_id[]'] = inputs.map((e) => e.id ?? '').toList();
        map['loose_measurement[]'] = inputs.map((e) {
          final v = e.looseMeasurement.text.trim().isNotEmpty
              ? e.looseMeasurement.text
              : e.packetMeasurement.text;
          if (v.trim().isEmpty || v.trim() == '0') return '1';
          return v;
        }).toList();
        map['loose_custom_title[]'] = inputs.map((e) => '').toList();
        map['loose_price[]'] = inputs.asMap().entries.map((en) {
          if (en.key == 0 && priceCtrl.text.isNotEmpty) return priceCtrl.text;
          final v = en.value.loosePrice.text.isNotEmpty
              ? en.value.loosePrice.text
              : en.value.packetPrice.text;
          return v.isEmpty ? '0' : v;
        }).toList();
        map['loose_discounted_price[]'] = inputs.asMap().entries.map((en) {
          if (en.key == 0 && discountCtrl.text.isNotEmpty)
            return discountCtrl.text;
          final v = en.value.looseDiscounted.text.isNotEmpty
              ? en.value.looseDiscounted.text
              : en.value.discountedPrice.text;
          return v.isEmpty ? '0' : v;
        }).toList();
        map['packet_stock[]'] = inputs
            .map((e) => e.packetStock.text.isEmpty ? '0' : e.packetStock.text)
            .toList();
      }
      if (widget.id != null) {
        map['id'] = widget.id;
        if (deleteImageIds.isNotEmpty)
          map['deleteImageIds'] = '[${deleteImageIds.join(',')}]';
      }
      if (imagePath != null) {
        map['image'] = await MultipartFile.fromFile(
          imagePath!,
          filename: 'product.jpg',
        );
      }
      for (var i = 0; i < otherPaths.length; i++) {
        map['other_images[$i]'] = await MultipartFile.fromFile(
          otherPaths[i],
          filename: 'other_$i.jpg',
        );
      }
      final data = FormData.fromMap(map);
      final result = widget.id == null
          ? await app.api.saveProductForm(data)
          : await app.api.updateProductForm(data);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.ok) {
          _dirty = false;
          _allowPop = true;
        }
      });
      if (!context.mounted) return;
      toast(context, result.ok ? 'تم الحفظ' : result.message);
      if (result.ok) {
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => busy = false);
      if (context.mounted) toast(context, 'تعذر الحفظ');
    }
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
  String rawBalance = '—';
  String pending = '0';
  double available = 0;
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
      available = J.d(d['balance']);
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
          height: 360,
          child: NetImage(url, fit: BoxFit.contain, iconSize: 40),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الرصيد المتاح: ${Fmt.money(rawBalance)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: message,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  alignLabelWithHint: true,
                ),
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
            child: const Text('إرسال'),
          ),
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
    if (available > 0 && value > available) {
      if (mounted) toast(context, 'المبلغ أكبر من الرصيد المتاح');
      return;
    }
    final result = await app.api.addWithdrawal(
      amount: value.toString(),
      message: note,
    );
    if (!mounted) return;
    toast(context, result.ok ? 'تم إرسال الطلب' : result.message);
    if (result.ok) _load();
  }

  static String _statusKey(dynamic raw) {
    final value = J.str(raw).toLowerCase();
    if (value == '0' || value == 'pending') return '0';
    if (value == '1' || value == 'approved' || value == 'accepted') return '1';
    if (value == '2' || value == 'rejected') return '2';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final shown = filter.isEmpty
        ? items
        : items.where((e) => _statusKey(e['status']) == filter).toList();
    Widget stat(String label, String value, Color color, IconData icon) {
      return Expanded(
        child: BrandedCard(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('طلبات السحب')),
      floatingActionButton: app.canWrite
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('طلب سحب'),
            )
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
            Row(
              children: [
                stat(
                  'الرصيد المتاح',
                  Fmt.money(rawBalance),
                  AppColors.success,
                  Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(width: 8),
                stat(
                  'قيد الانتظار',
                  Fmt.money(pending),
                  AppColors.orangeText,
                  Icons.hourglass_empty,
                ),
                const SizedBox(width: 8),
                stat(
                  'إجمالي الرصيد',
                  Fmt.money(available),
                  AppColors.navy,
                  Icons.account_balance,
                ),
              ],
            ),
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
              final st = _statusKey(item['status']);
              final stLabel = st == '1'
                  ? 'معتمد'
                  : st == '2'
                  ? 'مرفوض'
                  : 'قيد الانتظار';
              final stColor = st == '1'
                  ? AppColors.success
                  : st == '2'
                  ? AppColors.error
                  : AppColors.orangeText;
              final receipt = _img(
                J.str(
                  item['receipt_image_url'].toString().isNotEmpty
                      ? item['receipt_image_url']
                      : item['receipt_image'],
                ),
              );
              return BrandedCard(
                child: Row(
                  children: [
                    if (receipt.isNotEmpty)
                      InkWell(
                        onTap: () => _preview(receipt),
                        child: NetImage(
                          receipt,
                          width: 56,
                          height: 56,
                          borderRadius: BorderRadius.circular(8),
                          iconSize: 22,
                        ),
                      )
                    else
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.greyBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.receipt_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Fmt.money(item['amount']),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            Fmt.date(item['created_at'], withTime: true),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (J.str(item['message']).isNotEmpty)
                            Text(
                              J.str(item['message']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            stLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: stColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (app.canWrite && st == '0')
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'delete') {
                            final ok = await confirmAction(
                              context,
                              title: 'حذف الطلب',
                              body: 'حذف طلب السحب؟',
                              confirmLabel: 'حذف',
                              destructive: true,
                            );
                            if (!ok || !context.mounted) return;
                            final r = await app.api.deleteWithdrawal(
                              item['id'],
                            );
                            if (!context.mounted) return;
                            toast(context, r.ok ? 'تم الحذف' : r.message);
                            if (r.ok) _load();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                  ],
                ),
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

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> txns = [];
  Map<String, dynamic> summary = {};
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = false;
  String? error;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!mounted) return;
    setState(() {
      if (more) {
        loadingMore = true;
      } else {
        loading = true;
        error = null;
      }
    });
    final result = await app.api.wallet(
      limit: _pageSize,
      offset: more ? txns.length : 0,
      search: searchCtrl.text.trim(),
    );
    if (!mounted) return;
    final rows = result.dataMaps;
    setState(() {
      if (more) {
        txns.addAll(rows);
      } else {
        txns
          ..clear()
          ..addAll(rows);
        summary = result.dataMap;
      }
      hasMore = rows.length >= _pageSize;
      loading = false;
      loadingMore = false;
      error = result.ok ? null : result.failMessage;
    });
  }

  String _balanceText() {
    for (final key in [
      'wallet_balance',
      'balance',
      'available_balance',
      'total_balance',
    ]) {
      if (summary[key] != null) return Fmt.money(summary[key]);
    }
    return Fmt.money(
      app.seller['wallet_balance'] ?? app.seller['balance'] ?? 0,
    );
  }

  bool _isCredit(Map<String, dynamic> item) {
    final type = '${item['type'] ?? item['transaction_type'] ?? ''}'
        .toLowerCase();
    if (type.contains('debit') || type.contains('withdraw')) return false;
    final amount = J.d(item['amount']);
    return !type.contains('credit') ? amount >= 0 : true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'ابحث في العمليات',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchCtrl.clear();
                          _load();
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: FetchBody(
              loading: loading,
              onRefresh: () => _load(),
              error: error,
              isEmpty: txns.isEmpty,
              emptyText: searchCtrl.text.trim().isEmpty
                  ? 'لا توجد عمليات في المحفظة بعد'
                  : 'لا توجد عمليات مطابقة للبحث',
              emptyIcon: Icons.account_balance_wallet_outlined,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.navy, const Color(0xFF163A5F)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الرصيد المتاح',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _balanceText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'آخر ${txns.length} عملية',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...txns.map((item) {
                    final credit = _isCredit(item);
                    final amount = J.d(item['amount']).abs();
                    final title = J.str(
                      item['message'] ??
                          item['description'] ??
                          item['reason'] ??
                          (credit ? 'إيداع' : 'سحب'),
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (credit ? Colors.green : Colors.red)
                              .withValues(alpha: 0.1),
                          child: Icon(
                            credit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: credit ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        title: Text(title),
                        subtitle: Text(
                          Fmt.date(
                            item['created_at'] ?? item['date'],
                            withTime: true,
                          ),
                        ),
                        trailing: Text(
                          '${credit ? '+' : '-'}${Fmt.money(amount)}',
                          style: TextStyle(
                            color: credit ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (hasMore)
                    Center(
                      child: loadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(),
                            )
                          : TextButton(
                              onPressed: () => _load(more: true),
                              child: const Text('عرض المزيد'),
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
              borderRadius: BorderRadius.circular(10),
            ),
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
                const Text(
                  'إشعارات الجهاز الفورية',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _busy ? 'جاري الطلب...' : PushService.statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
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
  Widget _sectionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String path,
    String? subtitle,
  }) {
    return BrandedCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: () => context.push(path),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
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
                    child: Icon(
                      Icons.storefront,
                      color: AppColors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.storeName,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          J.str(app.user?['email'] ?? app.seller['mobile']),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
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
            _sectionTile(
              context,
              icon: Icons.settings_outlined,
              title: 'الإعدادات',
              subtitle: 'ساعات العمل وكلمة المرور',
              path: '/settings',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.badge_outlined,
              title: 'ملف المتجر',
              path: '/profile',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.layers_outlined,
              title: 'أقسام المتجر',
              subtitle: 'أوقات العمل والترتيب',
              path: '/sections',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.straighten,
              title: 'الوحدات',
              path: '/units',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.upload_file,
              title: 'رفع منتجات جماعي',
              path: '/bulk',
            ),
            const SizedBox(height: 20),
            const SectionHeader('المالية'),
            _sectionTile(
              context,
              icon: Icons.account_balance,
              title: 'المحاسبة',
              path: '/accounting',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'المحفظة',
              path: '/wallet',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.payments_outlined,
              title: 'طلبات السحب',
              path: '/withdrawals',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.bar_chart,
              title: 'التقارير',
              path: '/reports',
            ),
            const SizedBox(height: 20),
            const SectionHeader('العروض'),
            _sectionTile(
              context,
              icon: Icons.local_offer_outlined,
              title: 'أكواد الخصم',
              path: '/promos',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.flash_on_outlined,
              title: 'عروض فلاش',
              path: '/flash',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.card_giftcard,
              title: 'اشترِ واحصل',
              path: '/bxgy',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.discount_outlined,
              title: 'خصم التصنيف',
              path: '/category-discounts',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.shopping_bag_outlined,
              title: 'طلبات التجارة الجديدة',
              path: '/seller-orders',
            ),
            const SizedBox(height: 20),
            const SectionHeader('الدعم'),
            const _PushStatusTile(),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'السياسات',
              path: '/privacy',
            ),
            const SizedBox(height: 8),
            _sectionTile(
              context,
              icon: Icons.description_outlined,
              title: 'الشروط والأحكام',
              path: '/terms',
            ),
            if (app.supportPhone.isNotEmpty) ...[
              const SizedBox(height: 8),
              BrandedCard(
                onTap: () => openTel(app.supportPhone),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.call_outlined,
                        color: AppColors.navy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'اتصال بالدعم',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            app.supportPhone,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_left, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
            if (app.supportEmail.isNotEmpty) ...[
              const SizedBox(height: 8),
              BrandedCard(
                onTap: () => openMail(app.supportEmail),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.mail_outline,
                        color: AppColors.navy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'البريد الإلكتروني للدعم',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            app.supportEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
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
                final ok = await confirmAction(
                  context,
                  title: 'تسجيل الخروج',
                  body: 'هل تريد تسجيل الخروج؟',
                );
                if (!ok || !context.mounted) return;
                await app.logout();
                if (context.mounted) context.go('/login');
              },
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppColors.error),
                  SizedBox(width: 12),
                  Text(
                    'خروج',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'سيتم حذف المتجر نهائياً ولا يمكن التراجع. أدخل كلمة المرور للتأكيد.',
                            ),
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
                                  final result = await app.api.deleteAccount(
                                    password: passwordCtrl.text,
                                  );
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
                                    color: Colors.white,
                                  ),
                                )
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
            const SizedBox(height: 16),
            Center(
              child: Text(
                'سريع MART - تاجر • الإصدار ${AppConfig.appVersion}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
