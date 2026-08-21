import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../core/app_controller.dart';
import '../core/json_util.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool storeOnline = true;

  @override
  void initState() {
    super.initState();
    app.refreshDashboard();
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
        final totalSales = _dashValue(d, ['total_sales', 'sales', 'gross_sales', 'wallet_balance'], '—');
        final storeRating = _dashValue(d, ['store_rating', 'rating', 'avg_rating'], '—');

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
                      const Icon(Icons.wifi_off_outlined, color: AppColors.error),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('تعذر تحديث الرئيسية')),
                      TextButton(onPressed: app.refreshDashboard, child: const Text('إعادة', style: TextStyle(color: AppColors.orange))),
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
                  child: const Row(
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
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  KpiMetricCard(
                    icon: Icons.payments_outlined,
                    label: 'إجمالي المبيعات',
                    value: totalSales,
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
                    iconColor: AppColors.success,
                    onTap: () => context.push('/orders'),
                  ),
                  KpiMetricCard(
                    icon: Icons.star_outline,
                    label: 'تقييم المتجر',
                    value: storeRating == '—' ? storeRating : '$storeRating ★',
                    iconColor: AppColors.navy,
                    onTap: () => context.push('/ratings'),
                  ),
                ],
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(storeOnline ? Icons.store : Icons.store_mall_directory_outlined, color: storeOnline ? AppColors.success : AppColors.textSecondary, size: 20),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(storeOnline ? 'متصل' : 'غير متصل', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Switch(
                                value: storeOnline,
                                activeThumbColor: AppColors.orange,
                                onChanged: (v) {
                                  setState(() => storeOnline = v);
                                  toast(context, v ? 'المتجر متاح الآن' : 'المتجر غير متاح مؤقتاً');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader('الإدارة'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  DashboardShortcutCard(icon: Icons.receipt_long, title: 'الطلبات', value: '$totalOrders', path: '/orders'),
                  DashboardShortcutCard(icon: Icons.inventory_2, title: 'المنتجات', value: _dashValue(d, ['product_count']), path: '/products'),
                  DashboardShortcutCard(icon: Icons.warning_amber, title: 'نفد المخزون', value: _dashValue(d, ['sold_out_count']), path: '/products'),
                  DashboardShortcutCard(icon: Icons.account_balance, title: 'المحاسبة', path: '/accounting'),
                  DashboardShortcutCard(icon: Icons.account_balance_wallet, title: 'المحفظة', path: '/wallet'),
                  DashboardShortcutCard(icon: Icons.payments_outlined, title: 'السحب', path: '/withdrawals'),
                  DashboardShortcutCard(icon: Icons.bar_chart, title: 'التقارير', path: '/reports'),
                  DashboardShortcutCard(icon: Icons.assignment_return, title: 'الإرجاع', path: '/returns'),
                  DashboardShortcutCard(icon: Icons.local_offer, title: 'أكواد الخصم', path: '/promos'),
                  DashboardShortcutCard(icon: Icons.flash_on, title: 'عروض فلاش', path: '/flash'),
                  DashboardShortcutCard(icon: Icons.card_giftcard, title: 'اشترِ واحصل', path: '/bxgy'),
                  DashboardShortcutCard(icon: Icons.discount, title: 'خصم تصنيف', path: '/category-discounts'),
                  DashboardShortcutCard(icon: Icons.category_outlined, title: 'تصنيفاتي', path: '/categories'),
                ],
              ),
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
  bool loading = true;
  String? error;
  bool gridView = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await app.api.orders();
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
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
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: items.isEmpty,
        emptyText: 'لا توجد طلبات حالياً',
        child: gridView ? _buildGrid() : _buildList(),
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
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _orderCard(items[i], compact: true),
    );
  }

  Widget _orderCard(Map<String, dynamic> order, {bool compact = false}) {
    final status = J.str(order['order_status'] ?? order['active_status']);
    final id = order['order_id'] ?? order['id'];
    return BrandedCard(
      padding: EdgeInsets.all(compact ? 12 : 16),
      onTap: () => context.push('/orders/$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.orange, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#$id', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(J.str(order['user_name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          OrderStatusBadge(status: status),
          const SizedBox(height: 8),
          Text(
            '${order['final_total'] ?? order['total'] ?? '—'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
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
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                Text(J.str(order?['user_name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(J.str(order?['address'] ?? order?['mobile']), style: const TextStyle(color: AppColors.textSecondary)),
                if (J.str(order?['mobile']).isNotEmpty) ...[
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('تحديث الحالة'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((s) {
              final name = J.str(s['status'] ?? s['name']);
              final isActive = currentStatus.toLowerCase() == name.toLowerCase();
              return StageActionButton(
                label: name,
                icon: _statusIcon(name),
                active: isActive,
                enabled: app.canWrite,
                onTap: app.canWrite
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
            const BrandedCard(
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
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.orange),
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
                _invoiceRow('العميل', J.str(order?['user_name'])),
                _invoiceRow('الجوال', J.str(order?['mobile'])),
                _invoiceRow('العنوان', J.str(order?['address'])),
                _invoiceRow('الدفع', J.str(order?['payment_method'])),
                _invoiceRow('المجموع', '${order?['total']}'),
                _invoiceRow('النهائي', '${order?['final_total']}', bold: true),
              ],
            ),
          ),
          if (app.canAssignDelivery) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: app.canWrite && boys.isNotEmpty
                  ? () => showDriverAssignmentSheet(
                        context,
                        drivers: boys,
                        onAssign: (driver) async {
                          final ok = await confirmAction(
                            context,
                            title: 'تعيين موصل',
                            body: 'تعيين ${J.str(driver['name'])} لهذا الطلب؟',
                          );
                          if (!ok || !context.mounted) return;
                          final result = await app.api.assignDelivery(orderId: widget.id, deliveryBoyId: driver['id']);
                          if (!context.mounted) return;
                          toast(context, result.ok ? 'تم التعيين' : result.message);
                          if (result.ok) _load();
                        },
                      )
                  : null,
              icon: const Icon(Icons.delivery_dining),
              label: Text(boys.isEmpty ? 'لا يوجد موصلون' : 'تعيين موصل'),
            ),
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
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
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
                await context.push('/products/edit/${p['id']}');
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
                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.navy),
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
            );
          },
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

class _ProductEditScreenState extends State<ProductEditScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final discounted = TextEditingController(text: '0');
  final stock = TextEditingController();
  final measurement = TextEditingController(text: '1');
  final manufacturer = TextEditingController();
  final madeIn = TextEditingController();
  final returnDays = TextEditingController(text: '0');
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> taxes = [];
  String? categoryId;
  String? sectionId;
  String? unitId;
  String? taxId;
  String? imagePath;
  bool unlimited = false;
  bool returnable = false;
  bool taxIncluded = true;
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
        manufacturer.text = J.str(p['manufacturer']);
        madeIn.text = J.str(p['made_in']);
        returnDays.text = J.str(p['return_days'], '0');
        unlimited = J.flag(p['is_unlimited_stock']);
        returnable = J.flag(p['return_status']);
        taxIncluded = J.flag(p['tax_included_in_price'] ?? 1);
        final variants = J.maps(p['variants']);
        if (variants.isNotEmpty) {
          price.text = J.str(variants.first['price']);
          discounted.text = J.str(variants.first['discounted_price'], '0');
          stock.text = J.str(variants.first['stock']);
          measurement.text = J.str(variants.first['measurement'], '1');
          unitId = '${variants.first['stock_unit_id'] ?? unitId}';
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    discounted.dispose();
    stock.dispose();
    measurement.dispose();
    manufacturer.dispose();
    madeIn.dispose();
    returnDays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'منتج جديد' : 'تعديل منتج')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('معلومات المنتج'),
          BrandedCard(
            child: Column(
              children: [
                labeledField(name, 'اسم المنتج'),
                labeledField(description, 'الوصف', maxLines: 3),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader('التسعير والمخزون'),
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
                labeledField(price, 'السعر', type: TextInputType.number),
                labeledField(discounted, 'سعر بعد الخصم', type: TextInputType.number),
                labeledField(measurement, 'القياس', type: TextInputType.number),
                DropdownButtonFormField<String>(
                  key: ValueKey('unit-${units.length}-$unitId'),
                  initialValue: dropdownId(unitId, units),
                  items: units.map((u) => DropdownMenuItem(value: '${u['id']}', child: Text(J.str(u['name'] ?? u['short_code'])))).toList(),
                  onChanged: (v) => setState(() => unitId = v),
                  decoration: const InputDecoration(labelText: 'وحدة المخزون'),
                ),
                const SizedBox(height: 10),
                if (!unlimited) labeledField(stock, 'المخزون', type: TextInputType.number),
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
          const SectionHeader('صورة المنتج'),
          UploadDropZone(
            label: imagePath == null ? 'رفع صورة المنتج' : 'تم اختيار الصورة ✓',
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await confirmWrite(context)) return;
                    if (name.text.trim().isEmpty || price.text.trim().isEmpty) {
                      toast(context, 'أكمل اسم المنتج والسعر');
                      return;
                    }
                    if (widget.id == null && imagePath == null) {
                      toast(context, 'صورة المنتج مطلوبة');
                      return;
                    }
                    setState(() => busy = true);
                    final map = <String, dynamic>{
                      'name': name.text,
                      'description': description.text,
                      'seller_id': app.sellerId,
                      if (categoryId != null && categoryId!.isNotEmpty) 'category_id': categoryId,
                      'seller_section_id': sectionId ?? '',
                      'tax_id': taxId ?? '',
                      'type': 'packet',
                      'is_unlimited_stock': unlimited ? 1 : 0,
                      'tax_included_in_price': taxIncluded ? 1 : 0,
                      'return_status': returnable ? 1 : 0,
                      'return_days': returnDays.text,
                      'manufacturer': manufacturer.text,
                      'made_in': madeIn.text,
                      'is_approved': 1,
                      'packet_measurement[]': measurement.text.isEmpty ? '1' : measurement.text,
                      'packet_price[]': price.text,
                      'packet_stock[]': unlimited ? '0' : stock.text,
                      'packet_stock_unit_id[]': unitId ?? '1',
                      'discounted_price[]': discounted.text.isEmpty ? '0' : discounted.text,
                      'packet_status[]': '1',
                      if (widget.id != null) 'id': widget.id,
                    };
                    if (imagePath != null) {
                      map['image'] = await MultipartFile.fromFile(imagePath!, filename: 'product.jpg');
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
        ],
      ),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await app.api.withdrawals();
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
      loading = false;
      error = result.ok ? null : result.failMessage;
    });
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
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات السحب')),
      floatingActionButton: app.canWrite
          ? FloatingActionButton(onPressed: _add, child: const Icon(Icons.add))
          : null,
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        error: error,
        isEmpty: items.isEmpty,
        emptyText: 'لا توجد طلبات سحب',
        child: ListView(
          children: items
              .map((item) => ListTile(
                    title: Text(J.str(item['amount'])),
                    subtitle: Text(J.str(item['status'] ?? item['message'] ?? item['created_at'])),
                  ))
              .toList(),
        ),
      ),
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
                if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, color: AppColors.textSecondary),
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
                    child: const Icon(Icons.storefront, color: AppColors.orange, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.storeName, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(J.str(app.user?['email'] ?? app.seller['mobile']), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader('إعدادات المتجر'),
            _sectionTile(context, icon: Icons.badge_outlined, title: 'ملف المتجر', path: '/profile'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.category_outlined, title: 'تصنيفاتي', path: '/categories'),
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
            const SizedBox(height: 20),
            const SectionHeader('الدعم'),
            _sectionTile(context, icon: Icons.notifications_outlined, title: 'إشعارات الطلبات', path: '/mail'),
            const SizedBox(height: 8),
            _sectionTile(context, icon: Icons.privacy_tip_outlined, title: 'السياسات', path: '/privacy'),
            if (app.supportPhone.isNotEmpty) ...[
              const SizedBox(height: 8),
              BrandedCard(
                onTap: () => openTel(app.supportPhone),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.call_outlined, color: AppColors.navy, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('اتصال بالدعم', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(app.supportPhone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left, color: AppColors.textSecondary),
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
              child: const Row(
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
                final ok = await confirmAction(
                  context,
                  title: 'حذف الحساب',
                  body: 'سيتم حذف المتجر نهائياً ولا يمكن التراجع. هل أنت متأكد؟',
                  confirmLabel: 'حذف',
                );
                if (!ok || !context.mounted) return;
                final result = await app.api.deleteAccount();
                if (!context.mounted) return;
                toast(context, result.ok ? 'تم حذف الحساب' : result.message);
                if (result.ok) {
                  await app.logout();
                  if (context.mounted) context.go('/login');
                }
              },
              child: const Row(
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
