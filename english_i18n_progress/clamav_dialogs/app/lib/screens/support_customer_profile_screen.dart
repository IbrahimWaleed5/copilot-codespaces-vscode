import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';

class SupportCustomerProfileScreen extends StatelessWidget {
  final int userId;
  final Map<String, dynamic> profile;

  const SupportCustomerProfileScreen({super.key, required this.userId, required this.profile});

  Map<String, dynamic> _m(Object? value) => Map<String, dynamic>.from(value as Map? ?? const {});
  List<dynamic> _l(Object? value) => List<dynamic>.from(value as List? ?? const []);

  @override
  Widget build(BuildContext context) {
    final account=_m(profile['account']); final kyc=_m(profile['kyc']); final ai=_m(profile['ai']);
    final payments=_m(profile['payments']); final support=_m(profile['support']); final moderation=_m(profile['moderation']);
    final subscriptions=_m(profile['subscriptions']); final engineerSub=_m(subscriptions['engineer']); final officeSub=_m(subscriptions['office']); final aiSub=_m(subscriptions['ai']);
    final risk=_m(profile['risk']); final tickets=_l(support['recent']); final security=_l(profile['login_security']);
    final recoveries=_l(profile['recoveries']); final linked=_l(profile['linked_accounts']); final devices=_l(profile['devices']); final timeline=_l(profile['timeline']);
    final riskLevel=risk['level']?.toString()??'low';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final riskColor = riskLevel == 'high'
        ? (dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C))
        : riskLevel == 'medium'
            ? (dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309))
            : (dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D));

    return Directionality(textDirection: AppLanguage.instance.textDirection,child:Scaffold(
      backgroundColor: dark
          ? const Color(0xFF060B18)
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: dark
            ? const Color(0xFF0B132B)
            : Theme.of(context).colorScheme.surface,
        title: const TrText('ملف العميل للدعم'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text('ID: CUST-$userId', style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
      body:ListView(padding:const EdgeInsets.all(14),children:[
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CUSTOMER SUPPORT PROFILE',
                    style: TextStyle(
                      color: dark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    trUi(account['name']?.toString() ?? '—'),
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: dark ? .12 : .08),
                border: Border.all(color: riskColor.withValues(alpha: .35)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'RISK',
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${riskLevel.toUpperCase()} · ${risk['score']??0}/100',
                    style: TextStyle(color: riskColor, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height:14),
        _grid([_infoCard(context, 'تفاصيل الحساب',{'البريد':account['email'],'الهاتف':account['phone'],'الدور':account['role'],'الحالة':account['status'],'2FA':account['two_factor']==true?'مفعّل':'غير مفعّل'}),_infoCard(context, 'توثيق الهوية KYC',{'الحالة':kyc['status']??'لم يبدأ'.tr(),'المستوى':kyc['level'],'المخاطر':kyc['risk_level'],'آخر 4':kyc['identity_last4'],'المستندات':kyc['documents_count']}),_infoCard(context, 'AI والاشتراك',{'الباقة':ai['plan'],'الحالة':ai['status'],'الرصيد':ai['available'],'المستخدم':ai['monthly_used']})]),
        const SizedBox(height:12),
        _grid([_stat(context, 'المشاريع',profile['projects_count'],Icons.folder_open),_stat(context, 'الاستشارات',profile['consultations_count'],Icons.chat_bubble_outline),_stat(context, 'عمليات الدفع',payments['count'],Icons.credit_card),_stat(context, 'مدفوع مؤكد',payments['paid_total'],Icons.receipt_long)]),
        const SizedBox(height:12),
        _card(context, 'الاشتراكات والباقات',[
          if(engineerSub.isNotEmpty) ListTile(contentPadding:EdgeInsets.zero,leading: Icon(Icons.engineering_outlined,color:dark?const Color(0xFF60A5FA):const Color(0xFF1D4ED8)),title:TrText('باقة المهندس: ${engineerSub['plan']??'—'}'),subtitle:Text('${engineerSub['status']??'—'} • ${engineerSub['started_at']??'—'} → ${engineerSub['ends_at']??'—'}${engineerSub['last_order_note']!=null?' • ${engineerSub['last_order_note']}':''}')),
          if(officeSub.isNotEmpty) ListTile(contentPadding:EdgeInsets.zero,leading: Icon(Icons.business_outlined,color:dark?const Color(0xFF67E8F9):const Color(0xFF0E7490)),title:TrText('باقة المكتب: ${officeSub['plan']??'—'}'),subtitle:Text('${officeSub['status']??'—'} • ${officeSub['started_at']??'—'} → ${officeSub['ends_at']??'—'}${officeSub['rejection_reason']!=null?' • ${officeSub['rejection_reason']}':''}')),
          if(aiSub.isNotEmpty) ListTile(contentPadding:EdgeInsets.zero,leading: Icon(Icons.auto_awesome_outlined,color:dark?const Color(0xFFA78BFA):const Color(0xFF6D28D9)),title:Text('AI: ${aiSub['plan']??'—'}'),subtitle:Text('${aiSub['status']??'—'} • الرصيد ${aiSub['available_credits']??0} • حتى ${aiSub['period_ends_at']??'—'}'.tr())),
          if(engineerSub.isEmpty&&officeSub.isEmpty&&aiSub.isEmpty) const TrText('لا توجد اشتراكات حالية.'),
        ]),
        const SizedBox(height:12),
        _card(context, 'إجراءات الحساب',[Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:()=>_simpleAction(context,'resend_verification'),icon:const Icon(Icons.mark_email_read_outlined),label:const TrText('إعادة توثيق البريد')),OutlinedButton.icon(onPressed:()=>_reasonAction(context,'revoke_sessions','تسجيل خروج كل الأجهزة'),icon:const Icon(Icons.phonelink_erase_rounded),label:const TrText('إنهاء الجلسات')),OutlinedButton.icon(onPressed:()=>_reasonAction(context,'lock','قفل الحساب'),icon:const Icon(Icons.lock_outline),label:const TrText('قفل مؤقت')),OutlinedButton.icon(onPressed:()=>_reasonAction(context,'unlock','إلغاء قفل الحساب'),icon:const Icon(Icons.lock_open_rounded),label:const TrText('إلغاء القفل'))])]),
        const SizedBox(height:12),
        _card(context, 'إجراء حساس بموافقة ثانية',[FilledButton.icon(onPressed:()=>_sensitiveDialog(context),icon:const Icon(Icons.approval_outlined),label:const TrText('طلب اعتماد من Support Supervisor'))]),
        const SizedBox(height:12),
        _card(context, 'الأجهزة والجلسات',devices.isEmpty?[const TrText('لا توجد أجهزة مسجلة.')]:devices.map((raw){final d=_m(raw);return ListTile(contentPadding:EdgeInsets.zero,dense:true,title:Text(d['device_name']?.toString()??'جهاز'.tr()),subtitle:Text('${d['platform']??'—'} • ${d['last_ip']??'—'} • ${d['last_seen_at']??'—'}'));}).toList()),
        const SizedBox(height:12),
        _card(context, 'حسابات محتمل ارتباطها',linked.isEmpty?[const TrText('لا توجد حسابات مطابقة.')]:linked.map((raw){final u=_m(raw);return ListTile(contentPadding:EdgeInsets.zero,title:Text(trUi(u['name']?.toString()??'—')),subtitle:Text('${u['email']??'—'} • ${u['phone']??'—'} • ${u['status']??'—'}'));}).toList()),
        const SizedBox(height:12),
        _card(context, 'سجل تذاكر العميل',tickets.isEmpty?[const TrText('لا توجد تذاكر.')]:tickets.map((raw){final t=_m(raw);return ListTile(contentPadding:EdgeInsets.zero,title:Text(
            trUi(t['ticket_number']?.toString() ?? '—'),
            style: TextStyle(
              color: dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
              fontWeight: FontWeight.w800,
            ),
          ),subtitle:Text('${t['subject']??'—'} • ${t['status']??'—'} • ${t['priority']??'—'}'));}).toList()),
        const SizedBox(height:12),
        _card(context, 'الأمان والاسترداد',[TrText('تحذيرات: ${moderation['warnings_count']??0}   •   High risk: ${moderation['high_risk_count']??0}'),const SizedBox(height:8),...recoveries.map((raw){final r=_m(raw);return Text('${r['reference']??'—'} • ${r['status']??'—'}',style:TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant)));})]),
        const SizedBox(height:12),
        _card(context, 'آخر أحداث الأمان',security.isEmpty?[const TrText('لا توجد أحداث.')]:security.take(8).map((raw){final e=_m(raw);return ListTile(contentPadding:EdgeInsets.zero,dense:true,title:Text('${e['platform']??'—'} • ${e['method']??e['event']??'—'}'),subtitle:Text('${e['ip_address']??'—'} • ${e['created_at']??'—'}'));}).toList()),
        const SizedBox(height:12),
        _card(context, 'Activity Timeline',timeline.isEmpty?[const TrText('لا توجد أحداث.')]:timeline.take(25).map((raw){final x=_m(raw);return ListTile(contentPadding:EdgeInsets.zero,dense:true,leading: Icon(
            Icons.timeline_rounded,
            color: dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490),
          ),title:Text(trUi(x['title']?.toString()??'—')),subtitle:Text('${x['description']??''}\n${x['status']??'—'} • ${x['at']??'—'}'));}).toList()),
        const SizedBox(height:12),
        _emailActions(context,account['email']?.toString()??''),
        const SizedBox(height:80),
      ]),
    ));
  }

  Widget _grid(List<Widget> children) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 760) {
            return Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 250,
            ),
            itemCount: children.length,
            itemBuilder: (_, index) => children[index],
          );
        },
      );
  Widget _card(BuildContext context, String title, List<Widget> children) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xB3111C38) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? const Color(0xFF1F2E54) : Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x100F2747),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trUi(title),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          Divider(
            color: dark ? const Color(0xFF1F2E54) : Theme.of(context).dividerColor,
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _infoCard(
    BuildContext context,
    String title,
    Map<String, Object?> rows,
  ) =>
      _card(
        context,
        title,
        rows.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        trUi(e.key),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${e.value ?? '—'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );

  Widget _stat(
    BuildContext context,
    String title,
    Object? value,
    IconData icon,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xB3111C38) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? const Color(0xFF1F2E54) : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trUi(title),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              Text(
                '${value ?? 0}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Icon(
            icon,
            color: dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
          ),
        ],
      ),
    );
  }

  Future<void> _simpleAction(BuildContext context,String action) async{try{final m=await ApiService.supportAccountAction(userId,action:action);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(m))));}on ApiException catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(e.message))));}}
  Future<void> _reasonAction(BuildContext context,String action,String title) async{
    final c=TextEditingController();
    bool identity=false, ownership=false, documented=false;
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setState)=>AlertDialog(
      title:Text(trUi(title)),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:c,minLines:3,maxLines:5,decoration:InputDecoration(labelText:'السبب المطلوب'.tr(),hintText:'اكتب السبب بالتفصيل (8 أحرف على الأقل)'.tr(),alignLabelWithHint:true,border:const OutlineInputBorder())),
        CheckboxListTile(contentPadding:EdgeInsets.zero,dense:true,controlAffinity:ListTileControlAffinity.leading,value:identity,onChanged:(v)=>setState(()=>identity=v==true),title:const TrText('تحققت من الهوية')),
        CheckboxListTile(contentPadding:EdgeInsets.zero,dense:true,controlAffinity:ListTileControlAffinity.leading,value:ownership,onChanged:(v)=>setState(()=>ownership=v==true),title:const TrText('تحققت من ملكية الحساب')),
        CheckboxListTile(contentPadding:EdgeInsets.zero,dense:true,controlAffinity:ListTileControlAffinity.leading,value:documented,onChanged:(v)=>setState(()=>documented=v==true),title:const TrText('وثقت سبب الإجراء')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const TrText('إلغاء')),FilledButton(onPressed:identity&&ownership&&documented?()=>Navigator.pop(d,{'reason':c.text,'checklist':true}):null,child:const TrText('تنفيذ'))]
    )));
    Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
    if(result==null)return;
    if((result['reason']??'').toString().trim().length<8){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi('اكتب سببًا واضحًا (8 أحرف على الأقل).'))));return;}
    try{final m=await ApiService.supportAccountAction(userId,action:action,reason:'${result['reason']}',checklist:const {'identity_confirmed':true,'ownership_confirmed':true,'reason_confirmed':true});if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(m))));}on ApiException catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(e.message))));}
  }
  Widget _emailActions(BuildContext context, String email) => _card(
    context,
    'البريد المباشر للعميل',
    [
      Text(
        trUi(email.isEmpty ? 'لا يوجد بريد مسجل لهذا العميل.' : email),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: email.isEmpty ? null : () => _customEmailDialog(context),
            icon: const Icon(Icons.outgoing_mail),
            label: const TrText('إرسال بريد مخصص'),
          ),
          OutlinedButton.icon(
            onPressed: email.isEmpty ? null : () => _sendKycRecovery(context),
            icon: const Icon(Icons.verified_user_outlined),
            label: const TrText('إرسال رابط KYC / الاسترداد'),
          ),
        ],
      ),
    ],
  );

  Future<void> _customEmailDialog(BuildContext context) async {
    final subject = TextEditingController();
    final message = TextEditingController();
    final actionUrl = TextEditingController();
    final actionLabel = TextEditingController();

    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('إرسال بريد مخصص'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subject,
                decoration: InputDecoration(labelText: 'العنوان'.tr()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: message,
                maxLines: 6,
                decoration: InputDecoration(labelText: 'الرسالة'.tr()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: actionUrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'رابط الإجراء — اختياري'.tr(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: actionLabel,
                decoration: InputDecoration(
                  labelText: 'اسم زر الإجراء — اختياري'.tr(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const TrText('إرسال'),
          ),
        ],
      ),
    );

    if (send == true &&
        subject.text.trim().isNotEmpty &&
        message.text.trim().isNotEmpty) {
      try {
        final result = await ApiService.sendSupportCustomEmail(
          userId,
          subject: subject.text.trim(),
          message: message.text.trim(),
          actionUrl: actionUrl.text.trim().isEmpty ? null : actionUrl.text.trim(),
          actionLabel:
              actionLabel.text.trim().isEmpty ? null : actionLabel.text.trim(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trUi(result))),
          );
        }
      } on ApiException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trUi(error.message))),
          );
        }
      }
    }

    Future<void>.delayed(const Duration(milliseconds: 600), subject.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), message.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), actionUrl.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), actionLabel.dispose);
  }

  Future<void> _sendKycRecovery(BuildContext context) async {
    try {
      final result = await ApiService.sendSupportKycRecovery(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trUi(result))),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trUi(error.message))),
        );
      }
    }
  }

  Future<void> _sensitiveDialog(BuildContext context) async{
    String type='recovery_issue_password';
    final c=TextEditingController();
    bool identity=false, ownership=false, documented=false;
    final result=await showDialog<Map<String,String>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setState)=>AlertDialog(
      title:const TrText('إجراء حساس'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(initialValue:type,isExpanded:true,decoration:InputDecoration(labelText:'نوع الإجراء'.tr(),border:const OutlineInputBorder()),items:const[
          DropdownMenuItem(value:'recovery_issue_password',child:TrText('إصدار كلمة مرور لاسترداد عالي المخاطر',maxLines:2,overflow:TextOverflow.ellipsis)),
          DropdownMenuItem(value:'disable_2fa',child:TrText('إلغاء 2FA',maxLines:2,overflow:TextOverflow.ellipsis)),
          DropdownMenuItem(value:'change_primary_email',child:TrText('تغيير البريد الأساسي',maxLines:2,overflow:TextOverflow.ellipsis)),
          DropdownMenuItem(value:'high_risk_recovery',child:TrText('استرداد عالي المخاطر',maxLines:2,overflow:TextOverflow.ellipsis)),
        ],onChanged:(v)=>setState(()=>type=v??type)),
        const SizedBox(height:12),
        TextField(controller:c,minLines:3,maxLines:5,decoration:InputDecoration(labelText:'سبب الإجراء'.tr(),hintText:'اكتب السبب بالتفصيل (12 حرفًا على الأقل)'.tr(),alignLabelWithHint:true,border:const OutlineInputBorder())),
        CheckboxListTile(contentPadding:EdgeInsets.zero,dense:true,controlAffinity:ListTileControlAffinity.leading,value:identity,onChanged:(v)=>setState(()=>identity=v==true),title:const TrText('تحققت من الهوية')),
        CheckboxListTile(contentPadding:EdgeInsets.zero,dense:true,controlAffinity:ListTileControlAffinity.leading,value:ownership,onChanged:(v)=>setState(()=>ownership=v==true),title:const TrText('تحققت من ملكية الحساب')),
        CheckboxListTile(contentPadding:EdgeInsets.zero,dense:true,controlAffinity:ListTileControlAffinity.leading,value:documented,onChanged:(v)=>setState(()=>documented=v==true),title:const TrText('وثقت السبب')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const TrText('إلغاء')),FilledButton(onPressed:identity&&ownership&&documented?()=>Navigator.pop(d,{'type':type,'reason':c.text}):null,child:const TrText('إرسال للمشرف'))]
    )));
    Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
    if(result==null)return;
    if((result['reason']??'').trim().length<12){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi('اكتب سببًا واضحًا (12 حرفًا على الأقل).'))));return;}
    try{final m=await ApiService.requestSupportSensitiveAction(userId,actionType:result['type']!,reason:result['reason']!,checklist:const {'identity_confirmed':true,'ownership_confirmed':true,'reason_confirmed':true});if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(m))));}on ApiException catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(e.message))));}
  }
}
