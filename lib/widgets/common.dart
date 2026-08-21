import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_controller.dart';
import '../core/json_util.dart';
import '../core/theme.dart';

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class BusySpinner extends StatelessWidget {
  const BusySpinner({super.key, this.color = Colors.white});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
    );
  }
}

Future<bool> confirmWrite(BuildContext context) async {
  if (app.canWrite) return true;
  toast(context, 'لا يمكن التعديل قبل موافقة الإدارة');
  return false;
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  String confirmLabel = 'تأكيد',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<XFile?> pickStoreImage(
  BuildContext context, {
  required String reason,
}) async {
  final ok = await confirmAction(
    context,
    title: 'اختيار صورة',
    body: reason,
    confirmLabel: 'متابعة',
  );
  if (!ok || !context.mounted) return null;
  return ImagePicker().pickImage(
    source: ImageSource.gallery,
    requestFullMetadata: false,
  );
}

Widget labeledField(
  TextEditingController controller,
  String label, {
  int maxLines = 1,
  TextInputType? type,
  bool obscure = false,
  bool toggleObscure = false,
}) {
  if (toggleObscure) {
    return _ObscureField(controller: controller, label: label);
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class _ObscureField extends StatefulWidget {
  const _ObscureField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  State<_ObscureField> createState() => _ObscureFieldState();
}

class _ObscureFieldState extends State<_ObscureField> {
  bool hidden = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: widget.controller,
        obscureText: hidden,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            onPressed: () => setState(() => hidden = !hidden),
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
    );
  }
}

class Refreshable extends StatelessWidget {
  const Refreshable({super.key, required this.onRefresh, required this.child});
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: constraints.maxHeight, child: child),
        ),
      ),
    );
  }
}

Future<void> copyText(
  BuildContext context,
  String value, [
  String ok = 'تم النسخ',
]) async {
  if (value.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) toast(context, ok);
}

Future<void> openTel(String raw) async {
  final phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (phone.isEmpty) return;
  await launchUrl(Uri.parse('tel:$phone'));
}

Future<void> openSms(String raw) async {
  final phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (phone.isEmpty) return;
  await launchUrl(Uri.parse('sms:$phone'));
}

Future<void> openMail(String raw) async {
  final email = raw.trim();
  if (email.isEmpty) return;
  await launchUrl(Uri.parse('mailto:$email'));
}

Future<FilePickerResult?> pickStoreFiles(
  BuildContext context, {
  required String reason,
  FileType type = FileType.image,
  List<String>? extensions,
  bool multiple = false,
}) async {
  final ok = await confirmAction(
    context,
    title: 'اختيار ملف',
    body: reason,
    confirmLabel: 'متابعة',
  );
  if (!ok || !context.mounted) return null;
  return FilePicker.platform.pickFiles(
    allowMultiple: multiple,
    type: type,
    allowedExtensions: extensions,
  );
}

String? dropdownId(String? id, List<Map<String, dynamic>> items) {
  if (id == null || id.isEmpty) return null;
  return items.any((item) => '${item['id']}' == id) ? id : null;
}

Future<String?> pickDate(
  BuildContext context, {
  DateTime? initial,
  bool withTime = false,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (date == null) return null;
  if (!withTime) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
  );
  final hour = time?.hour ?? 0;
  final minute = time?.minute ?? 0;
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
}

class EmptyBox extends StatelessWidget {
  const EmptyBox(
    this.text, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });
  final String text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class FetchBody extends StatelessWidget {
  const FetchBody({
    super.key,
    required this.loading,
    required this.onRefresh,
    required this.isEmpty,
    required this.child,
    this.error,
    this.emptyText = 'لا توجد بيانات',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final bool loading;
  final Future<void> Function() onRefresh;
  final bool isEmpty;
  final Widget child;
  final String? error;
  final String emptyText;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && error!.isNotEmpty) {
      return Refreshable(
        onRefresh: onRefresh,
        child: EmptyBox(
          error!,
          icon: Icons.wifi_off_outlined,
          actionLabel: 'إعادة المحاولة',
          onAction: () { onRefresh(); },
        ),
      );
    }
    if (isEmpty) {
      return Refreshable(
        onRefresh: onRefresh,
        child: EmptyBox(
          emptyText,
          icon: emptyIcon,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
        ),
      );
    }
    return RefreshIndicator(onRefresh: onRefresh, color: AppColors.orange, child: child);
  }
}

// ─── Brand UI components ────────────────────────────────────────────────────

class KpiMetricCard extends StatelessWidget {
  const KpiMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.navy).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor ?? AppColors.navy, size: 22),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final style = orderBadgeStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.isNotEmpty ? status : style.label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: style.fg),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          if (action != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: AppColors.orange))),
        ],
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.orange,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: AppColors.orange.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.white, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class BrandedCard extends StatelessWidget {
  const BrandedCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    );
    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Material(
        color: AppColors.white,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return Material(
      color: AppColors.white,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class UploadDropZone extends StatelessWidget {
  const UploadDropZone({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.subtitle,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.orange.withValues(alpha: 0.06) : AppColors.greyBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.orange : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                selected ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                size: 40,
                color: selected ? AppColors.orange : AppColors.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.orange : AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 8),
              Text('اسحب وأفلت أو اضغط للاختيار', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }
}

class StageActionButton extends StatelessWidget {
  const StageActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.orange : AppColors.white;
    final fg = active ? AppColors.white : AppColors.navy;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.orange.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppColors.orange : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: enabled ? fg : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: enabled ? fg : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardShortcutCard extends StatelessWidget {
  const DashboardShortcutCard({
    super.key,
    required this.icon,
    required this.title,
    required this.path,
    this.value,
  });

  final IconData icon;
  final String title;
  final String path;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return BrandedCard(
      padding: const EdgeInsets.all(12),
      onTap: () {
        if (path == '/products') {
          GoRouter.of(context).go(path);
        } else {
          GoRouter.of(context).push(path);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.navy, size: 22),
          const Spacer(),
          if (value != null && value!.isNotEmpty)
            Text(value!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

Future<void> showDriverAssignmentSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> drivers,
  required Future<void> Function(Map<String, dynamic> driver) onAssign,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, scroll) {
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.delivery_dining, color: AppColors.navy),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تعيين موصل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('اختر موصلاً لاستلام الطلب', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: drivers.isEmpty
                    ? const Center(child: Text('لا يوجد موصلون متاحون', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: drivers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final d = drivers[i];
                          return BrandedCard(
                            onTap: () async {
                              Navigator.pop(ctx);
                              await onAssign(d);
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.orange.withValues(alpha: 0.12),
                                  child: Text(
                                    J.str(d['name']).isNotEmpty ? J.str(d['name'])[0] : '?',
                                    style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(J.str(d['name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text(
                                        J.str(d['mobile']).isNotEmpty ? J.str(d['mobile']) : 'موصل متاح',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_left, color: AppColors.orange),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      );
    },
  );
}
