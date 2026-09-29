import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import 'customer_email_center_screen.dart';
import 'support_customer_search_screen.dart';
import 'support_operations_screen.dart';
import 'support_screen.dart';
import 'support_trust_center_screen.dart';

enum SupportFeatureKind {
  autoAssignment,
  devicesSessions,
  sensitiveData,
  viewAsUser,
  secureEmail,
  disputes,
  payoutHold,
  securityHold,
  approvals,
  moderation,
  incidents,
  sla,
  supportEmail,
  channels,
  attachments,
  ticketControls,
  dataRequests,
  repeatContact,
  professionalDocs,
}

class SupportFeatureScreen extends StatelessWidget {
  final SupportFeatureKind kind;

  const SupportFeatureScreen({super.key, required this.kind});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  _FeatureConfig get _config {
    switch (kind) {
      case SupportFeatureKind.autoAssignment:
        return _FeatureConfig(
          title: 'التوزيع التلقائي'.tr(),
          icon: Icons.alt_route_rounded,
          description: 'إدارة توزيع التذاكر حسب القسم والسعة والحمل الحالي للموظفين.'.tr(),
          points: ['التوزيع حسب القسم', 'مراعاة سعة الموظف', 'Fallback تلقائي', 'التعيين اليدوي يبقى متاحًا'],
          primary: 'فتح التذاكر والتعيين',
          secondary: 'عمليات الدعم',
        );
      case SupportFeatureKind.devicesSessions:
        return _FeatureConfig(
          title: 'الأجهزة والجلسات'.tr(),
          icon: Icons.devices_other_rounded,
          description: 'ابحث عن العميل ثم راجع الأجهزة والجلسات وأحداث تسجيل الدخول من ملف الدعم.'.tr(),
          points: ['الأجهزة المسجلة', 'الجلسات النشطة', 'آخر IP', 'إنهاء الجلسات حسب الصلاحية'],
          primary: 'اختيار العميل',
          secondary: 'مركز الأمان',
        );
      case SupportFeatureKind.sensitiveData:
        return _FeatureConfig(
          title: 'كشف البيانات الحساسة'.tr(),
          icon: Icons.visibility_outlined,
          description: 'كشف البريد أو الهاتف الكامل بسبب إلزامي مع Audit، بدون كشف كلمات مرور أو OTP.'.tr(),
          points: ['Masked افتراضيًا', 'سبب إلزامي', 'Audit كامل', 'لا أسرار 2FA أو Passkeys'],
          primary: 'اختيار العميل',
          secondary: 'سجل التدقيق',
        );
      case SupportFeatureKind.viewAsUser:
        return _FeatureConfig(
          title: 'View as User',
          icon: Icons.preview_outlined,
          description: 'جلسة مؤقتة للقراءة فقط لرؤية تجربة العميل دون منح موظف الدعم صلاحيات كتابة.'.tr(),
          points: ['Read only', 'مدة محددة', 'سبب إلزامي', 'Audit للجلسة'],
          primary: 'اختيار العميل',
          secondary: 'مركز الثقة',
        );
      case SupportFeatureKind.secureEmail:
        return _FeatureConfig(
          title: 'تغيير البريد الآمن'.tr(),
          icon: Icons.alternate_email_rounded,
          description: 'تغيير البريد عبر Checklist وتنبيه البريد القديم وتدفق «هذا مش أنا».'.tr(),
          points: ['Checklist', 'إخطار البريد القديم', 'حماية الجلسات', 'Security Hold عند الحاجة'],
          primary: 'اختيار العميل',
          secondary: 'Email Center',
        );
      case SupportFeatureKind.disputes:
        return _FeatureConfig(
          title: 'النزاعات'.tr(),
          icon: Icons.gavel_rounded,
          description: 'ربط النزاعات بالتذاكر ومراجعة الحالة المالية والإجراءات المرتبطة.'.tr(),
          points: ['ربط النزاع بالتذكرة', 'مراجعة الحالة', 'توثيق السبب', 'فصل صلاحية Hold/Release'],
          primary: 'فتح مركز الثقة',
          secondary: 'فتح التذاكر',
        );
      case SupportFeatureKind.payoutHold:
        return _FeatureConfig(
          title: 'تجميد المستحقات'.tr(),
          icon: Icons.account_balance_wallet_outlined,
          description: 'تجميد مستحقات نزاع أو فكها فقط عند امتلاك الصلاحية المطلوبة.'.tr(),
          points: ['Hold للمستحقات', 'Release مستقل', 'سبب إلزامي', 'Audit'],
          primary: 'فتح مركز الثقة',
          secondary: 'فتح التذاكر',
        );
      case SupportFeatureKind.securityHold:
        return _FeatureConfig(
          title: 'Security Hold',
          icon: Icons.lock_clock_outlined,
          description: 'مراجعة تعليق الصرف الأمني بعد تغييرات حساسة وفك التعليق بعد التحقق.'.tr(),
          points: ['Hold تلقائي', 'مدة أمان', 'Release بصلاحية', 'تسجيل السبب'],
          primary: 'فتح مركز الثقة',
          secondary: 'اختيار العميل',
        );
      case SupportFeatureKind.approvals:
        return _FeatureConfig(
          title: 'الاعتمادات الحساسة'.tr(),
          icon: Icons.approval_outlined,
          description: 'طابور الإجراءات عالية الخطورة التي تحتاج موافقة ثانية من المشرف.'.tr(),
          points: ['Second approval', 'فصل طالب الإجراء عن المراجع', 'ملاحظات القرار', 'Audit'],
          primary: 'فتح عمليات الدعم',
          secondary: 'اختيار العميل',
        );
      case SupportFeatureKind.moderation:
        return _FeatureConfig(
          title: 'التوصيات الرقابية'.tr(),
          icon: Icons.flag_outlined,
          description: 'رفع توصية تحذير أو قفل للمراجعة بدل تنفيذ عقوبة نهائية مباشرة.'.tr(),
          points: ['Recommendation فقط', 'سبب واضح', 'مراجعة منفصلة', 'لا حظر نهائي آلي'],
          primary: 'اختيار العميل',
          secondary: 'عمليات الدعم',
        );
      case SupportFeatureKind.incidents:
        return _FeatureConfig(
          title: 'الحوادث العامة'.tr(),
          icon: Icons.warning_amber_rounded,
          description: 'إدارة الحوادث العامة وربطها بتذاكر الدعم وإظهار بانر الحالة عند الحاجة.'.tr(),
          points: ['Incident status', 'Severity', 'ربط التذاكر', 'Banner للموقع والتطبيق'],
          primary: 'فتح مركز الثقة والحوادث',
          secondary: 'التذاكر',
        );
      case SupportFeatureKind.sla:
        return _FeatureConfig(
          title: 'SLA والتعطيل'.tr(),
          icon: Icons.schedule_rounded,
          description: 'متابعة أوقات SLA والعطلات وساعات العمل وحالات التأخير.'.tr(),
          points: ['Business hours', 'Holidays', 'Overdue', 'Pause عند waiting_customer'],
          primary: 'فتح عمليات الدعم',
          secondary: 'مركز الثقة',
        );
      case SupportFeatureKind.supportEmail:
        return _FeatureConfig(
          title: 'بريد الدعم'.tr(),
          icon: Icons.outgoing_mail,
          description: 'إرسال بريد دعم مخصص للعميل عبر Queue مع Email Log وقالب RTL.'.tr(),
          points: ['Queue', 'Email Log', 'RTL Templates', 'بدون بيانات حساسة'],
          primary: 'فتح Email Center',
          secondary: 'اختيار العميل',
        );
      case SupportFeatureKind.channels:
        return _FeatureConfig(
          title: 'Email + WhatsApp',
          icon: Icons.hub_outlined,
          description: 'قنوات الدعم الواردة من البريد وWhatsApp وتحويلها إلى تذاكر مع Dedupe.'.tr(),
          points: ['Inbound Email', 'WhatsApp Webhook', 'Dedupe', 'Signature verification'],
          primary: 'فتح Email Center',
          secondary: 'فتح التذاكر',
        );
      case SupportFeatureKind.attachments:
        return _FeatureConfig(
          title: 'فحص المرفقات'.tr(),
          icon: Icons.attach_file_rounded,
          description: 'مراجعة مرفقات التذاكر وحالة الفحص الأمني قبل التنزيل.'.tr(),
          points: ['Attachment scan', 'Signed URLs', 'حالة الفحص', 'منع الملفات غير الآمنة'],
          primary: 'فتح التذاكر',
          secondary: 'عمليات الدعم',
        );
      case SupportFeatureKind.ticketControls:
        return _FeatureConfig(
          title: 'Spam / Merge / Locks',
          icon: Icons.block_rounded,
          description: 'أدوات التحكم المتقدمة بالتذاكر: Spam، دمج، وقفل الرد.'.tr(),
          points: ['Merge', 'Spam/Abuse', 'Reply Lock', 'Block sender عند الحاجة'],
          primary: 'فتح التذاكر',
          secondary: 'مركز الثقة',
        );
      case SupportFeatureKind.dataRequests:
        return _FeatureConfig(
          title: 'تصدير / حذف البيانات'.tr(),
          icon: Icons.privacy_tip_outlined,
          description: 'طلبات تصدير بيانات المستخدم أو حذفها مع فترة سماح ومراجعة.'.tr(),
          points: ['Export', 'Delete request', 'Grace period', 'Review before execution'],
          primary: 'فتح مركز الثقة',
          secondary: 'اختيار العميل',
        );
      case SupportFeatureKind.repeatContact:
        return _FeatureConfig(
          title: 'Repeat Contact',
          icon: Icons.repeat_rounded,
          description: 'مؤشر تكرار تواصل العميل لنفس الفئة لمتابعة جودة الحل من أول مرة.'.tr(),
          points: ['آخر 30 يومًا', 'الحالات المتكررة', 'مؤشر جودة', 'لا قرار آلي ضد العميل'],
          primary: 'فتح مركز الثقة',
          secondary: 'عمليات الدعم',
        );
      case SupportFeatureKind.professionalDocs:
        return _FeatureConfig(
          title: 'الوثائق المهنية'.tr(),
          icon: Icons.workspace_premium_outlined,
          description: 'متابعة انتهاء ترخيص المهندس وعضوية النقابة والتوثيق المهني.'.tr(),
          points: ['License expiry', 'Syndicate expiry', 'تنبيه قبل الانتهاء', 'مراجعة بصلاحية مستقلة'],
          primary: 'فتح مركز الثقة',
          secondary: 'اختيار العميل',
        );
    }
  }

  void _primary(BuildContext context) {
    switch (kind) {
      case SupportFeatureKind.autoAssignment:
      case SupportFeatureKind.attachments:
      case SupportFeatureKind.ticketControls:
        _open(context, const SupportScreen());
        break;
      case SupportFeatureKind.devicesSessions:
      case SupportFeatureKind.sensitiveData:
      case SupportFeatureKind.viewAsUser:
      case SupportFeatureKind.secureEmail:
      case SupportFeatureKind.moderation:
        _open(context, const SupportCustomerSearchScreen());
        break;
      case SupportFeatureKind.approvals:
      case SupportFeatureKind.sla:
        _open(context, const SupportOperationsScreen());
        break;
      case SupportFeatureKind.supportEmail:
      case SupportFeatureKind.channels:
        _open(context, const CustomerEmailCenterScreen());
        break;
      default:
        _open(context, const SupportTrustCenterScreen());
    }
  }

  void _secondary(BuildContext context) {
    switch (kind) {
      case SupportFeatureKind.devicesSessions:
        _open(context, const SupportOperationsScreen(initialSection: 'security'));
        break;
      case SupportFeatureKind.sensitiveData:
        _open(context, const SupportOperationsScreen(initialSection: 'audit'));
        break;
      case SupportFeatureKind.secureEmail:
      case SupportFeatureKind.supportEmail:
        _open(context, const SupportCustomerSearchScreen());
        break;
      case SupportFeatureKind.approvals:
      case SupportFeatureKind.moderation:
      case SupportFeatureKind.repeatContact:
      case SupportFeatureKind.professionalDocs:
      case SupportFeatureKind.securityHold:
        _open(context, const SupportCustomerSearchScreen());
        break;
      case SupportFeatureKind.channels:
      case SupportFeatureKind.incidents:
      case SupportFeatureKind.attachments:
      case SupportFeatureKind.ticketControls:
      case SupportFeatureKind.disputes:
      case SupportFeatureKind.payoutHold:
        _open(context, const SupportScreen());
        break;
      default:
        _open(context, const SupportOperationsScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF061226) : Theme.of(context).scaffoldBackgroundColor),
        appBar: AppBar(
          backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF061226) : Theme.of(context).scaffoldBackgroundColor),
          foregroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
          title: Text(trUi(c.title), style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A1B35) : Theme.of(context).colorScheme.surface),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17385F) : Theme.of(context).colorScheme.surface)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF102A50) : Theme.of(context).colorScheme.surface),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C467B) : const Color(0xFFBAE6FD))),
                        ),
                        child: Icon(c.icon, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          trUi(c.title),
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 19, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(trUi(c.description), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFB6C4DA) : const Color(0xFF334155)), height: 1.7, fontSize: 12.5)),
                  const SizedBox(height: 14),
                  ...c.points.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0C203C) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17355A) : const Color(0xFFE2E8F0))),
                          ),
                          child: Text('✓  ${trUi(p)}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD5E1F2) : const Color(0xFF1E293B)), fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      )),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _primary(context),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(trUi(c.primary)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _secondary(context),
                      child: Text(trUi(c.secondary)),
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

class _FeatureConfig {
  final String title;
  final IconData icon;
  final String description;
  final List<String> points;
  final String primary;
  final String secondary;

  const _FeatureConfig({
    required this.title,
    required this.icon,
    required this.description,
    required this.points,
    required this.primary,
    required this.secondary,
  });
}
