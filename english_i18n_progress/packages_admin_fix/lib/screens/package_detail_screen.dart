import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/localized_text.dart';
import '../providers/auth_provider.dart';
import 'engineer_application_screen.dart';
import 'office_application_screen.dart';
import 'ai_premium_screen.dart';
import 'alwaleed_wallet_screen.dart';

class PackageDetailScreen extends StatelessWidget {
  final Map<String, dynamic> plan;
  const PackageDetailScreen({super.key, required this.plan});

  List<Map<String, dynamic>> get features =>
      (plan['features'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final type = '${plan['type'] ?? ''}';
    final price = plan['price'] ?? plan['monthly_price'] ?? 0;
    final planId = int.tryParse('${plan['id'] ?? ''}');
    final title = '${plan['name'] ?? 'تفاصيل الباقة'.tr()}';
    final muted = dark ? const Color(0xFFB9CBE3) : const Color(0xFF475569);
    final isCurrent = plan['is_current_plan'] == true;
    // Same purchase rules as the website packages page.
    final user = context.watch<AuthProvider>().user;
    final buyerRole = user?.role ?? '';
    final buyerActive = user == null || user.status == 'active';
    final canBuyThisPlan = buyerActive && switch (type) {
      'engineer' => buyerRole == 'engineer',
      'office' => buyerRole == 'office_owner',
      'ai' => buyerRole != 'admin', // the admin already has unlimited AI
      _ => false,
    };
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: Text(trUi(title))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: dark
                    ? const [Color(0xFF172554), Color(0xFF0D1B31)]
                    : const [Color(0xFFE5F0FF), Color(0xFFFFFFFF)]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: dark
                    ? const Color(0xFF334C71) : const Color(0xFFCBDDF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trUi(title), style: TextStyle(color: scheme.onSurface,
                      fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('${plan['description'] ?? ''}',
                      style: TextStyle(color: muted, height: 1.6)),
                  const SizedBox(height: 16),
                  Text('$price ${plan['currency'] ?? 'USD'} / شهر'.tr(),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                          color: dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490))),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const TrText('ماذا تتضمن الباقة؟',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final f in features)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dark
                      ? const Color(0xFF263F5B) : const Color(0xFFD9E4F2)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF047857)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    trUi('${f['label'] ?? f['key'] ?? 'ميزة'.tr()}'
                    '${f['value'] != null ? ' — ${f['value']}' : ''}'
                    '${f['limit'] != null ? ' — الحد ${f['limit']}' : ''}'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  )),
                ]),
              ),
            if (plan['active_coupon'] is Map) ...[
              const SizedBox(height: 8),
              TrText('الكوبون ${(plan['active_coupon'] as Map)['code'] ?? ''} '
                  'يُتحقق منه عند إكمال الدفع.', style: TextStyle(color: muted)),
            ],
            const SizedBox(height: 18),
            if (isCurrent)
              const Card(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: TrText('✓ أنت داخل الخطة بالفعل', textAlign: TextAlign.center)))
            else if (user != null && !buyerActive)
              _notice(context, 'الحساب غير نشط حاليًا؛ راجع حالة الحساب قبل شراء باقة.', const Color(0xFFF59E0B))
            else if (user != null && buyerRole == 'admin' && type == 'ai')
              _notice(context, 'حساب المدير لديه صلاحية AI غير محدودة بحسب إعدادات المنصة الحالية؛ لا يلزم شراء هذه الباقة من محفظتك الشخصية.', const Color(0xFF06B6D4))
            else if (user != null && !canBuyThisPlan)
              _notice(context, type == 'office'
                  ? 'هذه الباقة مخصصة لحساب صاحب مكتب هندسي معتمد. لا يمكن شراؤها لحساب المدير أو لحساب من نوع آخر. لا تتغير صلاحيات حسابك عند عرض الكتالوج.'
                  : 'هذه الباقة مخصصة لحساب مهندس معتمد. لا يمكن شراؤها لحساب المدير أو لحساب من نوع آخر. لا تتغير صلاحيات حسابك عند عرض الكتالوج.',
                  const Color(0xFFF59E0B))
            else ...[
              FilledButton.icon(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const TrText('إكمال الدفع من محفظتي لهذه الباقة'),
                onPressed: planId == null || !const ['ai','office','engineer'].contains(type) ? null
                  : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
                      AlwaleedWalletScreen(initialPackageType: type, initialPackageId: planId,
                          initialPackageTitle: title))),
              ),
              const SizedBox(height: 10),
              if (type == 'ai') OutlinedButton.icon(
                icon: const Icon(Icons.payment_rounded),
                label: const TrText('إكمال الدفع بوسيلة أخرى'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const AiPremiumScreen(initialSection: 'plans'))),
              ),
              if (type != 'ai') FilledButton.icon(
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(trUi(type == 'office' ? 'اختيار الباقة وإكمال مستندات المكتب'
                    : 'اختيار الباقة وإكمال مستندات المهندس')),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => type == 'office'
                        ? OfficeApplicationScreen(initialPlan: plan)
                        : EngineerApplicationScreen(initialPlan: plan))),
              ),
              if (type != 'ai') const SizedBox(height: 8),
              if (type != 'ai') TrText('في حالة عدم اكتمال طلب المكتب/المهندس، أكمل المستندات والتوثيق قبل شراء الباقة.',
                  textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notice(BuildContext context, String text, Color accent) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? .12 : .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TrText(text, style: TextStyle(
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: dark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            )),
          ),
        ],
      ),
    );
  }
}
