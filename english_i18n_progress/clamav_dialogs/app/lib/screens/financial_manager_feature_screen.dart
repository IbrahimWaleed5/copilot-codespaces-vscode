import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';

class FinancialManagerFeatureScreen extends StatefulWidget {
  final String feature;
  final String title;
  const FinancialManagerFeatureScreen({super.key, required this.feature, required this.title});

  @override
  State<FinancialManagerFeatureScreen> createState() => _FinancialManagerFeatureScreenState();
}

class _FinancialManagerFeatureScreenState extends State<FinancialManagerFeatureScreen> {
  bool _loading = true;
  String? _error;
  Map<String,dynamic> _data = const {};

  @override
  void initState(){ super.initState(); _load(); }

  Future<void> _load() async {
    if(mounted) setState(() { _loading=true; _error=null; });
    try {
      final d=await ApiService.fetchFinancialManagerFeature(widget.feature);
      if(mounted) setState(()=>_data=d);
    } on ApiException catch(e){ if(mounted)setState(()=>_error=e.message); }
    catch(_){ if(mounted)setState(()=>_error='تعذر تحميل البيانات المالية.'.tr()); }
    finally { if(mounted)setState(()=>_loading=false); }
  }

  Future<String?> _reasonDialog() async {
    final c=TextEditingController();
    return showDialog<String>(context: context, builder: (ctx)=>AlertDialog(
      title: const TrText('سبب كشف البيانات'),
      content: TextField(controller:c, minLines:2, maxLines:4, decoration: InputDecoration(hintText:'اكتب سببًا واضحًا للتدقيق...'.tr())),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const TrText('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const TrText('تأكيد'))],
    ));
  }

  Future<void> _reveal(int id) async {
    final reason=await _reasonDialog();
    if(reason==null||reason.length<3)return;
    try {
      final d=await ApiService.revealFinancialPayoutAccount(id, reason);
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title: const TrText('بيانات التحويل البنكي'),
        content: SelectableText('المستفيد: ${d['.tr()beneficiary_name']??'—'}\nالبنك: ${d['bank_name']??'—'}\nاسم الحساب: ${d['account_name']??'—'}\nرقم الحساب: ${d['account_number']??'—'}\nIBAN: ${d['iban']??'—'}\nSWIFT: ${d['swift_code']??'—'}'.tr()),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const TrText('إغلاق'))],
      ));
    } on ApiException catch(e){ if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(e.message)))); }
  }

  Future<void> _releaseSecurityHold(int id, Map<String,dynamic> row) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const TrText('فك تعليق الصرف الأمني'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TrText('المستخدم: ${row['title'] ?? ''}\nسبب الحجز: ${row['subtitle'] ?? ''}'),
        const SizedBox(height: 10),
        const TrText('هذا الإجراء لا يعيد رصيد Held إلى المتاح، ولا يلغي أي سحب أو نزاع.'),
        TextField(controller: reasonController, minLines: 2, maxLines: 4,
          decoration: InputDecoration(labelText: 'سبب فك التعليق (8 أحرف على الأقل)'.tr())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const TrText('إلغاء')),
        FilledButton(onPressed: () {
          if (reasonController.text.trim().length >= 8) Navigator.pop(ctx, reasonController.text.trim());
        }, child: const TrText('تأكيد فك التعليق')),
      ],
    ));
    Future<void>.delayed(const Duration(milliseconds: 600), reasonController.dispose);
    if (reason == null || !mounted) return;
    try {
      final message = await ApiService.releaseFinancialSecurityHold(id, reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _toggleCoupon(int id,bool current) async {
    try {
      final m=await ApiService.toggleFinancialCoupon(id,!current);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(m))));
      await _load();
    } on ApiException catch(e){ if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(e.message)))); }
  }

  String _line(Map<String,dynamic> row){
    const ignored={'id','title','subtitle','route','download_route'};
    return row.entries.where((e)=>!ignored.contains(e.key)&&e.value!=null&&e.value.toString().isNotEmpty).take(7).map((e)=>'${_label(e.key)}: ${e.value}').join('\n');
  }
  String _label(String k)=>const {
    'status':'الحالة','amount':'المبلغ','currency':'العملة','date':'التاريخ','updated_at':'آخر تحديث','account_number':'رقم الحساب','iban':'IBAN','swift':'SWIFT','starts_at':'البداية','ends_at':'النهاية','discount_value':'الخصم','redeemed_count':'عدد الاستخدامات','impact':'أثر الخصومات','user':'المستخدم','ip':'IP','read':'مقروء','scope':'النطاق','source':'المصدر'
  }[k] ?? k;

  @override
  Widget build(BuildContext context){
    final rows=(_data['rows'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
    final canReveal=_data['can_reveal']==true;
    final canManage=_data['can_manage']==true;
    return Directionality(textDirection: AppLanguage.instance.textDirection,child:Scaffold(
      appBar:AppBar(title:Text(trUi(_data['title']?.toString()??widget.title))),
      body:_loading?const Center(child:CircularProgressIndicator()):_error!=null?Center(child:Text(trUi(_error!))):RefreshIndicator(onRefresh:_load,child:ListView(
        padding:const EdgeInsets.all(16),
        children:[
          if((_data['subtitle']?.toString()??'').isNotEmpty) Padding(padding:const EdgeInsets.only(bottom:14),child:Text(trUi(_data['subtitle'].toString()),style:const TextStyle(height:1.6))),
          if(rows.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(24),child:Center(child:TrText('لا توجد بيانات حاليًا.')))),
          ...rows.map((r)=>Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(trUi(r['title']?.toString()??'#${r['id']??''}'),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),
            if((r['subtitle']?.toString()??'').isNotEmpty) ...[const SizedBox(height:4),Text(trUi(r['subtitle'].toString()))],
            if(_line(r).isNotEmpty) ...[const SizedBox(height:9),SelectableText(trUi(_line(r)),style:const TextStyle(height:1.55))],
            if(widget.feature=='payout-accounts'&&canReveal&&r['id']!=null) ...[const SizedBox(height:10),FilledButton.icon(onPressed:()=>_reveal(int.parse('${r['id']}')),icon:const Icon(Icons.visibility_outlined),label:const TrText('كشف البيانات الحساسة'))],
            if(widget.feature=='security-holds'&&canManage&&r['can_release']==true&&r['id']!=null) ...[const SizedBox(height:10),FilledButton.icon(onPressed:()=>_releaseSecurityHold(int.parse('${r['id']}'),r),icon:const Icon(Icons.lock_open_outlined),label:const TrText('فك التعليق الأمني'))],
            if(widget.feature=='coupons'&&canManage&&r['id']!=null) ...[const SizedBox(height:10),OutlinedButton.icon(onPressed:()=>_toggleCoupon(int.parse('${r['id']}'),r['is_active']==true),icon:Icon(r['is_active']==true?Icons.pause_circle_outline:Icons.play_circle_outline),label:Text(trUi(r['is_active']==true?'إيقاف الكوبون':'تفعيل الكوبون')))],
          ])))),
        ],
      )),
    ));
  }
}
