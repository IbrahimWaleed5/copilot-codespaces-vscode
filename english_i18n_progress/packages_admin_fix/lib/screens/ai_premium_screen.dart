import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'kyc_verification_screen.dart';
import 'alwaleed_wallet_screen.dart';
import '../theme/app_theme.dart';

String _paymentLabel(Map<String, dynamic> method) {
  final key = method['gateway_key']?.toString().toLowerCase() ?? '';
  final label = method['label']?.toString().trim() ?? '';
  if (key == 'fawateery') return 'فواتيري';
  if (key == 'fawateery_paypal') return 'فواتيري - PayPal';
  return label;
}

class AiPremiumScreen extends StatefulWidget {
  final String? initialSection;

  const AiPremiumScreen({super.key, this.initialSection});

  @override
  State<AiPremiumScreen> createState() => _AiPremiumScreenState();
}

class _AiPremiumScreenState extends State<AiPremiumScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final String _country = 'PS';
  final _scrollController = ScrollController();
  final _overviewKey = GlobalKey();
  final _plansKey = GlobalKey();
  final _creditsKey = GlobalKey();
  final _ordersKey = GlobalKey();
  final _usageKey = GlobalKey();
  bool _initialSectionHandled = false;

  Map<String, dynamic> get _entitlement =>
      Map<String, dynamic>.from(_data?['entitlement'] as Map? ?? const {});

  List<Map<String, dynamic>> get _plans => List<Map<String, dynamic>>.from(
        (_data?['plans'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)),
      );

  List<Map<String, dynamic>> get _packages => List<Map<String, dynamic>>.from(
        (_data?['credit_packages'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)),
      );

  List<Map<String, dynamic>> get _orders => List<Map<String, dynamic>>.from(
        (_data?['orders'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)),
      );

  List<Map<String, dynamic>> get _usage => List<Map<String, dynamic>>.from(
        (_data?['usage'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)),
      );

  List<Map<String, dynamic>> get _countries {
    final payment = Map<String, dynamic>.from(_data?['payment'] as Map? ?? const {});
    return List<Map<String, dynamic>>.from(
      (payment['countries'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey? _sectionKey(String? section) {
    if (section == 'overview' || section == 'subscription') return _overviewKey;
    if (section == 'files') return _plansKey;
    if (section == 'plans') return _plansKey;
    if (section == 'credits') return _creditsKey;
    if (section == 'orders') return _ordersKey;
    if (section == 'usage') return _usageKey;
    return null;
  }

  void _scheduleInitialSectionScroll() {
    if (_initialSectionHandled || widget.initialSection == null) return;
    _initialSectionHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _sectionKey(widget.initialSection);
      final target = key?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: .06,
      );
    });
  }



  String _brandProviderLabel(dynamic provider, dynamic model) {
    final providerText = provider?.toString().trim().toLowerCase() ?? '';
    final modelText = model?.toString().trim().toLowerCase() ?? '';
    if (providerText.contains('gemini') || modelText.contains('gemini') || modelText.contains('flash')) {
      return 'AlWaleed Platform';
    }
    return 'AlWaleed Platform';
  }

  List<Widget> _dropdownSelectedItems(List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) labelBuilder) {
    return items
        .map((item) => Align(
              alignment: Alignment.centerRight,
              child: Text(
                trUi(labelBuilder(item)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ))
        .toList();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiService.fetchAiPremium(country: _country);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
      _scheduleInitialSectionScroll();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل إعدادات المساعد الذكي.');
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPurchaseSheet({
    required String type,
    required Map<String, dynamic> item,
  }) async {
    // Same rule as the website packages page: the admin already has unlimited AI.
    if (type == 'plan' && context.read<AuthProvider>().user?.role == 'admin') {
      AppFeedback.info('حساب المدير لديه صلاحية AI غير محدودة بحسب إعدادات المنصة الحالية؛ لا يلزم شراء هذه الباقة من محفظتك الشخصية.');
      return;
    }
    String country = _country;
    int? methodId;
    const String targetScope = 'user';
    File? receipt;
    bool sending = false;

    List<Map<String, dynamic>> methodsFor(String code) {
      for (final c in _countries) {
        if (c['code']?.toString() == code) {
          return List<Map<String, dynamic>>.from(
            (c['methods'] as List? ?? const [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e)),
          );
        }
      }
      return const [];
    }

    final enabled = methodsFor(country).where((m) => m['enabled'] != false).toList();
    if (enabled.isNotEmpty) methodId = int.tryParse('${enabled.first['id']}');

    if (!mounted) return;
    String couponCode = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final methods = methodsFor(country);
          Map<String, dynamic>? selected;
          for (final m in methods) {
            if (int.tryParse('${m['id']}') == methodId) selected = m;
          }
          final needsReceipt = selected?['requires_receipt'] == true;

          Future<void> pickReceipt() async {
            final picked = await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
            );
            if (picked?.path != null) setSheetState(() => receipt = File(picked!.path!));
          }

          Future<void> submit() async {
            if (methodId == null) {
              AppFeedback.error('اختر طريقة دفع مفعلة.');
              return;
            }
            if (needsReceipt && receipt == null) {
              AppFeedback.error('أرفق إيصال الدفع لهذه الطريقة.');
              return;
            }
            setSheetState(() => sending = true);
            try {
              final result = type == 'plan'
                  ? await ApiService.purchaseAiPlan(
                      planId: int.parse('${item['id']}'),
                      countryCode: country,
                      platformPaymentMethodId: methodId!,
                      receipt: needsReceipt ? receipt : null,
                      couponCode: couponCode.trim(),
                    )
                  : await ApiService.purchaseAiCredits(
                      packageId: int.parse('${item['id']}'),
                      targetScope: targetScope,
                      countryCode: country,
                      platformPaymentMethodId: methodId!,
                      receipt: needsReceipt ? receipt : null,
                    );

              final checkoutUrl = result['checkout_url']?.toString() ?? '';
              if (checkoutUrl.isNotEmpty) {
                final uri = Uri.tryParse(checkoutUrl);
                if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  throw ApiException('تعذر فتح بوابة الدفع.');
                }
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
              AppFeedback.success(result['message']?.toString() ?? 'تم إنشاء طلب AI.');
              await _load(silent: true);
            } on ApiException catch (e) {
              AppFeedback.error(e.message);
              if (e.message.contains('توثيق الهوية')) {
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  await Navigator.of(this.context).push(MaterialPageRoute(builder: (_) => const KycVerificationScreen()));
                }
              }
            } finally {
              if (sheetContext.mounted) setSheetState(() => sending = false);
            }
          }

          return Directionality(
            textDirection: AppLanguage.instance.textDirection,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              trUi(type == 'plan' ? 'شراء ${item['name']}' : 'شراء ${item['credits']} رصيد AlWaleed Platform'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                        ],
                      ),
                      if (type == 'plan' && int.tryParse('${item['id']}') != null) ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const TrText('الدفع من محفظتي لهذه الباقة'),
                          onPressed: sending ? null : () async {
                            final planId = int.tryParse('${item['id']}');
                            if (planId == null) return;
                            Navigator.of(sheetContext).pop();
                            await Navigator.of(this.context).push(MaterialPageRoute<void>(
                              builder: (_) => AlwaleedWalletScreen(
                                initialPackageType: 'ai',
                                initialPackageId: planId,
                                initialPackageTitle: item['name']?.toString() ?? 'باقة AI',
                              ),
                            ));
                            if (mounted) await _load(silent: true);
                          },
                        ),
                        const SizedBox(height: 8),
                        const TrText('أو أكمل الدفع عبر إحدى الوسائل التالية:',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 14),
                      ],
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _countries.any((c) => c['code']?.toString() == country) ? country : null,
                        decoration: InputDecoration(labelText: 'الدولة / فئة الدفع'.tr()),
                        selectedItemBuilder: (_) => _dropdownSelectedItems(
                          _countries,
                          (c) => c['name']?.toString() ?? c['code']?.toString() ?? '',
                        ),
                        items: _countries
                            .map((c) => DropdownMenuItem<String>(
                                  value: c['code']?.toString(),
                                  child: Text(
                                    trUi(c['name']?.toString() ?? c['code']?.toString() ?? ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setSheetState(() {
                            country = v;
                            final next = methodsFor(country).where((m) => m['enabled'] != false).toList();
                            methodId = next.isEmpty ? null : int.tryParse('${next.first['id']}');
                            receipt = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: methods.any((m) => int.tryParse('${m['id']}') == methodId) ? methodId : null,
                        decoration: InputDecoration(labelText: 'طريقة الدفع'.tr()),
                        selectedItemBuilder: (_) => _dropdownSelectedItems(
                          methods,
                          (m) => '${_paymentLabel(m)}${m['enabled'] == false ? ' — غير متاح حاليًا' : ''}',
                        ),
                        items: methods.map((m) {
                          final disabled = m['enabled'] == false;
                          return DropdownMenuItem<int>(
                            value: int.tryParse('${m['id']}'),
                            enabled: !disabled,
                            child: Text(
                              '${_paymentLabel(m)}${disabled ? ' — غير متاح حاليًا' : ''}'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setSheetState(() {
                          methodId = v;
                          receipt = null;
                        }),
                      ),
                      if (type == 'plan' && item['coupon_enabled'] != false) ...[
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (value) => couponCode = value,
                          decoration: InputDecoration(labelText: 'كوبون الخصم'.tr()),
                        ),
                      ],
                      if (selected != null) ...[
                        const SizedBox(height: 12),
                        _PaymentMethodDetails(method: selected),
                      ],
                      if (needsReceipt) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: sending ? null : pickReceipt,
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: Text(trUi(receipt == null ? 'إرفاق إيصال الدفع' : 'تغيير الإيصال')),
                        ),
                        if (receipt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              trUi(receipt!.path.split(Platform.pathSeparator).last),
                              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300), fontSize: 12),
                            ),
                          ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: sending ? null : submit,
                        icon: sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.payment_rounded),
                        label: Text(trUi(sending ? 'جاري إنشاء الطلب...' : 'متابعة الدفع')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancelOrder(int id) async {
    try {
      final message = await ApiService.cancelAiOrder(id);
      AppFeedback.success(message);
      await _load(silent: true);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  String _statusLabel(String status) {
    return switch (status) {
      'paid' => 'مدفوع ومفعّل',
      'pending' => 'معلق',
      'under_review' => 'قيد المراجعة',
      'rejected' => 'مرفوض',
      'cancelled' => 'ملغى',
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'paid' => AppColors.success,
      'rejected' => AppColors.danger,
      'cancelled' => AppColors.slate500,
      _ => const Color(0xFFF59E0B),
    };
  }

  @override
  Widget build(BuildContext context) {
    final unlimited = _entitlement['unlimited'] == true;
    final available = int.tryParse('${_entitlement['available_credits'] ?? 0}') ?? 0;
    final monthlyGranted = int.tryParse('${_entitlement['monthly_granted'] ?? 0}') ?? 0;
    final monthlyUsed = int.tryParse('${_entitlement['monthly_used'] ?? 0}') ?? 0;
    final purchased = int.tryParse('${_entitlement['purchased_balance'] ?? 0}') ?? 0;
    final usageLimits = Map<String, dynamic>.from(_entitlement['usage_limits'] as Map? ?? const {});

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: const TrText('ترقية المساعد الذكي'),
          actions: [IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded))],
        ),
        body: _loading && _data == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _data == null
                ? _AiError(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        Container(
                          key: _overviewKey,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: Theme.of(context).brightness == Brightness.dark
                                  ? const [Color(0xFF312E81), Color(0xFF0E7490), Color(0xFF0D1B31)]
                                  : const [Color(0xFFE9E5FF), Color(0xFFE1F3FF), Color(0xFFFFFFFF)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFC4B5FD) : const Color(0xFF4338CA)),
                                  const SizedBox(width: 8),
                                  const TrText('المساعد الذكي • الباقة والرصيد', style: TextStyle(fontWeight: FontWeight.w900)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(trUi(unlimited ? '∞' : '$available'), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                              TrText('Credits متاحة للمساعد • ${_entitlement['plan_label'] ?? 'AI Free'}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                              const SizedBox(height: 12),
                              if (unlimited)
                                const TrText('مدير المنصة • AI Business • استخدام غير محدود بدون خصم Credits', style: TextStyle(fontSize: 11, color: Color(0xFF86EFAC), fontWeight: FontWeight.w800))
                              else ...[
                                LinearProgressIndicator(
                                  value: monthlyGranted > 0 ? (monthlyUsed / monthlyGranted).clamp(0.0, 1.0).toDouble() : 0,
                                  minHeight: 7,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                const SizedBox(height: 7),
                                TrText('استهلاك الشهر: $monthlyUsed / $monthlyGranted • رصيد إضافي: $purchased', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _UsageLimitsPanel(limits: usageLimits, unlimited: unlimited, usableNow: int.tryParse('${_entitlement['usable_credits_now'] ?? 0}') ?? 0),
                        const SizedBox(height: 18),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(trUi(_error!), style: const TextStyle(color: AppColors.red200)),
                          ),
                        // File attachments stay in the AI chat; no separate analysis upload on the packages page.
                        const SizedBox(height: 18),
                        _SectionTitle(key: _plansKey, title: 'باقات المساعد الذكي', subtitle: 'ترقية شهرية خاصة بهذا الحساب', icon: Icons.workspace_premium_rounded),
                        const SizedBox(height: 10),
                        ..._plans.map((plan) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PlanCard(
                                plan: plan,
                                isCurrent: (_entitlement['status'] == 'active' &&
                                    _entitlement['plan'] is Map &&
                                    int.tryParse('${(_entitlement['plan'] as Map)['id']}') == int.tryParse('${plan['id']}') &&
                                    _entitlement['plan_source'] != 'free' &&
                                    DateTime.tryParse('${_entitlement['period_ends_at'] ?? ''}')?.isAfter(DateTime.now()) == true),
                                onBuy: () => _openPurchaseSheet(type: 'plan', item: plan),
                              ),
                            )),
                        const SizedBox(height: 14),
                        _SectionTitle(key: _creditsKey, title: 'شراء رصيد إضافي', subtitle: 'يزيد استخدام باقتك الحالية ولا يفتح أدوات باقة أعلى', icon: Icons.add_card_rounded),
                        const SizedBox(height: 10),
                        ..._packages.map((package) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CreditPackageCard(
                                package: package,
                                onBuy: () => _openPurchaseSheet(type: 'credits', item: package),
                              ),
                            )),
                        const SizedBox(height: 14),
                        _SectionTitle(key: _ordersKey, title: 'طلبات الشراء', subtitle: 'آخر طلبات الباقات والرصيد', icon: Icons.receipt_long_rounded),
                        const SizedBox(height: 10),
                        if (_orders.isEmpty)
                          _EmptyCard(text: 'لا توجد طلبات شراء حتى الآن.'.tr())
                        else
                          ..._orders.take(12).map((order) {
                            final status = order['status']?.toString() ?? '';
                            final product = order['plan'] is Map
                                ? (order['plan'] as Map)['name']?.toString()
                                : order['credit_package'] is Map
                                    ? (order['credit_package'] as Map)['name']?.toString()
                                    : null;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(trUi(order['reference_number']?.toString() ?? '-'), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300), fontWeight: FontWeight.w900, fontSize: 12)),
                                          const SizedBox(height: 4),
                                          Text(trUi(product ?? 'طلب AI'), style: const TextStyle(fontWeight: FontWeight.w900)),
                                          const SizedBox(height: 3),
                                          Text('${order['amount'] ?? 0} ${order['currency'] ?? ''} • ${order['payment_method'] ?? '-'}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
                                          if ((order['rejection_reason']?.toString() ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 5),
                                              child: Text(trUi(order['rejection_reason'].toString()), style: const TextStyle(color: AppColors.red300, fontSize: 11)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(trUi(_statusLabel(status)), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w800, fontSize: 11)),
                                        if (status == 'pending' || status == 'under_review')
                                          TextButton(
                                            onPressed: () => _cancelOrder(int.parse('${order['id']}')),
                                            child: const TrText('إلغاء', style: TextStyle(color: AppColors.red300, fontSize: 11)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 14),
                        _SectionTitle(key: _usageKey, title: 'سجل الاستهلاك', subtitle: 'كل عملية AI وتكلفتها الفعلية', icon: Icons.insights_rounded),
                        const SizedBox(height: 10),
                        if (_usage.isEmpty)
                          _EmptyCard(text: 'لم يُسجل استخدام AI بعد.'.tr())
                        else
                          Card(
                            child: Column(
                              children: _usage.take(20).map((row) {
                                final succeeded = row['status']?.toString() == 'succeeded';
                                return ListTile(
                                  dense: true,
                                  title: Text(trUi(row['operation']?.toString() ?? 'AI'), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text(trUi(_brandProviderLabel(row['provider'], row['model'])), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Text(trUi(succeeded ? '-${row['credits_used'] ?? 0}' : '0'), style: TextStyle(color: succeeded ? (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300) : (Theme.of(context).brightness == Brightness.dark ? Color(0xFF6D85A5) : AppColors.slate500), fontWeight: FontWeight.w900)),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _UsageLimitsPanel extends StatelessWidget {
  final Map<String, dynamic> limits;
  final bool unlimited;
  final int usableNow;

  const _UsageLimitsPanel({required this.limits, required this.unlimited, required this.usableNow});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> limit(String key) => Map<String, dynamic>.from(limits[key] as Map? ?? const {});

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: TrText('حدود الاستخدام', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
                if (!unlimited) TrText('متاح الآن: $usableNow', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300))),
              ],
            ),
            const SizedBox(height: 4),
            TrText('5 ساعات و7 أيام Rolling • الشهر حسب دورة الاشتراك', style: TextStyle(fontSize: 10.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 650 ? (constraints.maxWidth - 20) / 3 : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: width, child: _UsageLimitCard(title: '5 ساعات', data: limit('five_hours'), unlimited: unlimited)),
                    SizedBox(width: width, child: _UsageLimitCard(title: '7 أيام', data: limit('seven_days'), unlimited: unlimited)),
                    SizedBox(width: width, child: _UsageLimitCard(title: 'الشهر', data: limit('month'), unlimited: unlimited)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageLimitCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  final bool unlimited;

  const _UsageLimitCard({required this.title, required this.data, required this.unlimited});

  @override
  Widget build(BuildContext context) {
    final isUnlimited = unlimited || data['unlimited'] == true;
    final limit = int.tryParse('${data['limit'] ?? 0}') ?? 0;
    final used = int.tryParse('${data['used'] ?? 0}') ?? 0;
    final remaining = int.tryParse('${data['remaining'] ?? 0}') ?? 0;
    final progress = isUnlimited || limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF071426) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(trUi(title), style: const TextStyle(fontWeight: FontWeight.w900))),
              Text(trUi(isUnlimited ? '∞' : '$remaining'), style: TextStyle(fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300))),
            ],
          ),
          const SizedBox(height: 9),
          if (isUnlimited)
            const TrText('غير محدود', style: TextStyle(fontSize: 11, color: Color(0xFF86EFAC), fontWeight: FontWeight.w800))
          else ...[
            LinearProgressIndicator(value: progress, minHeight: 6, borderRadius: BorderRadius.circular(99)),
            const SizedBox(height: 6),
            TrText('$used / $limit مستخدم', style: TextStyle(fontSize: 10.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _SectionTitle({super.key, required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.blue500_10, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trUi(title), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text(trUi(subtitle), style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onBuy;
  final bool isCurrent;
  const _PlanCard({required this.plan, required this.onBuy, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trUi(plan['name']?.toString() ?? 'AI Plan'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(trUi(plan['description']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.5, fontSize: 12)),
                    ],
                  ),
                ),
                Text('${plan['monthly_price'] ?? 0} ${plan['currency'] ?? 'USD'}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip('${plan['monthly_credits'] ?? 0} Credits / شهر'),
                _Chip('${plan['credits_5h_limit'] ?? 0} / 5 ساعات'),
                _Chip('${plan['credits_7d_limit'] ?? 0} / 7 أيام'),
                const _Chip('باقة خاصة بهذا الحساب'),
                if ((int.tryParse('${plan['max_file_mb'] ?? 0}') ?? 0) > 0) _Chip('ملفات حتى ${plan['max_file_mb']} MB'),
              ],
            ),
            const SizedBox(height: 14),
            TrText('يفتح لك', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List<dynamic>.from(plan['upgrade_highlights'] as List? ?? const [])
                  .map((item) => _Chip(item.toString()))
                  .toList(),
            ),
            const SizedBox(height: 12),
            ...List<dynamic>.from(plan['marketing_benefits'] as List? ?? const []).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF6EE7B7)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        trUi(item.toString()),
                        style: TextStyle(fontSize: 11.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x2210B981),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const TrText('✓ أنت داخل الخطة بالفعل',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900,
                      color: Color(0xFF6EE7B7))),
              )
            else FilledButton.icon(
              onPressed: onBuy,
              icon: const Icon(Icons.upgrade_rounded),
              label: TrText('شراء / ترقية إلى ${plan['name'] ?? 'AI'}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditPackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final VoidCallback onBuy;
  const _CreditPackageCard({required this.package, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: const Color(0x1A10B981), borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFF6EE7B7)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${package['credits'] ?? 0} رصيد AlWaleed Platform'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('${package['price'] ?? 0} ${package['currency'] ?? 'USD'}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                  const SizedBox(height: 3),
                  TrText('رصيد إضافي فقط • لا يفتح مزايا باقة أعلى', style: TextStyle(fontSize: 9.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant))),
                ],
              ),
            ),
            FilledButton(onPressed: onBuy, child: const TrText('شراء')),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodDetails extends StatelessWidget {
  final Map<String, dynamic> method;
  const _PaymentMethodDetails({required this.method});

  @override
  Widget build(BuildContext context) {
    final rows = <String>[];
    void add(String label, dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) rows.add('$label: $text');
    }

    add('الجهة', method['provider_name']);
    add('اسم الحساب', method['account_name']);
    add('رقم الحساب', method['account_number']);
    add('IBAN', method['iban']);
    add('المحفظة', method['phone']);
    add('العملة', method['currency']);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF071426) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trUi(_paymentLabel(method)), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: SelectableText(trUi(row), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11), textAlign: TextAlign.start),
              )),
          if ((method['instructions']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(trUi(method['instructions'].toString()), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300), fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x0DFFFFFF) : Theme.of(context).colorScheme.surface), borderRadius: BorderRadius.circular(10), border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor))),
      child: Text(trUi(text), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(trUi(text), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)))),
        ),
      );
}

class _AiError extends StatelessWidget {
  final String message;
  final Future<void> Function({bool silent}) onRetry;
  const _AiError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.red300, size: 42),
            const SizedBox(height: 12),
            Text(trUi(message), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => onRetry(), child: const TrText('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
