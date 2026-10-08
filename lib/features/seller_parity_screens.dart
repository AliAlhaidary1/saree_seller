import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/json_util.dart';
import '../core/theme.dart';
import '../widgets/branded_skeleton.dart';
import '../widgets/common.dart';

// ───────── Campaigns (seller/campaigns) ─────────
// ───────── Campaigns (seller/campaigns) — مطابق الباكند ─────────
// الحالات: draft/scheduled/active/paused/expired/archived
// الأهداف: acquisition/retention/reactivation/sales/clearance/seasonal/awareness/store_launch/loyalty/free_delivery
const _campaignStatuses = [
  'draft',
  'scheduled',
  'active',
  'paused',
  'expired',
  'archived'
];
const _campaignGoals = [
  'acquisition',
  'retention',
  'reactivation',
  'sales',
  'clearance',
  'seasonal',
  'awareness',
  'store_launch',
  'loyalty',
  'free_delivery'
];
const _attachTypes = [
  'flash_sale',
  'category_discount',
  'bxgy_offer',
  'promo_code',
  'delivery_offer',
  'offer',
  'slider'
];

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});
  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> meta = {};
  bool loading = true;
  String? error;
  String statusFilter = '';

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    final m = await app.api.campaignsMeta();
    final r = await app.api.campaigns(status: statusFilter);
    if (!mounted) return;
    setState(() {
      meta = m.dataMap;
      items = r.dataMaps.isNotEmpty ? r.dataMaps : r.list('campaigns');
      loading = false;
      error = r.ok ? null : r.failMessage;
    });
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    final statuses = J.maps(meta['statuses']).isNotEmpty
        ? J.maps(meta['statuses'])
            .map((e) => J.str(e['value'] ?? e))
            .where((s) => s.isNotEmpty)
            .toList()
        : _campaignStatuses;
    return Scaffold(
      appBar: AppBar(title: const Text('الحملات التسويقية')),
      floatingActionButton: app.canWrite ? FloatingActionButton(onPressed: () async {
        final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CampaignFormScreen()));
        if (ok == true) _load();
      }, child: const Icon(Icons.add)) : null,
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('الكل'),
                  selected: statusFilter.isEmpty,
                  onSelected: (_) {
                    setState(() => statusFilter = '');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                ...statuses.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: statusFilter == s,
                        onSelected: (_) {
                          setState(() => statusFilter = s);
                          _load();
                        },
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: FetchBody(
              loading: loading, onRefresh: _load, error: error, isEmpty: items.isEmpty,
              emptyText: 'لا توجد حملات',
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (meta.isNotEmpty) BrandedCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('البيانات الوصفية', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('الأهداف: ${(J.maps(meta['goals']).isNotEmpty ? J.maps(meta['goals']).map((e) => J.str(e['value'] ?? e)).join(', ') : _campaignGoals.join(', '))}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ])),
                  const SizedBox(height: 8),
            ...items.map((c) => BrandedCard(
              onTap: () async {
                final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CampaignDetailsScreen(item: c)));
                if (ok == true && mounted) _load();
              },
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(J.str(c['title'] ?? c['name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${J.str(c['status'])} • ${J.str(c['created_at'])}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                if (app.canWrite) PopupMenuButton<String>(onSelected: (v) async {
                  if (v == 'delete') {
                    if (!await confirmWrite(context)) return;
                    final ok = await confirmAction(context, title: 'حذف الحملة', body: 'هل أنت متأكد؟', confirmLabel: 'حذف');
                    if (!ok || !context.mounted) return;
                    final res = await app.api.deleteCampaign(c['id']);
                    if (!context.mounted) return;
                    toast(context, res.ok ? 'تم الحذف' : res.message);
                    if (res.ok) _load();
                  } else if (v == 'duplicate') {
                    final res = await app.api.duplicateCampaign(c['id']);
                    if (!context.mounted) return;
                    toast(context, res.ok ? 'تم النسخ' : res.message);
                    if (res.ok) _load();
                  } else if (v == 'analytics') {
                    if (!context.mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CampaignDetailsScreen(item: c, showAnalytics: true)));
                  }
                }, itemBuilder: (_) => const [PopupMenuItem(value: 'analytics', child: Text('التحليل')), PopupMenuItem(value: 'duplicate', child: Text('نسخ')), PopupMenuItem(value: 'delete', child: Text('حذف'))]),
              ]),
            )),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }
}

class CampaignFormScreen extends StatefulWidget {
  const CampaignFormScreen({super.key, this.item});
  final Map<String, dynamic>? item;
  @override
  State<CampaignFormScreen> createState() => _CampaignFormScreenState();
}

class _CampaignFormScreenState extends State<CampaignFormScreen> {
  final name = TextEditingController();
  final desc = TextEditingController();
  final customerDesc = TextEditingController();
  final priority = TextEditingController(text: '0');
  String goal = 'sales';
  String status = 'draft';
  String audienceType = 'all';
  String startAt = '';
  String endAt = '';
  bool isPermanent = false;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      name.text = J.str(it['name'] ?? it['title']);
      desc.text = J.str(it['internal_description'] ?? it['description']);
      customerDesc.text = J.str(it['customer_description']);
      priority.text = J.str(it['priority'], '0');
      final g = J.str(it['goal'], 'sales');
      goal = _campaignGoals.contains(g) ? g : 'sales';
      final s = J.str(it['status'], 'draft');
      status = _campaignStatuses.contains(s) ? s : 'draft';
      audienceType = J.str(it['audience_type'], 'all');
      startAt = J.str(it['start_at']);
      endAt = J.str(it['end_at']);
      isPermanent = J.flag(it['is_permanent']);
    }
  }

  @override
  void dispose() {
    name.dispose();
    desc.dispose();
    customerDesc.dispose();
    priority.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'حملة جديدة' : 'تعديل حملة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        labeledField(name, 'الاسم *'),
        labeledField(desc, 'الوصف الداخلي', maxLines: 3),
        labeledField(customerDesc, 'وصف العميل (يظهر في الواجهة)', maxLines: 2),
        labeledField(priority, 'الأولوية', type: TextInputType.number),
        SwitchListTile(title: const Text('دائمة (بدون تواريخ)'), value: isPermanent, onChanged: (v) => setState(() => isPermanent = v)),
        if (!isPermanent) ...[
          ListTile(
            title: Text(startAt.isEmpty ? 'تبدأ في (اختياري)' : startAt),
            trailing: const Icon(Icons.event),
            onTap: () async {
              final v = await pickDate(context, withTime: true);
              if (v != null) setState(() => startAt = v);
            },
          ),
          ListTile(
            title: Text(endAt.isEmpty ? 'تنتهي في (اختياري)' : endAt),
            trailing: const Icon(Icons.event),
            onTap: () async {
              final v = await pickDate(context, withTime: true);
              if (v != null) setState(() => endAt = v);
            },
          ),
        ],
        DropdownButtonFormField<String>(
            initialValue:
                _campaignGoals.contains(goal) ? goal : 'sales',
            items: _campaignGoals
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => goal = v ?? 'sales'),
            decoration: const InputDecoration(
                labelText: 'الهدف *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
            initialValue: _campaignStatuses.contains(status)
                ? status
                : 'draft',
            items: _campaignStatuses
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => status = v ?? 'draft'),
            decoration: const InputDecoration(
                labelText: 'الحالة', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(
          controller: TextEditingController(text: audienceType),
          readOnly: true,
          onTap: () async {
            final v = await showDialog<String>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('نوع الجمهور'),
                children: ['all', 'new', 'returning', 'vip', 'city']
                    .map((a) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, a),
                          child: Text(a),
                        ))
                    .toList(),
              ),
            );
            if (v != null) setState(() => audienceType = v);
          },
          decoration: const InputDecoration(labelText: 'الجمهور (اختياري)', border: OutlineInputBorder(), suffixIcon: Icon(Icons.group_outlined)),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy ? null : () async {
          if (!await confirmWrite(context)) return;
          if (name.text.trim().isEmpty) { toast(context, 'أدخل الاسم'); return; }
          setState(() => busy = true);
          final body = {
            'name': name.text.trim(),
            'internal_description': desc.text.trim(),
            if (customerDesc.text.trim().isNotEmpty) 'customer_description': customerDesc.text.trim(),
            'goal': goal,
            'status': status,
            if (audienceType.isNotEmpty && audienceType != 'all') 'audience_type': audienceType,
            if (!isPermanent && startAt.isNotEmpty) 'start_at': startAt,
            if (!isPermanent && endAt.isNotEmpty) 'end_at': endAt,
            if (isPermanent) 'is_permanent': 1,
            'priority': int.tryParse(priority.text.trim()) ?? 0,
            if (!isNew) 'id': widget.item!['id'],
          };
          final res = isNew ? await app.api.saveCampaign(body) : await app.api.updateCampaign(body);
          if (!mounted) return;
          setState(() => busy = false);
          toast(context, res.ok ? 'تم الحفظ' : res.message);
          if (res.ok) Navigator.pop(context, true);
        }, child: busy ? const BusySpinner() : const Text('حفظ')),
      ]),
    );
  }
}

class CampaignDetailsScreen extends StatefulWidget {
  const CampaignDetailsScreen({super.key, required this.item, this.showAnalytics = false});
  final Map<String, dynamic> item;
  final bool showAnalytics;
  @override
  State<CampaignDetailsScreen> createState() => _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState extends State<CampaignDetailsScreen> {
  Map<String, dynamic> detail = {};
  Map<String, dynamic> analytics = {};
  List<Map<String, dynamic>> attached = [];
  bool loading = true;
  String attachType = 'promo_code';
  final attachId = TextEditingController();
  bool attachBusy = false;
  @override
  void initState() { super.initState(); detail = widget.item; _load(); }
  @override
  void dispose() {
    attachId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final show = await app.api.campaignShow(widget.item['id']);
    final an = await app.api.campaignAnalytics(widget.item['id']);
    if (!mounted) return;
    setState(() {
      if (show.ok) {
        detail = show.dataMap.isNotEmpty ? show.dataMap : detail;
        attached = J.maps(detail['attachments']);
        if (attached.isEmpty) {
          // بعض العروض تُرجع products/flash_sales كمرفقات مباشرة
          attached = J.maps(detail['products'])
              .map((p) => {'type': 'promo_code', ...p})
              .toList();
        }
      }
      analytics = an.dataMap;
      loading = false;
    });
  }

  bool get _isActive => J.str(detail['status']) == 'active';

  Future<void> _toggleStatus() async {
    if (!await confirmWrite(context)) return;
    final next = _isActive ? 'paused' : 'active';
    final res =
        await app.api.setCampaignStatus(id: detail['id'], status: next);
    if (!mounted) return;
    toast(context, res.ok ? 'تم التحديث إلى $next' : res.message);
    if (res.ok) _load();
  }

  Future<void> _attach() async {
    if (attachBusy) return;
    final id = int.tryParse(attachId.text.trim());
    if (id == null || id <= 0) {
      toast(context, 'أدخل معرّفاً صحيحاً');
      return;
    }
    if (!await confirmWrite(context)) return;
    setState(() => attachBusy = true);
    final res = await app.api.attachCampaign(
      campaignId: detail['id'],
      type: attachType,
      id: id,
    );
    if (!mounted) return;
    setState(() => attachBusy = false);
    toast(context, res.ok ? 'تم الإرفاق' : res.message);
    if (res.ok) {
      attachId.clear();
      _load();
    }
  }

  Future<void> _detach(Map<String, dynamic> a) async {
    if (!await confirmWrite(context)) return;
    final ok = await confirmAction(context,
        title: 'فصل المرفق', body: 'فصل هذا العنصر من الحملة؟');
    if (!ok || !mounted) return;
    final res = await app.api.detachCampaign(
      campaignId: detail['id'],
      type: J.str(a['type'], attachType),
      id: a['id'],
    );
    if (!mounted) return;
    toast(context, res.ok ? 'تم الفصل' : res.message);
    if (res.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(J.str(detail['title'] ?? detail['name']))),
      body: loading
          ? const BrandedSkeletonList(count: 3)
          : ListView(padding: const EdgeInsets.all(16), children: [
        BrandedCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(J.str(detail['title'] ?? detail['name']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(J.str(detail['internal_description'] ?? detail['description']), style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('الحالة: ${detail['status']} • الهدف: ${J.str(detail['goal'])}', style: const TextStyle(fontSize: 13)),
        ])),
        const SizedBox(height: 12),
        if (app.canWrite) Wrap(spacing: 8, children: [
          FilledButton.icon(onPressed: _toggleStatus, icon: const Icon(Icons.toggle_on), label: Text(_isActive ? 'إيقاف مؤقت' : 'تفعيل')),
          OutlinedButton.icon(onPressed: () async { final res = await app.api.duplicateCampaign(detail['id']); if (!mounted) return; toast(context, res.ok ? 'تم النسخ' : res.message); }, icon: const Icon(Icons.copy), label: const Text('نسخ')),
          OutlinedButton.icon(onPressed: () async { final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CampaignFormScreen(item: detail))); if (ok == true && mounted) _load(); }, icon: const Icon(Icons.edit), label: const Text('تعديل')),
        ]),
        const SizedBox(height: 16),
        const SectionHeader('التحليل'),
        if (analytics.isEmpty) Text('لا يوجد تحليل', style: TextStyle(color: AppColors.textSecondary))
        else BrandedCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: analytics.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${e.key}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)), Text('${e.value}', style: TextStyle(fontWeight: FontWeight.w600))]))).toList())),
        const SizedBox(height: 16),
        const SectionHeader('المرفقات'),
        if (attached.isEmpty)
          Text('لا توجد مرفقات', style: TextStyle(color: AppColors.textSecondary)),
        ...attached.map((a) => ListTile(
              title: Text(J.str(a['name'] ?? a['title'] ?? '#${a['id']}')),
              subtitle: Text(J.str(a['type'])),
              trailing: app.canWrite
                  ? IconButton(
                      icon: const Icon(Icons.link_off),
                      onPressed: () => _detach(a),
                    )
                  : null,
            )),
        if (app.canWrite) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: attachType,
                  items: _attachTypes
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => attachType = v ?? 'promo_code'),
                  decoration: const InputDecoration(
                    labelText: 'النوع',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: attachId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المعرّف',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: attachBusy ? null : _attach,
                child: attachBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إرفاق'),
              ),
            ],
          ),
        ],
      ]),
    );
  }
}

// ───────── Storefront (seller/storefront) ─────────
class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({super.key});
  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  List<Map<String, dynamic>> templates = [];
  Map<String, dynamic> me = {};
  bool loading = true;
  String? error;

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    final t = await app.api.storefrontTemplates();
    final m = await app.api.myStorefront();
    if (!mounted) return;
    setState(() {
      templates = t.dataMaps.isNotEmpty ? t.dataMaps : t.list('templates');
      me = m.dataMap.isNotEmpty ? m.dataMap : J.map(m.raw);
      loading = false;
      error = t.ok && m.ok ? null : (t.failMessage.isNotEmpty ? t.failMessage : m.failMessage);
    });
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    final storefront = J.map(me['storefront']);
    final settings = J.map(me['settings']);
    final urls = J.map(me['urls']);
    final templatesAllowed = me['templates_allowed'] == true;
    final published = J.i(storefront['is_published'], 0) == 1;
    return Scaffold(
      appBar: AppBar(title: const Text('واجهة المتجر')),
      body: FetchBody(
        loading: loading, onRefresh: _load, error: error, isEmpty: false,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          BrandedCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('متجري الحالي', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('الرابط: ${J.str(urls['platform_url'] ?? me['slug'] ?? me['store_url'])}', style: const TextStyle(fontSize: 13)),
            if (J.str(urls['subdomain_url']).isNotEmpty)
              Text('النطاق الفرعي: ${J.str(urls['subdomain_url'])}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text('القالب: ${J.str(me['template'] is Map ? me['template']['name'] : storefront['template_id'] ?? me['template_id'])}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text('النشر: ${published ? 'منشور' : 'غير منشور'} • النوع: ${J.str(me['link_type'] ?? storefront['link_type'], 'platform')}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (app.canWrite) Wrap(spacing: 8, children: [
              FilledButton.icon(onPressed: () async {
                final r = await app.api.publishStorefront(isPublished: !published);
                if (!mounted) return;
                toast(context, r.ok ? (published ? 'تم إلغاء النشر' : 'تم النشر') : r.message);
                if (r.ok) _load();
              }, icon: const Icon(Icons.publish), label: Text(published ? 'إلغاء النشر' : 'نشر')),
              OutlinedButton.icon(onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => AppearanceEditor(initial: settings, templatesAllowed: templatesAllowed)));
                if (mounted) _load();
              }, icon: const Icon(Icons.palette_outlined), label: const Text('تحرير المظهر')),
            ]),
          ])),
          const SizedBox(height: 16),
          const SectionHeader('القوالب المتاحة'),
          if (templates.isEmpty) Text('لا توجد قوالب', style: TextStyle(color: AppColors.textSecondary))
          else ...templates.map((tpl) => BrandedCard(
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(J.str(tpl['name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(J.str(tpl['description']), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              if (app.canWrite) FilledButton(onPressed: () async {
                if (!await confirmWrite(context)) return;
                final ok = await confirmAction(context, title: 'تطبيق القالب', body: 'تطبيق قالب ${J.str(tpl['name'])}؟');
                if (!ok || !context.mounted) return;
                final r = await app.api.applyStorefrontTemplate(tpl['id']);
                if (!context.mounted) return;
                toast(context, r.ok ? 'تم التطبيق' : r.message);
                if (r.ok) _load();
              }, child: const Text('تطبيق')),
            ]),
          )),
          const SizedBox(height: 16),
          const SectionHeader('الدومين المخصص'),
          // الباكند: saveCustomDomain إداري فقط (storefront_link_admin_only).
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الدومين المخصص من الإدارة فقط',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      if (J.str(me['custom_domain']).isNotEmpty)
                        Text(J.str(me['custom_domain']),
                            style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('المظهر والروابط'),
          if (settings.isNotEmpty)
            BrandedCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اللون: ${J.str(settings['primary_color'])} • الأعمدة: ${J.str(settings['product_columns'])} • الهبوط: ${J.str(settings['default_landing'])}', style: const TextStyle(fontSize: 13)),
              if (J.str(settings['announcement_text']).isNotEmpty)
                Text('إعلان: ${J.str(settings['announcement_text'])}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              if (J.str(settings['hero_title']).isNotEmpty)
                Text('العنوان: ${J.str(settings['hero_title'])}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ])),
          if (app.canWrite) Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AppearanceEditor(initial: settings, templatesAllowed: templatesAllowed)));
              if (mounted) _load();
            }, icon: const Icon(Icons.palette_outlined), label: const Text('تحرير المظهر الكامل')),
            // الباكند: saveLinkSettings إداري فقط — زر معطّل مع توضيح.
          ]),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text('إعدادات الروابط من الإدارة فقط',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BrandedCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('صفحة مخصصة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // الباكند: saveMyPage معطّل (template_editing_disabled).
            const Text('تحرير الصفحات معطّل من الإدارة حالياً.',
                style: TextStyle(fontSize: 13)),
          ])),
        ]),
      ),
    );
  }
}

// ───────── محرر المظهر (مطابق appearanceSettingsSchema) ─────────
class AppearanceEditor extends StatefulWidget {
  const AppearanceEditor({super.key, required this.initial, this.templatesAllowed = true});
  final Map<String, dynamic> initial;
  final bool templatesAllowed;
  @override
  State<AppearanceEditor> createState() => _AppearanceEditorState();
}

class _AppearanceEditorState extends State<AppearanceEditor> {
  final primary = TextEditingController();
  final accent = TextEditingController();
  final heroTitle = TextEditingController();
  final heroSubtitle = TextEditingController();
  final announcement = TextEditingController();
  String bgMode = 'default';
  String landing = 'home';
  int columns = 2;
  bool showBanner = true;
  bool showCategories = true;
  bool showAnnouncement = true;
  bool showFooter = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    primary.text = J.str(s['primary_color'], '#0A2540');
    accent.text = J.str(s['accent_color'], '#FF6B00');
    heroTitle.text = J.str(s['hero_title']);
    heroSubtitle.text = J.str(s['hero_subtitle']);
    announcement.text = J.str(s['announcement_text']);
    bgMode = J.str(s['bg_mode'], 'default');
    landing = J.str(s['default_landing'], 'home');
    columns = J.i(s['product_columns'], 2);
    showBanner = J.flag(s['show_banner'] ?? 1);
    showCategories = J.flag(s['show_categories'] ?? 1);
    showAnnouncement = J.flag(s['show_announcement'] ?? 1);
    showFooter = J.flag(s['show_footer'] ?? 1);
  }

  @override
  void dispose() {
    primary.dispose();
    accent.dispose();
    heroTitle.dispose();
    heroSubtitle.dispose();
    announcement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحرير المظهر')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.templatesAllowed)
            BrandedCard(child: Text('المظهر الكامل متاح مع نطاق فرعي/خاص فقط — داخل المنصة يظهر تصميم السوق.', style: TextStyle(fontSize: 13))),
          labeledField(primary, 'اللون الأساسي (hex)'),
          labeledField(accent, 'لون التمييز (hex)'),
          labeledField(heroTitle, 'عنوان الواجهة'),
          labeledField(heroSubtitle, 'العنوان الفرعي'),
          labeledField(announcement, 'نص الإعلان'),
          DropdownButtonFormField<String>(
            initialValue: ['default', 'light', 'soft', 'dark'].contains(bgMode) ? bgMode : 'default',
            items: const [DropdownMenuItem(value: 'default', child: Text('افتراضي')), DropdownMenuItem(value: 'light', child: Text('فاتح')), DropdownMenuItem(value: 'soft', child: Text('ناعم')), DropdownMenuItem(value: 'dark', child: Text('داكن'))],
            onChanged: (v) => setState(() => bgMode = v ?? 'default'),
            decoration: const InputDecoration(labelText: 'الخلفية', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: ['home', 'products'].contains(landing) ? landing : 'home',
            items: const [DropdownMenuItem(value: 'home', child: Text('الرئيسية')), DropdownMenuItem(value: 'products', child: Text('المنتجات'))],
            onChanged: (v) => setState(() => landing = v ?? 'home'),
            decoration: const InputDecoration(labelText: 'الصفحة الافتراضية', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: [2, 3, 4].contains(columns) ? columns : 2,
            items: const [DropdownMenuItem(value: 2, child: Text('عمودان')), DropdownMenuItem(value: 3, child: Text('3 أعمدة')), DropdownMenuItem(value: 4, child: Text('4 أعمدة'))],
            onChanged: (v) => setState(() => columns = v ?? 2),
            decoration: const InputDecoration(labelText: 'أعمدة المنتجات', border: OutlineInputBorder()),
          ),
          SwitchListTile(title: const Text('البانر'), value: showBanner, onChanged: (v) => setState(() => showBanner = v)),
          SwitchListTile(title: const Text('التصنيفات'), value: showCategories, onChanged: (v) => setState(() => showCategories = v)),
          SwitchListTile(title: const Text('شريط الإعلان'), value: showAnnouncement, onChanged: (v) => setState(() => showAnnouncement = v)),
          SwitchListTile(title: const Text('التذييل'), value: showFooter, onChanged: (v) => setState(() => showFooter = v)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : () async {
              if (!await confirmWrite(context)) return;
              setState(() => busy = true);
              final r = await app.api.saveStorefrontAppearance({
                'primary_color': primary.text.trim(),
                'accent_color': accent.text.trim(),
                'bg_mode': bgMode,
                'default_landing': landing,
                'product_columns': columns,
                'hero_title': heroTitle.text.trim(),
                'hero_subtitle': heroSubtitle.text.trim(),
                'announcement_text': announcement.text.trim(),
                'show_banner': showBanner ? 1 : 0,
                'show_categories': showCategories ? 1 : 0,
                'show_announcement': showAnnouncement ? 1 : 0,
                'show_footer': showFooter ? 1 : 0,
              });
              if (!mounted) return;
              setState(() => busy = false);
              toast(context, r.ok ? 'تم حفظ المظهر' : r.message);
              if (r.ok && mounted) Navigator.pop(context, true);
            },
            child: busy ? const BusySpinner() : const Text('حفظ المظهر'),
          ),
        ],
      ),
    );
  }
}

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
    final list =
        r.dataMaps.isNotEmpty ? r.dataMaps : r.list('seller_orders');
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
  void initState() { super.initState(); _load(); }

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
                DropdownButton<String>(
                  value: sort,
                  items: sorts
                      .map((s) => DropdownMenuItem(value: s, child: Text(sortLabels[s]!)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => sort = v);
                    _load();
                  },
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
                    value: deliveryStatus.isEmpty ? null : deliveryStatus,
                    hint: const Text('حالة التوصيل'),
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('الكل')),
                      ...deliveryStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))),
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
                  const labels = {'': 'كل الفترات', 'today': 'اليوم', 'yesterday': 'أمس', 'week': 'أسبوع', 'month': 'شهر'};
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
                    avatar: Icon(Icons.date_range,
                        size: 16, color: startDate.isNotEmpty ? AppColors.orange : null),
                    label: Text(startDate.isNotEmpty ? '$startDate → $endDate' : 'فترة مخصصة'),
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
              emptyText: 'لا توجد طلبات $filter',
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
                                    'عرض المزيد (${total - items.length})'),
                              ),
                      ),
                    );
                  }
                  final o = items[i];
                  final fulfillment =
                      J.str(o['fulfillment_status'] ?? o['status']);
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
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: fc.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                fulfillment.isNotEmpty ? fulfillment : '—',
                                style: TextStyle(
                                    color: fc,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
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
                          'الأصناف: ${itemsList.length} | الإجمالي: ${J.str(o['final_total'])}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          'الدفع: ${J.str(o['payment_method'])} (${J.str(o['payment_status'])}) | المتوقع نقداً: ${J.str(o['cod_expected_amount'])}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        Text(
                          'التوصيل: ${J.str(o['delivery_status'])}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        if (courier.isNotEmpty)
                          Text(
                            'مهمة المندوب #${courier['id']}: ${J.str(courier['status'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (itemsList.isNotEmpty) ...[
                          const Divider(),
                          ...itemsList.map((it) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${J.str(it['product_name'])} x${it['quantity'] ?? 1} — ${J.str(it['sub_total'])}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      J.str(it['active_status']),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              )),
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
  State<SellerOrderNewDetailsScreen> createState() => _SellerOrderNewDetailsScreenState();
}

class _SellerOrderNewDetailsScreenState extends State<SellerOrderNewDetailsScreen> {
  Map<String, dynamic> order = {};
  bool loading = true;
  String? error;
  bool busy = false;
  Future<void> _load() async {
    final r = await app.api.sellerOrderById(widget.id);
    if (!mounted) return;
    setState(() { order = r.dataMap.isNotEmpty ? r.dataMap : (r.dataMaps.isNotEmpty ? r.dataMaps.first : {}); loading = false; error = r.ok || order.isNotEmpty ? null : r.failMessage; });
  }
  @override
  void initState() { super.initState(); _load(); }

  List<String> get _allowed {
    final v = order['allowed_next_fulfillment'];
    if (v is List) return v.map((e) => '$e').toList();
    return [];
  }

  List<Map<String, dynamic>> get _activeItems =>
      J.maps(order['items'])
          .where((it) => J.str(it['active_status']) != 'cancelled')
          .toList();

  Future<void> _fulfill(String status) async {
    if (busy) return;
    if (!await confirmWrite(context)) return;
    setState(() => busy = true);
    final r = await app.api.sellerOrderFulfillment(
        id: widget.id, status: status);
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, r.ok ? 'تم التحديث إلى $status' : r.message);
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
                .map((it) => ListTile(
                      title: Text(
                          '${J.str(it['product_name'])} x${it['quantity'] ?? 1}'),
                      subtitle: Text(J.str(it['active_status'])),
                      onTap: () => Navigator.pop(ctx, it),
                    ))
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
        title: const Text('سبب الرفض (نفد المخزون / تالف)'),
        content: TextField(
          controller: reasonCtrl,
          decoration:
              const InputDecoration(hintText: 'السبب (اختياري)'),
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
          decoration:
              const InputDecoration(hintText: 'سبب الإلغاء (اختياري)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    final r = await app.api.sellerOrderCancel(
      id: widget.id,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, r.ok ? 'تم الإلغاء' : r.message);
    if (r.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(appBar: AppBar(title: Text('طلب ${widget.id}')), body: const BrandedSkeletonList(count: 3));
    if (order.isEmpty) return Scaffold(appBar: AppBar(title: Text('طلب ${widget.id}')), body: FetchBody(loading: false, onRefresh: _load, error: error ?? 'تعذر التحميل', isEmpty: true, child: const SizedBox.shrink()));
    final fulfillment = J.str(order['fulfillment_status']);
    final courier = J.map(order['delivery_assignment']);
    final cancelled = fulfillment == 'cancelled';
    return Scaffold(
      appBar: AppBar(
          title: Text(
              'طلب #${J.str(order['public_id']).isNotEmpty ? order['public_id'] : widget.id}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        BrandedCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الحالة: $fulfillment', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('التوصيل: ${J.str(order['delivery_status'])}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(J.str(order['created_at']), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (app.canViewCustomerDetail) Text(
              'العميل: ${J.str(order['customer_name'])} (${J.str(order['customer_mobile'])})',
              style: const TextStyle(fontSize: 14)),
          Text(
              'الدفع: ${J.str(order['payment_method'])} (${J.str(order['payment_status'])}) | المتوقع نقداً: ${J.str(order['cod_expected_amount'])}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text('الإجمالي: ${J.str(order['final_total'])}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (courier.isNotEmpty)
            Text(
                'مهمة المندوب #${courier['id']}: ${J.str(courier['status'])}',
                style: const TextStyle(fontSize: 13)),
        ])),
        const SizedBox(height: 12),
        if (app.canWrite && !cancelled) Wrap(spacing: 8, runSpacing: 8, children: [
          ..._allowed.map((s) => FilledButton(
                onPressed: busy ? null : () => _fulfill(s),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(s == 'preparing'
                        ? 'بدء التحضير'
                        : s == 'ready'
                            ? 'جاهز للاستلام'
                            : s),
              )),
          if (_activeItems.isNotEmpty)
            OutlinedButton(
              onPressed: busy ? null : _rejectItem,
              child: const Text('رفض صنف'),
            ),
          OutlinedButton(
              onPressed: busy ? null : _cancel,
              child: Text('إلغاء الطلب',
                  style: TextStyle(color: AppColors.error))),
        ]),
        const SizedBox(height: 12),
        ...J.maps(order['items']).map((it) => BrandedCard(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(
                          '${J.str(it['product_name'])}${J.str(it['variant_name']).isNotEmpty ? ' — ${it['variant_name']}' : ''}')),
                  Text('x${it['quantity'] ?? 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(
                    child: Text(
                      '${J.str(it['sub_total'])} | ${J.str(it['active_status'])}${J.str(it['return_status']).isNotEmpty && J.str(it['return_status']) != 'none' ? ' / إرجاع: ${it['return_status']}' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ]),
              ],
            ))),
      ]),
    );
  }
}

// ───────── Accounting exports helpers ─────────
class AccountingExportsCard extends StatelessWidget {
  const AccountingExportsCard({super.key});
  @override
  Widget build(BuildContext context) {
    return BrandedCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('التصدير للخلفية مطابقة', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(onPressed: () async {
            final r = await app.api.accountingExportExcel();
            if (!context.mounted) return; toast(context, r.ok ? 'تم تصدير الإكسل' : r.message);
          }, icon: const Icon(Icons.table_chart), label: const Text('تصدير إكسل')),
          OutlinedButton.icon(onPressed: () async {
            final r = await app.api.accountingExportInvoices();
            if (!context.mounted) return; toast(context, r.ok ? 'تم تصدير الفواتير' : r.message);
          }, icon: const Icon(Icons.receipt_long), label: const Text('تصدير الفواتير')),
        ]),
      ]),
    );
  }
}

// ───────── Withdrawals ext + products advanced helpers ─────────
class ProductAdvancedActions extends StatelessWidget {
  const ProductAdvancedActions({super.key, required this.onRefresh});
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    return BrandedCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('إجراءات متقدمة للمنتجات (مطابقة للخلفية)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: app.canWrite ? () async {
            if (!await confirmWrite(context)) return;
            final r = await app.api.activeProducts();
            if (!context.mounted) return; toast(context, r.ok ? 'تم جلب النشطة (${r.dataMaps.length})' : r.message);
          } : null, icon: const Icon(Icons.verified_outlined), label: const Text('النشطة')),
          OutlinedButton.icon(onPressed: () async {
            final r = await app.api.productsOffers();
            if (!context.mounted) return; toast(context, r.ok ? 'العروض (${r.dataMaps.length})' : r.message);
          }, icon: const Icon(Icons.local_offer_outlined), label: const Text('العروض')),
          OutlinedButton.icon(onPressed: () async {
            final r = await app.api.productTags('test');
            if (!context.mounted) return; toast(context, r.ok ? 'الوسوم (${r.dataMaps.length})' : r.message);
          }, icon: const Icon(Icons.tag), label: const Text('الوسوم')),
        ]),
      ]),
    );
  }
}