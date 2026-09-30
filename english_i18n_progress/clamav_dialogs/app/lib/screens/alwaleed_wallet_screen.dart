import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'payout_account_screen.dart';
import 'alwaleed_wallet_finance_screen.dart';
import 'wallet_fx_screen.dart';
import 'create_consultation_screen.dart';
import 'projects_screen.dart';
import 'packages_offers_screen.dart';

import '../services/api_service.dart';

class AlwaleedWalletScreen extends StatefulWidget {
  /// Context-only navigation. No financial operation is started without user confirmation.
  final int? initialConsultationId;
  final String? initialPackageType;
  final int? initialPackageId;
  final String? initialPackageTitle;
  const AlwaleedWalletScreen({super.key, this.initialConsultationId,
    this.initialPackageType, this.initialPackageId, this.initialPackageTitle});

  @override
  State<AlwaleedWalletScreen> createState() => _AlwaleedWalletScreenState();
}

class _AlwaleedWalletScreenState extends State<AlwaleedWalletScreen> {
  final _amount = TextEditingController();
  final _otp = TextEditingController();
  final _paymentReference = TextEditingController();
  final _senderName = TextEditingController();
  final _depositPassword = TextEditingController();
  final _depositOtp = TextEditingController();
  final _depositNote = TextEditingController();
  String _view = 'overview';
  bool _initialPackagePromptOpened = false;
  int _depositStep = 0;
  Map<String, dynamic>? _activeDeposit;
  PlatformFile? _depositReceipt;
  final _consultationId = TextEditingController();
  final _projectId = TextEditingController();
  final _installmentId = TextEditingController();
  String _currency = 'ILS';
  int? _paymentMethodId;
  Map<String, dynamic>? _depositFxQuote;
  String? _depositFxStamp;
  String? _currentDepositFxStamp() => _paymentMethodId == null ? null
      : '$_paymentMethodId|$_currency|${_amount.text.trim()}';
  Map? _selectedPaymentMethod() {
    final raw = _data['payment_methods'];
    if (raw is! List || _paymentMethodId == null) return null;
    for (final value in raw) {
      if (value is Map && int.tryParse('${value['id']}') == _paymentMethodId) return value;
    }
    return null;
  }
  bool _needsCrossDepositQuote() {
    final method = _selectedPaymentMethod();
    return method != null &&
        method['currency']?.toString().toUpperCase() != _currency;
  }

  Future<void> _previewDepositFx() async {
    final method = _selectedPaymentMethod();
    if (_busy || method == null || !_needsCrossDepositQuote()) return;
    final stamp = _currentDepositFxStamp();
    if (_amount.text.trim().isEmpty) { _notice('أدخل مبلغ الدفع أولًا.'); return; }
    setState(() { _busy = true; _depositFxQuote = null; _depositFxStamp = null; });
    try {
      final url = Uri.parse('${ApiService.baseUrl}/wallet/deposits/fx-quote')
          .replace(queryParameters: {
        'currency': _currency, 'payment_method_id': '${method['id']}',
        'amount': _amount.text.trim(),
      });
      final result = _decode(await http.get(url, headers: await _headers()));
      if (!mounted || stamp != _currentDepositFxStamp()) return;
      setState(() { _depositFxQuote = result; _depositFxStamp = stamp; });
    } catch (error) { _notice(error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  String _depositRegion = '';
  String _globalPaymentCategory = '';
  String _cryptoAsset = '';
  int? _payoutAccountId;
  String _withdrawSource = 'available';
  Map<String, dynamic> _data = {};
  final Map<String,String> _packageRequestKeys = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialConsultationId != null) {
      _consultationId.text = widget.initialConsultationId.toString();
      _view = 'payments';
    }
    _refresh();
  }

  @override
  void dispose() {
    _amount.dispose();
    _otp.dispose();
    _paymentReference.dispose();
    _senderName.dispose();
    _depositPassword.dispose();
    _depositOtp.dispose();
    _depositNote.dispose();
    _consultationId.dispose();
    _projectId.dispose();
    _installmentId.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers({bool jsonBody = true}) async {
    final token = await ApiService.getAuthToken();
    if (token == null || token.isEmpty) throw Exception('يجب تسجيل الدخول أولاً.');
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (jsonBody) 'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw Exception('تعذر قراءة استجابة الخادم (${response.statusCode}).');
    }
    if (response.statusCode == 429) {
      throw Exception('طلبات كثيرة خلال وقت قصير. انتظر قليلًا قبل إعادة المحاولة.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message']?.toString() ?? 'تعذر تنفيذ العملية (${response.statusCode}).');
    }
    return data;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/wallet'), headers: await _headers());
      final data = _decode(res);
      if (mounted) setState(() {
        _data = data; _loading = false;
        if (_activeDeposit?['id'] != null && data['deposit_requests'] is List) {
          final id = int.tryParse('${_activeDeposit!['id']}');
          for (final item in data['deposit_requests'] as List) {
            if (item is Map && int.tryParse('${item['id']}') == id) {
              _activeDeposit = {...?_activeDeposit, ...item.map((k, v) => MapEntry(k.toString(), v))};
              break;
            }
          }
        }
        final methods = data['payment_methods'];
        final selectedMethodAvailable = methods is List && methods.any((m) {
          if (m is! Map) return false;
          final methodId = int.tryParse('${m['id']}');
          final sameCurrency =
              m['currency']?.toString().trim().toUpperCase() == _currency;
          final crossCurrency = data['deposit_fx_enabled'] == true &&
              m['cross_currency_eligible'] == true;
          return methodId == _paymentMethodId &&
              m['available'] == true &&
              (sameCurrency || crossCurrency);
        });
        if (_paymentMethodId != null && !selectedMethodAvailable) {
          _paymentMethodId = null;
        }
        final accounts = data['payout_accounts'];
        final selectedPayoutAccountAvailable = accounts is List &&
            accounts.any((a) => a is Map &&
                a['id'] == _payoutAccountId &&
                a['is_verified'] == true &&
                a['currency'] == _currency);
        if (_payoutAccountId != null && !selectedPayoutAccountAvailable) {
          _payoutAccountId = null;
        }
      });
      if (!_initialPackagePromptOpened && widget.initialPackageId != null &&
          widget.initialPackageType != null) {
        _initialPackagePromptOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _buyPackage(widget.initialPackageType!, widget.initialPackageId!,
              widget.initialPackageTitle ?? 'الباقة المختارة');
        });
      }
    } catch (error) {
      if (mounted) setState(() {
        _error = error is SocketException
            ? 'تعذر الاتصال بالخادم حاليًا. تحقق من الإنترنت ثم أعد المحاولة.'
            : error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await http.post(Uri.parse('${ApiService.baseUrl}$path'),
          headers: await _headers(), body: jsonEncode(body));
      final response = _decode(res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trUi(response['message']?.toString() ?? 'تم حفظ الطلب.'))),
        );
      }
      await _refresh();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(error.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openView(String view) {
    if (!mounted) return;
    setState(() => _view = view);
  }

  // A request is not sent to the server until step one is explicitly confirmed.
  void _resumeDeposit(Map request) {
    if (!mounted) return;
    final status = request['status']?.toString() ?? '';
    if (!const ['draft','otp_sent','awaiting_payment','needs_info','pending'].contains(status)) return;
    setState(() {
      _activeDeposit = request.map((key, value) => MapEntry(key.toString(), value));
      _senderName.text = request['sender_name']?.toString() ?? _senderName.text;
      final currency = request['currency']?.toString();
      if (const ['ILS','USD','JOD','SAR'].contains(currency)) _currency = currency!;
      final method = request['platform_payment_method_id'];
      _paymentMethodId = method is num ? method.toInt() : int.tryParse(method?.toString() ?? '');
      final methods = _data['payment_methods'];
      if (methods is List) {
        for (final method in methods) {
          if (method is Map && int.tryParse('${method['id']}') == _paymentMethodId) {
            _depositRegion = method['country_code']?.toString() ?? '';
            _globalPaymentCategory = _depositRegion == 'GL'
                ? (method['type'] == 'crypto' ? 'crypto' : 'other') : '';
            _cryptoAsset = method['crypto_asset']?.toString() ?? '';
            break;
          }
        }
      }
      _depositStep = status == 'draft' ? 1 : status == 'otp_sent' ? 2
          : status == 'pending' ? 4 : 3;
      _view = 'deposit';
    });
  }

  Future<void> _createDepositDraft() async {
    final fx = _depositFxQuote;
    final cross = _needsCrossDepositQuote();
    if (cross && (fx == null || _depositFxStamp != _currentDepositFxStamp())) {
      _notice('احسب السعر وراجع عملة الدفع ومبلغ الرصيد المتوقع قبل إنشاء الطلب.');
      return;
    }
    final amount = num.tryParse(_amount.text.trim());
    if (_busy || amount == null || amount <= 0 || _paymentMethodId == null || _senderName.text.trim().length < 2) {
      _notice('أدخل مبلغًا صحيحًا واسم مرسل التحويل واختر طريقة الدفع.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = _decode(await http.post(Uri.parse('${ApiService.baseUrl}/wallet/deposits'),
        headers: await _headers(), body: jsonEncode({
          'currency': _currency, 'amount': _amount.text.trim(),
          'payment_method_id': _paymentMethodId, 'sender_name': _senderName.text.trim(),
          if (cross) ...{
            'expected_target_minor': fx!['wallet_credit_minor'],
            'expected_rate_ppm': fx!['rate_ppm'],
            'expected_fee_minor': fx!['fee_minor'],
          },
        })));
      if (!mounted) return;
      final item = result['deposit'];
      if (item is! Map || item['id'] == null) throw Exception('الخادم لم يرجع رقم طلب الشحن.');
      setState(() {
        _activeDeposit = item.map((k,v) => MapEntry(k.toString(),v));
        _depositStep = 1;
        _depositPassword.clear(); _depositOtp.clear(); _depositReceipt = null;
      });
      await _refresh();
    } catch (error) { _notice(error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _requestDepositOtp() async {
    if (_busy || _activeDeposit?['id'] == null || _depositPassword.text.isEmpty) {
      _notice('أدخل كلمة مرور حسابك أولًا.'); return;
    }
    setState(() => _busy = true);
    try {
      _decode(await http.post(Uri.parse('${ApiService.baseUrl}/wallet/deposits/${_activeDeposit!['id']}/otp'),
          headers: await _headers(), body: jsonEncode({'password':_depositPassword.text})));
      if (!mounted) return;
      setState(() { _depositStep = 2; _depositPassword.clear(); });
      _notice('أرسلنا رمز التحقق إلى بريدك الموثق.');
      await _refresh();
    } catch (error) { _notice(error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _verifyDepositOtp() async {
    if (_busy || _activeDeposit?['id'] == null || !RegExp(r'^\d{6}$').hasMatch(_depositOtp.text.trim())) {
      _notice('أدخل رمز التحقق الصحيح المكوّن من 6 أرقام.'); return;
    }
    setState(() => _busy = true);
    try {
      final result = _decode(await http.post(Uri.parse('${ApiService.baseUrl}/wallet/deposits/${_activeDeposit!['id']}/verify'),
          headers: await _headers(), body: jsonEncode({'otp':_depositOtp.text.trim()})));
      if (!mounted) return;
      final item = result['deposit'];
      if (item is! Map) throw Exception('لم يتم تأكيد رمز التحقق.');
      setState(() {
        _activeDeposit = {...?_activeDeposit, ...item.map((k,v) => MapEntry(k.toString(),v))};
        _depositOtp.clear(); _depositStep = 3;
      });
      await _refresh();
    } catch (error) { _notice(error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _chooseDepositReceipt() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.custom,
          allowedExtensions: const ['jpg','jpeg','png','webp','pdf']);
      if (file != null && mounted) setState(() => _depositReceipt = file);
    } catch (error) { _notice('تعذر اختيار إشعار التحويل: $error'); }
  }

  Future<void> _sendDepositProof() async {
    if (_busy || _activeDeposit?['id'] == null || _senderName.text.trim().length < 2 || _depositReceipt == null) {
      _notice('اسم المرسل وإشعار التحويل مطلوبان قبل إرسال الطلب للمراجعة.'); return;
    }
    setState(() => _busy = true);
    try {
      final file = _depositReceipt!;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.lengthInBytes > 10 * 1024 * 1024) {
        throw Exception('يجب ألا يزيد حجم الإشعار عن 10MB.');
      }
      final req = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/wallet/deposits/${_activeDeposit!['id']}/proof'));
      req.headers.addAll(await _headers(jsonBody: false));
      req.fields.addAll({'sender_name':_senderName.text.trim(),
        'payment_reference':_paymentReference.text.trim(), 'note':_depositNote.text.trim()});
      req.files.add(http.MultipartFile.fromBytes('receipt',bytes,filename:file.name));
      final result = _decode(await http.Response.fromStream(await req.send()));
      if (!mounted) return;
      final item = result['deposit'];
      setState(() {
        if (item is Map) _activeDeposit = {...?_activeDeposit, ...item.map((k,v) => MapEntry(k.toString(),v))};
        _depositStep = 4; _depositReceipt = null;
      });
      await _refresh();
      _notice('وصل طلب الشحن إلى الإدارة للمراجعة. لم يُضف الرصيد بعد.');
    } catch (error) { _notice(error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(message))));
  }

  Future<void> _submitWithdrawalInformation(Map request) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const TrText('إرسال التوضيح إلى الإدارة المالية'),
      content: TextField(controller:controller, minLines:2,maxLines:5,
        decoration: InputDecoration(labelText:'التوضيح المطلوب دون تغيير المبلغ أو الحساب البنكي'.tr())),
      actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const TrText('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const TrText('إرسال'))],
    ));
    final reply = controller.text.trim();Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (ok == true && reply.length >= 3) await _post('/wallet/withdrawals/${request['id']}/information', {'reply':reply});
  }

  Future<void> _withdraw() async {
    if (_payoutAccountId == null || _amount.text.trim().isEmpty || _otp.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: TrText('اختر حساب الاستلام وأدخل المبلغ ورمز OTP.')));
      return;
    }
    await _post('/wallet/withdrawals', {
      'currency': _currency,
      'amount': _amount.text.trim(),
      'payout_account_id': _payoutAccountId,
      'source_bucket': _withdrawSource,
      'otp': _otp.text.trim(),
    });
    _amount.clear();
    _otp.clear();
  }

  Future<void> _quoteThenPay({required bool consultation}) async {
    if (_busy) return;
    final firstId = int.tryParse(consultation ? _consultationId.text.trim() : _projectId.text.trim());
    final installmentId = consultation ? null : int.tryParse(_installmentId.text.trim());
    if (firstId == null || firstId < 1 || (!consultation && (installmentId == null || installmentId < 1))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: TrText('أدخل رقم الاستشارة أو رقم المشروع والقسط بشكل صحيح.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final quotePath = consultation
          ? '/wallet/quotes/consultations/$firstId'
          : '/wallet/quotes/projects/$firstId/installments/$installmentId';
      final quote = _decode(await http.get(Uri.parse('${ApiService.baseUrl}$quotePath'), headers: await _headers()));
      if (!mounted) return;
      if ((num.tryParse(quote['wallet_available']?.toString()??'')??0) < (num.tryParse(quote['amount']?.toString()??'')??0)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: TrText('الرصيد غير كافٍ؛ اشحن المحفظة وانتظر موافقة الإدارة أولًا.')));
        return;
      }
      final approved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const TrText('تأكيد الدفع من المحفظة'),
        content: Text('${quote['label'] ?? ''}\nالمبلغ النهائي: ${quote['amount']} ${quote['currency']}\nسيُخصم هذا المبلغ من رصيدك عند التأكيد.'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('تأكيد الدفع')),
        ],
      ));
      if (approved != true) return;
      final payPath = consultation
          ? '/wallet/consultations/$firstId/pay'
          : '/wallet/projects/$firstId/installments/$installmentId/pay';
      final result = _decode(await http.post(Uri.parse('${ApiService.baseUrl}$payPath'),
        headers: await _headers(), body: jsonEncode({
          'expected_amount': quote['amount'].toString(),
          'expected_currency': quote['currency'].toString(),
        })));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(result['message']?.toString() ?? 'تم الدفع.'))));
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _purchaseKey(String value) => _packageRequestKeys.putIfAbsent(value, () {
    final random = Random.secure();
    return List.generate(24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  });

  Future<void> _buyPackage(String type, int planId, String title) async {
    if (_busy) return;
    if (_data['live'] != true) {
      _notice('خدمة الدفع بالمحفظة معطّلة حاليًا من الخادم؛ لا يمكن خصم الرصيد قبل تفعيل النظام المالي بأمان.');
      return;
    }
    // The quote endpoint also enforces this on the server when a screen is stale.
    try {
      final packages = _decode(await http.get(
        Uri.parse('${ApiService.baseUrl}/wallet/packages'), headers: await _headers()));
      if ((packages['plans'] as List? ?? const []).whereType<Map>().any((p) =>
        p['type'].toString() == type && int.tryParse('${p['id']}') == planId && p['is_current_plan'] == true)) {
        _notice('أنت داخل الخطة بالفعل؛ اختر باقة أخرى للترقية.');
        return;
      }
    } catch (_) { /* Server-side quote remains authoritative if listing is unavailable. */ }
    String coupon = '';
    String cycle = 'monthly';
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, redraw) => AlertDialog(
        title: TrText('شراء باقة $title من المحفظة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(trUi(type=='ai'?'خصم الباقة من المحفظة وتفعيلها في رصيد AI الحالي.':'يلزم إكمال متطلبات وتوثيق المكتب أو المهندس في المنصة قبل الشراء.')),
          if (type == 'office') DropdownButton<String>(value:cycle,
            items:const [DropdownMenuItem(value:'monthly',child:TrText('شهري')),
              DropdownMenuItem(value:'yearly',child:TrText('سنوي'))],
            onChanged:(v)=>redraw(()=>cycle=v??'monthly')),
          TextFormField(initialValue: coupon, onChanged: (value) => coupon = value,
            decoration:InputDecoration(labelText:'كوبون خصم (اختياري)'.tr())),
        ]),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const TrText('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const TrText('عرض السعر النهائي'))],
      ),
    ));
    coupon = coupon.trim();
    if (accepted != true) return;
    setState(()=>_busy=true);
    try {
      final base = '/wallet/packages/$type/$planId';
      final uri=Uri.parse('${ApiService.baseUrl}$base/quote').replace(queryParameters:{
        'cycle':cycle, if(coupon.isNotEmpty)'coupon_code':coupon,
      });
      final quote = _decode(await http.get(uri, headers: await _headers()));
      if (!mounted) return;
      // Use the server's final price + exact configured FX quote; never calculate a local rate.
      final autoFx = quote['auto_fx'] is Map
          ? Map<String, dynamic>.from(quote['auto_fx'] as Map) : <String, dynamic>{};
      final enough = autoFx['available'] == true || quote['wallet_sufficient'] == true;
      final possible = autoFx['possible'] == true && autoFx['enabled'] == true;
      final legs = autoFx['conversions'] is List ? autoFx['conversions'] as List : const [];
      final alternatives = quote['conversion_options'] is List
          ? quote['conversion_options'] as List : const [];
      final choice = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: Text(trUi(enough ? 'تأكيد شراء الباقة' : possible
            ? 'تأكيد التحويل التلقائي وشراء الباقة' : 'الرصيد غير كافٍ بعملة الباقة')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${quote['plan_name']}\nالسعر النهائي: ${quote['amount']} ${quote['currency']}\nالرصيد المتاح بعملة الباقة: ${quote['wallet_available']} ${quote['currency']}'.tr()),
          const SizedBox(height: 12),
          if (enough) const TrText('سيخصم النظام السعر المعروض من رصيد عملة الباقة عند التأكيد.'),
          if (!enough && possible) ...[
            const TrText('سيحوّل النظام رصيدك تلقائيًا من العملة المتاحة إلى عملة الباقة ثم يخصم ثمنها في عملية واحدة بعد موافقتك:'),
            for (final raw in legs) if (raw is Map) Padding(
              padding: const EdgeInsets.only(top: 10), child: Text(
                trUi('${raw['source_amount']} ${raw['source_currency']} ← ${raw['target_amount']} ${raw['target_currency']}\n'
                'سعر الصرف: ${raw['rate']}'
                '${(num.tryParse(raw['fee_minor'].toString()) ?? 0) > 0 ? ' · رسوم فعلية: ${raw['fee_amount']} ${raw['target_currency']}' : ' · دون رسوم إضافية'}'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            const TrText('إذا تغير الرصيد أو سعر الصرف قبل الإتمام، سيلغى الشراء ويطلب منك تأكيد السعر الجديد.'),
          ],
          if (!enough && !possible) ...[
            const TrText('لا يوجد تحويل تلقائي متاح حاليًا. قد يكون أحد أسعار الصرف غير مفعل/منتهيًا، أو لا يكفي الرصيد الإجمالي؛ يمكنك شحن المحفظة أو الانتظار حتى يفعّل المدير المالي سعر الصرف والسيولة المطلوبة.'),
            for (final option in alternatives) if (option is Map) Padding(
              padding: const EdgeInsets.only(top: 8), child: Text(
                '${option['source_amount']} ${option['source_currency']} = ${option['target_amount']} ${option['target_currency']}'),
            ),
          ],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const TrText('إلغاء')),
          if (enough) FilledButton(onPressed: () => Navigator.pop(ctx, 'pay'),
              child: const TrText('تأكيد الشراء')),
          if (!enough && possible) FilledButton(onPressed: () => Navigator.pop(ctx, 'auto_fx'),
              child: const TrText('تأكيد تحويل الرصيد والشراء')),
          if (!enough && !possible && alternatives.isNotEmpty)
            OutlinedButton(onPressed: () => Navigator.pop(ctx, 'exchange'),
                child: const TrText('طلب صرف الرصيد يدويًا')),
        ],
      ));
      if (choice == 'exchange') {
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const WalletFxScreen()));
        return;
      }
      if (choice != 'pay' && choice != 'auto_fx') return;
      final autoFxConfirmed = choice == 'auto_fx';
      if (autoFxConfirmed && (autoFx['digest']?.toString().length != 64)) {
        _notice('تعذر تأكيد عرض الصرف؛ أعد المحاولة.');
        return;
      }
      final key='$type:$planId:$cycle:$coupon';
      final result=_decode(await http.post(Uri.parse('${ApiService.baseUrl}$base/pay'),
        headers: await _headers(), body:jsonEncode({
          'cycle':cycle,'coupon_code':coupon,'expected_amount':quote['amount'].toString(),
          'expected_currency':quote['currency'].toString(),'request_key':_purchaseKey(key),
          'auto_fx_confirmed': autoFxConfirmed,
          if (autoFxConfirmed) 'expected_fx_digest': autoFx['digest'].toString(),
        })));
      _packageRequestKeys.remove(key);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(result['message']?.toString()??'اكتمل شراء الباقة.'))));
      await _refresh();
    }catch(error){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(error.toString()))));}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _browseWalletPackages() async {
    try {
      final result=_decode(await http.get(Uri.parse('${ApiService.baseUrl}/wallet/packages'),headers:await _headers()));
      if(!mounted)return;
      final plans=result['plans'] is List ? result['plans'] as List : const [];
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,
        builder:(sheet)=>SafeArea(child:FractionallySizedBox(heightFactor:.82,child:Column(children:[
          const Padding(padding:EdgeInsets.all(12),child:TrText('الباقات والعروض الموجودة في المنصة',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18))),
          Expanded(child:ListView(children:[for(final p in plans)if(p is Map)
            ListTile(title:Text(trUi(p['name']?.toString()??'')),subtitle:Text(
                trUi(p['is_current_plan'] == true
                  ? '✓ أنت داخل الخطة بالفعل\n${p['description'] ?? ''}'
                  : '${p['description']??''}\n${p['price']} ${p['currency']}')),
              isThreeLine:true,
              trailing: p['is_current_plan'] == true
                  ? const Icon(Icons.verified_rounded, color: Color(0xFF047857))
                  : const Icon(Icons.chevron_left),onTap:(){
                Navigator.pop(sheet);
                if (p['is_current_plan'] == true) {
                  _notice('أنت داخل الخطة بالفعل');
                  return;
                }
                if(p['type']=='ai' && (num.tryParse(p['price']?.toString()??'')??0)<=0){
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:TrText('هذه باقة AI مجانية؛ تستخدم من المساعد دون دفع.')));
                }else{
                  _buyPackage(p['type'].toString(),(p['id'] as num).toInt(),p['name'].toString());
                }
              })])),
          TextButton(onPressed:()=>Navigator.pop(sheet),child:const TrText('إغلاق')),
        ]))));
    }catch(error){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(trUi(error.toString()))));}
  }

  void _browsePackages() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const PackagesOffersScreen(),
    ));
  }

  // V25.14.15: نفس بنية وألوان واجهة المحفظة الرئيسية في الويب.
  // لا نغيّر أي مسار مالي أو منطق شحن/سحب؛ كل القيم تأتي من API.
  Color get _walletBg => _appearanceDark ? const Color(0xFF050813) : const Color(0xFFF0F4FA);
  Color get _walletBorder => _appearanceDark ? const Color(0xFF22355E) : const Color(0xFFC7D4E6);
  static const Color _walletCyan = Color(0xFF0284C7);
  Color get _walletMuted => _appearanceDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
  static const Color _walletGreen = Color(0xFF10B981);
  static const Color _walletAmber = Color(0xFFF59E0B);
  static const Color _walletPurple = Color(0xFF7C3AED);

  bool get _appearanceDark => Theme.of(context).brightness == Brightness.dark;

  BoxDecoration _glassDecoration({bool accent = false}) => BoxDecoration(
    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: _appearanceDark
          ? (accent
              ? const [Color(0xFF13203E), Color(0xFF0C142A)]
              : const [Color(0xFF101A34), Color(0xFF0B1226)])
          : const [Color(0xFFFFFFFF), Color(0xFFF5F8FE)]),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _appearanceDark
        ? (accent ? const Color(0xFF314E89) : const Color(0xFF22355E))
        : (accent ? const Color(0xFF314E89) : _walletBorder)),
  );

  Widget _panel(Widget child,{EdgeInsetsGeometry padding = const EdgeInsets.all(17),
      bool accent = false}) => Container(
    decoration: _glassDecoration(accent: accent),
    padding: padding,
    child: child,
  );

  Widget _section(String title, Widget child) => Padding(
    padding:const EdgeInsets.only(bottom:16),
    child: _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch,children:[
      Text(trUi(title),style:TextStyle(color:(Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),fontSize:17,fontWeight:FontWeight.w800)),
      const SizedBox(height:12), child,
    ])),
  );

  Widget _action(String title, IconData icon, VoidCallback? action) => SizedBox(
    width:double.infinity,
    child: FilledButton.icon(onPressed: action,
      style:FilledButton.styleFrom(backgroundColor:const Color(0xFF35B4D5),
        foregroundColor:const Color(0xFF05101C),disabledBackgroundColor:const Color(0xFFE9F0FA),
        disabledForegroundColor:_walletMuted,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(11)),
        padding:const EdgeInsets.symmetric(vertical:14,horizontal:12)),
      icon:Icon(icon,size:19),label:Text(trUi(title),style:const TextStyle(fontWeight:FontWeight.w800))),
  );

  Widget _moneyField(String label) => TextField(controller:_amount,enabled:!_busy,
    keyboardType:const TextInputType.numberWithOptions(decimal:true),
    decoration:InputDecoration(labelText:trUiN(label)));

  Widget _currencyField() => DropdownButtonFormField<String>(
    key: ValueKey('wallet-deposit-currency-$_currency'), value:_currency,
    dropdownColor:(Theme.of(context).brightness == Brightness.dark ? const Color(0xFF14243A) : Theme.of(context).colorScheme.surface),decoration:InputDecoration(labelText:'العملة'.tr()),
    items:const [DropdownMenuItem(value:'ILS',child:TrText('شيكل ILS')),
      DropdownMenuItem(value:'USD',child:TrText('دولار USD')),
      DropdownMenuItem(value:'JOD',child:TrText('دينار JOD')),
      DropdownMenuItem(value:'SAR',child:TrText('ريال سعودي SAR'))],
    onChanged:_busy ? null : (v)=>setState(() { _currency=v??'ILS'; _paymentMethodId=null;
       if (_view == 'deposit') _cryptoAsset=''; _payoutAccountId=null; }));

  void _beginDeposit() {
    if (_busy) return;
    setState(() {
      _view='deposit'; _depositStep=0; _activeDeposit=null;
      _amount.clear(); _senderName.clear(); _paymentReference.clear(); _depositNote.clear();
      _depositReceipt=null; _paymentMethodId=null; _depositFxQuote=null; _depositFxStamp=null;
      _depositRegion=''; _globalPaymentCategory=''; _cryptoAsset='';
    });
  }

  void _beginWithdrawal() {
    _amount.clear(); _otp.clear(); _openView('withdraw');
  }

  String _moneyFromMinor(dynamic minor,String currency) {
    final amount = minor is num ? minor.toDouble() : double.tryParse('$minor') ?? 0;
    return (amount/(currency=='JOD' ? 1000 : 100)).toStringAsFixed(currency=='JOD' ? 3 : 2);
  }

  Widget _softButton(String title,IconData icon,VoidCallback? onTap,
      {Color color = _walletCyan,bool filled = false}) => SizedBox(
    width:double.infinity,
    child: FilledButton.icon(onPressed:onTap,
      style:FilledButton.styleFrom(
        backgroundColor:filled ? color : color.withValues(alpha:0.13),
        foregroundColor:filled ? const Color(0xFFF0F4FA) : color,
        disabledBackgroundColor:const Color(0xFFE9F0FA),
        disabledForegroundColor:_walletMuted,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(11),
          side:BorderSide(color:filled ? Colors.transparent : color.withValues(alpha:0.33))),
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:14)),
      icon:Icon(icon,size:18),
      label:Text(trUi(title),textAlign:TextAlign.center,
        style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)),
    ),
  );

  Widget _currencyCard(String currency,Map<String,dynamic> balance) {
    final symbol = currency=='ILS' ? '₪' : currency=='USD' ? r'$' : currency=='JOD' ? 'د.أ' : 'ر.س';
    final label = currency=='ILS' ? 'الشيكل' : currency=='USD' ? 'الدولار الأمريكي' : currency=='JOD' ? 'الدينار الأردني' : 'الريال السعودي';
    final color = currency=='ILS' ? _walletCyan : currency=='USD' ? _walletGreen : currency=='JOD' ? _walletAmber : _walletGreen;
    return _panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
          decoration:BoxDecoration(color:color.withValues(alpha:0.11),
            borderRadius:BorderRadius.circular(7),border:Border.all(color:color.withValues(alpha:0.25))),
          child:Text(trUi(currency),style:TextStyle(color:color,fontWeight:FontWeight.w900,letterSpacing:0.5))),
        Flexible(child:Text(trUi(label),style:TextStyle(color:_walletMuted,fontSize:12))),
      ]),
      const SizedBox(height:16),
      FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerRight,
        child:Row(mainAxisSize:MainAxisSize.min,children:[
          Text('${balance['available'] ?? (currency=='JOD'?'0.000':'0.00')}',
            style:TextStyle(color:(Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),fontSize:30,fontWeight:FontWeight.w900)),
          const SizedBox(width:6),
          Text(trUi(symbol),style:TextStyle(color:color,fontSize:20,fontWeight:FontWeight.bold)),
        ])),
      const SizedBox(height:15),
      Divider(color:_appearanceDark ? const Color(0xFF334155) : _walletBorder,height:1),
      const SizedBox(height:10),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        Flexible(child:TrText('مستحقاتي المهنية المتاحة:',style:TextStyle(color:_walletMuted,fontSize:11))),
        Text('${balance['withdrawable'] ?? '0.00'}',style:const TextStyle(color:_walletGreen,fontSize:12,fontWeight:FontWeight.w700)),
      ]),
      const SizedBox(height:7),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        TrText('رصيد محجوز:',style:TextStyle(color:_walletMuted,fontSize:11)),
        Text('${balance['held'] ?? '0.00'}',style:const TextStyle(color:_walletAmber,fontSize:12,fontWeight:FontWeight.w700)),
      ]),
    ]));
  }

  Widget _responsiveCards(List<Widget> children,{int desktopColumns=3}) => LayoutBuilder(
    builder:(context,constraints) {
      final width=constraints.maxWidth;
      final columns=width>=820 ? desktopColumns : width>=580 ? 2 : 1;
      final itemWidth=(width-12*(columns-1))/columns;
      return Wrap(spacing:12,runSpacing:12,
        children:[for (final child in children) SizedBox(width:itemWidth,child:child)]);
    });

  Widget _smallHeading(IconData icon,String title,{Color color=_walletCyan}) =>
      Row(children:[Icon(icon,color:color,size:20),const SizedBox(width:8),
        Flexible(child:Text(trUi(title),style:const TextStyle(fontSize:17,color:Color(0xFF0F172A),
          fontWeight:FontWeight.w800)))]);

  Widget _emptyBox(String title,{IconData icon=Icons.inbox_outlined}) => Container(
    width:double.infinity,padding:const EdgeInsets.symmetric(vertical:28,horizontal:12),
    decoration:BoxDecoration(color:const Color(0xFFFFFFFF),borderRadius:BorderRadius.circular(12),
      border:Border.all(color:const Color(0xFFC7D4E6))),
    child:Column(children:[Icon(icon,color:_walletMuted,size:26),const SizedBox(height:7),
      Text(trUi(title),style:TextStyle(color:_walletMuted,fontSize:12),textAlign:TextAlign.center)]));

  Widget _walletOverview(bool live,Map<String,dynamic> balances) {
    final role=_data['role']?.toString() ?? '';
    final manager=role=='admin' || role=='financial_manager';
    final isTreasury=_data['is_platform_treasury']==true;
    final canWithdraw=true;
    final depositRequests = _data['deposit_requests'] is List ? (_data['deposit_requests'] as List).whereType<Map>().toList() : <Map>[];
    final withdrawalRequests = _data['withdrawal_requests'] is List ? (_data['withdrawal_requests'] as List).whereType<Map>().toList() : <Map>[];
    final transactions = _data['transactions'] is List ? (_data['transactions'] as List).whereType<Map>().toList() : <Map>[];
    final consultations = _data['payable_consultations'] is List ? (_data['payable_consultations'] as List).whereType<Map>().toList() : <Map>[];
    final installments = _data['payable_installments'] is List ? (_data['payable_installments'] as List).whereType<Map>().toList() : <Map>[];
    return RefreshIndicator(onRefresh:_refresh,color:_walletCyan,child:ListView(
      padding:const EdgeInsets.fromLTRB(14,10,14,32),children:[
        // Main header: مطابق للمرجع مع زر مراجعة الإدارة في الحسابات المخولة.
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _smallHeading(Icons.account_balance_wallet_outlined,
              isTreasury ? 'خزينة المنصة — محفظة مدير النظام' : 'محفظة الوليد الهندسية'),
            const SizedBox(height:5),
            TrText(isTreasury
                ? 'حصة المنصة من الاستشارات المدفوعة تُقيد هنا تلقائيًا، بينما حصة مقدم الخدمة تبقى محجوزة حتى اعتماد العميل.'
                : 'الأرصدة المالية منفصلة تمامًا عن Credits الذكاء الاصطناعي.',
              style:TextStyle(color:_walletMuted,fontSize:11)),
          ])),
          if (manager) ...[const SizedBox(width:9),
            Flexible(child:OutlinedButton(onPressed:()=>Navigator.push(context,
              MaterialPageRoute(builder:(_)=>const AlwaleedWalletFinanceScreen())),
              style:OutlinedButton.styleFrom(foregroundColor:_walletCyan,
                side:const BorderSide(color:Color(0xFF246681)),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(11))),
              child:const TrText('مراجعة المحفظة المالية',textAlign:TextAlign.center,
                style:TextStyle(fontSize:11,fontWeight:FontWeight.bold))))],
        ]),
        if (_error!=null) ...[const SizedBox(height:12),_panel(Text(
          trUi(_error!),style:const TextStyle(color:_walletAmber,fontSize:12)))],
        if (!live) ...[const SizedBox(height:12),_panel(const TrText('المحفظة في وضع العرض. لا يمكن تنفيذ شحن أو سحب أو دفع حتى تفعيل التشغيل الآمن على الخادم.',
          style:TextStyle(color:_walletAmber,fontSize:12)))],
        const SizedBox(height:19),
        _responsiveCards([for (final code in const ['ILS','USD','JOD','SAR'])
          _currencyCard(code, balances[code] is Map
            ? Map<String,dynamic>.from(balances[code] as Map) : <String,dynamic>{})]),
        const SizedBox(height:17),
        _panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          _smallHeading(Icons.bolt,'شحن المحفظة بخطوات واضحة'),
          const SizedBox(height:14),
          Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A1426) : Theme.of(context).colorScheme.surface),borderRadius:BorderRadius.circular(10),
            border:Border.all(color:const Color(0xFFC7D4E6))),
            child:const TrText('1. إنشاء طلب الشحن   ←   2. تأكيد كلمة المرور   ←   3. رمز البريد OTP   ←   4. الدفع وإرفاق اسم المرسل وإشعار التحويل   ←   انتظار تأكيد الإدارة.',
              style:TextStyle(color:Color(0xFFB6E6F0),height:1.9,fontSize:12),textAlign:TextAlign.center)),
          const SizedBox(height:13),
          _softButton('ابدأ طلب شحن جديد',Icons.add_circle_outline,_busy ? null : _beginDeposit,filled:true),
          const SizedBox(height:10),
          const TrText('لا يُضاف الرصيد عند رفع الإيصال أو العودة من بوابة الدفع؛ يعتمد فقط بعد مطابقة التحصيل من المدير المالي أو مدير المنصة.',
            style:TextStyle(color:_walletAmber,fontSize:11,height:1.6),textAlign:TextAlign.center),
        ]),accent:true),
        const SizedBox(height:16),
        _panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          _smallHeading(Icons.widgets_outlined,'الخدمات والباقات — من داخل محفظتي',color:const Color(0xFF9C86FF)),
          const SizedBox(height:9),
          TrText('يمكنك إنشاء استشارة، استعراض أقساط المشاريع، ومشاهدة الباقات والعروض الموجودة. للدفع من المحفظة يجب أن يكون رصيدك المعتمد كافيًا بنفس العملة. تعرض صفحة التأكيد السعر الفعلي من الخادم.',
            style:TextStyle(color:_walletMuted,fontSize:12,height:1.6)),
          const SizedBox(height:16),
          _responsiveCards([
            _softButton('تصفح الباقات والعروض',Icons.local_offer_outlined,_browsePackages,color:_walletPurple,filled:true),
            _softButton('مشاريعي',Icons.folder_open_outlined,()=>Navigator.push(context,
              MaterialPageRoute(builder:(_)=>const ProjectsScreen())),color:const Color(0xFF245A7E),filled:true),
            _softButton('إنشاء استشارة',Icons.chat_outlined,() async {
              await Navigator.push(context,MaterialPageRoute(builder:(_)=>const CreateConsultationScreen()));
              if (mounted) _refresh();
            },filled:true),
          ]),
          const SizedBox(height:13),
          _responsiveCards([
            _miniDueBox('الاستشارات التي لم تُدفع',consultations,
              'لا توجد استشارات غير مدفوعة، أنشئ استشارة أولًا.',
              ()=>_openView('payments')),
            _miniDueBox('دفعات المشاريع المستحقة',installments,
              'لا توجد دفعات مستحقة في الوقت الحالي.',
              ()=>_openView('payments')),
          ],desktopColumns:2),
          const SizedBox(height:13),
          TrText('باقات المكتب والمهندس تُشترى من المحفظة بعد استيفاء متطلبات وتوثيق الحساب، وينقل الاشتراك إلى النظام المالي بعد تأكيد الدفع.',
            style:TextStyle(color:_walletMuted,fontSize:11,height:1.5),textAlign:TextAlign.center),
        ])),
        const SizedBox(height:16),
        _responsiveCards([
          _panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[Expanded(child:_smallHeading(Icons.move_to_inbox_outlined,'طلبات الإيداع')),
              TrText('${depositRequests.length} طلب',style:TextStyle(color:_walletMuted,fontSize:11))]),
            const SizedBox(height:12),
            if(depositRequests.isEmpty) _emptyBox('لا توجد طلبات إيداع حاليًا')
            else for(final request in depositRequests) Padding(
              padding:const EdgeInsets.only(bottom:10),child:_depositTicket(request)),
            _softButton('طلب شحن جديد',Icons.add,_busy?null:_beginDeposit),
          ])),
          _panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            _smallHeading(Icons.outbox_outlined,'طلبات السحب',color:const Color(0xFF6D28D9)),
            const SizedBox(height:12),
            if(withdrawalRequests.isEmpty) _emptyBox('لا توجد طلبات سحب حاليًا')
            else for(final request in withdrawalRequests) Padding(
              padding:const EdgeInsets.only(bottom:9),child:_withdrawTicket(request)),
            const SizedBox(height:6),
            if(canWithdraw) _softButton('طلب سحب جديد',Icons.account_balance_outlined,
              live&&!_busy ? _beginWithdrawal : null,color:const Color(0xFF6D28D9))
            else const SizedBox.shrink(),
            const SizedBox(height:8),
          ])),
        ],desktopColumns:2),
        const SizedBox(height:16),
        _panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          _smallHeading(Icons.receipt_long_outlined,'سجل العمليات',color:_walletMuted),
          const SizedBox(height:12),
          if(transactions.isEmpty) _emptyBox('لا توجد عمليات مالية بعد.',icon:Icons.history)
          else for (final item in transactions) Container(
            padding:const EdgeInsets.symmetric(vertical:10),decoration:const BoxDecoration(
              border:Border(bottom:BorderSide(color:Color(0xFFD9E4F2)))),
            child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${item['purpose']??'حركة مالية'}'.tr(),style:TextStyle(color:(Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),fontSize:12,fontWeight:FontWeight.w700)),
              Text('${item['bucket']??''} • ${item['created_at']??''}',
                style:TextStyle(color:_walletMuted,fontSize:10)),
            ])),const SizedBox(width:8),Text('${item['change']??''} ${item['currency']??''}',
              style:const TextStyle(color:_walletCyan,fontSize:12,fontWeight:FontWeight.w800))])),
        ])),
        const SizedBox(height:14),
        _softButton('صرف الرصيد بين العملات',Icons.currency_exchange,() async {
          await Navigator.push(context,MaterialPageRoute(builder:(_)=>const WalletFxScreen()));
          if (mounted) _refresh();
        }),
      ],
    ));
  }

  Widget _miniDueBox(String title,List<Map> items,String empty,VoidCallback onTap) =>
    InkWell(onTap:items.isNotEmpty ? onTap : null,borderRadius:BorderRadius.circular(11),
      child:Container(padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(color:const Color(0xFFFFFFFF),borderRadius:BorderRadius.circular(11),
          border:Border.all(color:const Color(0xFFC7D4E6))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(trUi(title),style:const TextStyle(color:Color(0xFF0F172A),fontWeight:FontWeight.w800,fontSize:13)),
          const SizedBox(height:6),
          Text(trUi(items.isEmpty ? empty : '${items.length} مستحق • اضغط لعرض تفاصيل الدفع'),
            style:TextStyle(color:items.isEmpty ? _walletMuted : _walletCyan,fontSize:11)),
        ])));

  Widget _depositTicket(Map item) {
    final currency=item['currency']?.toString() ?? 'ILS';
    final status=item['status']?.toString() ?? '';
    final canContinue=const ['draft','otp_sent','awaiting_payment','needs_info','pending'].contains(status);
    return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(
      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A1426) : Theme.of(context).colorScheme.surface),borderRadius:BorderRadius.circular(11),
      border:Border.all(color:const Color(0xFFC7D4E6))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[
          Expanded(child:Text('$currency ${_moneyFromMinor(item['amount_minor'],currency)}',
            style:const TextStyle(color:_walletCyan,fontWeight:FontWeight.w900,fontSize:16))),
          Text(trUi(status),style:TextStyle(color:status=='approved'?_walletGreen:_walletAmber,fontSize:11)),
        ]),
        const SizedBox(height:6),
        SelectableText('${item['reference']??''}',textDirection:TextDirection.ltr,
          style:TextStyle(color:_walletMuted,fontSize:11)),
        const SizedBox(height:5),
        Text('${item['created_at']??''}',style:TextStyle(color:_walletMuted,fontSize:10)),
        if(canContinue) ...[const SizedBox(height:8),
          _softButton(status=='pending'?'عرض الطلب':'أكمل الطلب / إرسال الإثبات',
            Icons.arrow_back,_busy?null:()=>_resumeDeposit(item))],
      ]));
  }

  Widget _withdrawTicket(Map item) {
    final currency=item['currency']?.toString() ?? 'ILS';
    final status=item['status']?.toString() ?? '';
    return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(
      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A1426) : Theme.of(context).colorScheme.surface),borderRadius:BorderRadius.circular(11),
      border:Border.all(color:const Color(0xFFC7D4E6))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('$currency ${_moneyFromMinor(item['amount_minor'],currency)}',
          style:TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),fontWeight:FontWeight.w800,fontSize:15)),
        const SizedBox(height:5),
        Text('${item['reference']??''} • ${status=='completed'?'تم السحب بنجاح':status=='approved'?'معتمد — بانتظار التحويل':status=='pending'?'قيد مراجعة الإدارة المالية':status}'.tr(),style:TextStyle(color:_walletMuted,fontSize:11)),
        if(status=='needs_info') ...[const SizedBox(height:8),
          _softButton('إرسال المعلومات المطلوبة',Icons.mark_email_read_outlined,
            _busy ? null : ()=>_submitWithdrawalInformation(item))],
      ]));
  }

  Widget _depositWizard(bool live,List methods) {
    final deposit=_activeDeposit;
    final titles=<String>['طلب الشحن'.tr(),'تأكيد كلمة المرور'.tr(),'رمز البريد الإلكتروني'.tr(),'الدفع وإشعار التحويل'.tr(),'بانتظار مراجعة الإدارة'.tr()];
    final int step=_depositStep < 0 ? 0 : (_depositStep > 4 ? 4 : _depositStep);
    final selected=methods.where((m)=>m is Map && m['id']==_paymentMethodId).toList();
    // Region -> global category -> administrator-defined crypto asset -> payment method.
    // Never display an unavailable or wrong-currency method as selectable.
    final configuredMethods = methods.whereType<Map>().where((method) =>
        int.tryParse('${method['id']}') != null && method['available'] == true &&
        method['type'] != 'crypto' && // Existing crypto records stay readable; no NEW manual payment.
        (method['currency']?.toString().trim().toUpperCase() == _currency ||
        (_data['deposit_fx_enabled'] == true && method['cross_currency_eligible'] == true))).toList();
    final categoryMethods = configuredMethods.where((method) {
      if (method['country_code']?.toString() != _depositRegion) return false;
      if (_depositRegion != 'GL') return true;
      final digital = method['type'] == 'crypto';
      if (_globalPaymentCategory == 'crypto') {
        return digital && method['crypto_asset']?.toString() == _cryptoAsset;
      }
      return _globalPaymentCategory == 'other' && !digital;
    }).toList();
    final cryptoAssets = configuredMethods.where((method) =>
        method['country_code'] == 'GL' && method['type'] == 'crypto' &&
        (method['crypto_asset']?.toString().isNotEmpty ?? false))
        .map((method) => method['crypto_asset'].toString()).toSet().toList()..sort();
    final showMethods = _depositRegion.isNotEmpty && _globalPaymentCategory != 'crypto' &&
        (_depositRegion != 'GL' || _globalPaymentCategory == 'other');
    final bank = _data['bank_instructions'];
    final rawCrypto=deposit?['crypto_snapshot'];
    Map<String,dynamic>? crypto;
    if(rawCrypto is Map) crypto=rawCrypto.map((k,v)=>MapEntry(k.toString(),v));
    if(rawCrypto is String && rawCrypto.trim().isNotEmpty) {
      try { final decoded=jsonDecode(rawCrypto); if(decoded is Map) crypto=decoded.map((k,v)=>MapEntry(k.toString(),v)); }
      catch (_) { /* Existing non-crypto deposits do not have a snapshot. */ }
    }
    final selectedMethod=selected.isEmpty ? null : selected.first;
    if(crypto==null && selectedMethod is Map && selectedMethod['type']=='crypto') {
      crypto={'asset':selectedMethod['crypto_asset'], 'network':selectedMethod['crypto_network'],
        'address':selectedMethod['crypto_address']};
    }
    return ListView(padding:const EdgeInsets.all(16),children:[
      _section('شحن المحفظة — الخطوة ${step+1} من 5',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(trUi(titles[step]),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        LinearProgressIndicator(value:(step+1)/5),
        const SizedBox(height:12),
        if(deposit!=null) TrText('رقم الطلب: ${deposit['reference']??deposit['id']}',style:const TextStyle(color:Color(0xFF0E7490))),
        if (!live) const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: TrText('طلب الشحن معطّل على الخادم حاليًا؛ يمكنك معاينة الخطوات، لكن إنشاء الطلب لن يعمل حتى اعتماد تشغيل المحفظة ماليًا.',
            style: TextStyle(color: Color(0xFF92400E))),
        ),
        if(step==0) ...[
          const TrText('أنشئ الطلب أولًا. لن تحتاج إدخال كلمة المرور أو OTP إلا بعد حفظه.'),
          const SizedBox(height:12),_currencyField(),
          const SizedBox(height:12),_moneyField('مبلغ الدفع (بعملة وسيلة الدفع)'),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            key: ValueKey('wallet-deposit-region-$_depositRegion'),
            value: _depositRegion.isEmpty ? null : _depositRegion,
            isExpanded: true,
            dropdownColor: const Color(0xFFF4F7FB),
            decoration: InputDecoration(labelText: 'المنطقة / فئة الدفع'.tr()),
            items: const [
              DropdownMenuItem(value:'PS', child:TrText('فلسطين')),
              DropdownMenuItem(value:'SA', child:TrText('السعودية')),
              DropdownMenuItem(value:'GL', child:TrText('طرق دفع عالمية')),
            ],
            onChanged: _busy ? null : (value) => setState(() {
              _depositRegion = value ?? '';
              _globalPaymentCategory = '';
              _cryptoAsset = '';
              _paymentMethodId = null;
            }),
          ),
          if (_depositRegion == 'GL') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('wallet-global-category-$_globalPaymentCategory'),
              value: _globalPaymentCategory.isEmpty ? null : _globalPaymentCategory,
              isExpanded:true,
              dropdownColor: const Color(0xFFF4F7FB),
              decoration: InputDecoration(labelText: 'قسم طرق الدفع العالمية'.tr()),
              items: const [
                DropdownMenuItem(value:'other', child:TrText('وسائل الدفع العالمية الأخرى')),
              ],
              onChanged: _busy ? null : (value) => setState(() {
                _globalPaymentCategory = value ?? '';
                _cryptoAsset = '';
                _paymentMethodId = null;
                if (_globalPaymentCategory == 'crypto') {
                  _currency = 'USD'; // Existing wallet crypto settlement is USD only.
                  _payoutAccountId = null;
                }
              }),
            ),
          ],
          if (showMethods) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('wallet-deposit-method-$_depositRegion-$_currency-$_cryptoAsset'),
              value: categoryMethods.any((method) => int.tryParse('${method['id']}') == _paymentMethodId)
                  ? _paymentMethodId : null,
              isExpanded: true,
              dropdownColor: const Color(0xFFF4F7FB),
              menuMaxHeight: MediaQuery.of(context).size.height * 0.55,
              decoration: InputDecoration(labelText: 'طريقة الدفع / الشبكة'.tr()),
              items: categoryMethods.map<DropdownMenuItem<int>>((method) {
                final title = method['type'] == 'crypto'
                    ? '${method['label']} — ${method['crypto_network'] ?? ''}'
                    : '${method['label']} — ${method['currency'] ?? _currency}';
                return DropdownMenuItem<int>(
                  value:int.parse('${method['id']}'),
                  child:Text(trUi(title), maxLines:1, overflow:TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _busy ? null : (id) => setState(() { _paymentMethodId = id;
                _depositFxQuote = null; _depositFxStamp = null; }),
            ),
            if (categoryMethods.isEmpty) const Padding(
              padding: EdgeInsets.only(top:8),
              child:TrText('لا توجد طريقة دفع مفعّلة لهذه المنطقة والفئة والعملة. للشحن من السعودية اختر رصيد SAR، وبعد اعتماده يمكنك تحويله بوجود سعر صرف وسيولة.',
                style:TextStyle(color:Color(0xFF92400E), fontSize:12))),
          ],
          if (_needsCrossDepositQuote()) ...[
            const SizedBox(height:12),
            TrText('عملة وسيلة الدفع مختلفة عن عملة الرصيد؛ هذا الشحن يحتاج سعر صرف معتمدًا وسيولة خزينة متاحة.',
                style: TextStyle(color: _walletMuted)),
            const SizedBox(height:8),
            _action('احسب سعر الصرف والرسوم', Icons.currency_exchange,
                _busy ? null : _previewDepositFx),
            if (_depositFxQuote != null && _depositFxStamp == _currentDepositFxStamp())
              Padding(padding:const EdgeInsets.only(top:8), child: TrText('ستدفع ${_depositFxQuote!['payment_amount']} ${_depositFxQuote!['payment_currency']}، '
                'ويضاف بعد التحقق ${_depositFxQuote!['wallet_credit_amount']} ${_depositFxQuote!['wallet_currency']}؛ '
                'السعر ${_depositFxQuote!['rate']}، الرسوم ${_depositFxQuote!['fee_amount']} ${_depositFxQuote!['wallet_currency']}.',
                style:const TextStyle(fontWeight:FontWeight.w700))),
          ],
          const SizedBox(height:12),
          TextField(controller:_senderName,enabled:!_busy,
            decoration:InputDecoration(labelText:'اسم مرسل التحويل'.tr())),
          const SizedBox(height:16),_action('إنشاء طلب الشحن والمتابعة',Icons.arrow_forward,
            _busy ? null : (live ? _createDepositDraft : () => _notice(
              'لا يمكن إنشاء طلب الشحن الآن: المحفظة معطلة ماليًا على الخادم حتى اكتمال اختبار الدفع والتسوية.'))),
        ] else if(step==1) ...[
          const TrText('تأكيد كلمة مرور حسابك. لا تُرسلها بالبريد أو لموظف الدعم.'),
          const SizedBox(height:12),
          TextField(controller:_depositPassword,enabled:!_busy,obscureText:true,
            decoration:InputDecoration(labelText:'كلمة المرور'.tr())),
          const SizedBox(height:16),_action('تأكيد كلمة المرور وإرسال OTP',Icons.lock_outline,
            live&&!_busy ? _requestDepositOtp : null),
        ] else if(step==2) ...[
          const TrText('أدخل الرمز المرسل إلى بريد حسابك الموثق؛ مدة صلاحية الرمز 5 دقائق.'),
          const SizedBox(height:12),
          TextField(controller:_depositOtp,enabled:!_busy,maxLength:6,
            keyboardType:TextInputType.number,
            decoration:InputDecoration(labelText:'رمز البريد الإلكتروني (6 أرقام)'.tr())),
          _action('تحقق من الرمز وانتقل للدفع',Icons.verified_outlined,
            live&&!_busy ? _verifyDepositOtp : null),
          TextButton(onPressed:_busy ? null : ()=>setState(()=>_depositStep=1),
            child:const TrText('لم يصلني الرمز — إعادة التأكيد بكلمة المرور')),
        ] else if(step==3) ...[
          const TrText('بعد إتمام التحويل عبر وسيلة الدفع المختارة، أرفق إشعار التحويل ثم أرسل الطلب للمراجعة.'),
          const SizedBox(height:8),
          if(selected.isNotEmpty) TrText('طريقة الدفع: ${selected.first['label']} — ${selected.first['currency'] ?? ''}'),
          if (deposit?['payment_currency'] != null) TrText('حوّل ${_moneyFromMinor(deposit!['payment_amount_minor'], '${deposit['payment_currency']}')} ${deposit['payment_currency']} فقط؛ '
            'رصيد محفظتك بعد التحقق ${_moneyFromMinor(deposit['amount_minor'], '${deposit['currency']}')} ${deposit['currency']}.',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          if (selected.isNotEmpty && selected.first['flow']=='manual') ...[
            if ((selected.first['provider_name']?.toString()??'').isNotEmpty) TrText('الجهة: ${selected.first['provider_name']}'),
            if ((selected.first['account_name']?.toString()??'').isNotEmpty) TrText('المستفيد: ${selected.first['account_name']}'),
            if ((selected.first['iban']?.toString()??'').isNotEmpty) SelectableText('IBAN: ${selected.first['iban']}'),
            if ((selected.first['account_number']?.toString()??'').isNotEmpty) SelectableText('الحساب: ${selected.first['.tr()account_number']}'.tr()),
            if ((selected.first['phone']?.toString()??'').isNotEmpty) SelectableText('رقم المحفظة: ${selected.first['.tr()phone']}'.tr()),
            if ((selected.first['instructions']?.toString()??'').isNotEmpty) Text('${selected.first['instructions']}'),
          ],
          if(crypto!=null) ...[
            const SizedBox(height:8),
            TrText('تحويل رقمي: ${crypto['asset']??'—'} على شبكة ${crypto['network']??'—'}',
              style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF0E7490))),
            SelectableText(trUi(crypto['address']?.toString()??''),
              style:const TextStyle(fontFamily:'monospace',fontSize:13)),
            const TrText('حوّل إلى العنوان والشبكة المحددين لهذا الطلب فقط. أدخل TX Hash الحقيقي وأرفق إثبات التحويل. لن يُضاف الرصيد قبل التأكد من استلامه وموافقة الإدارة.',
              style:TextStyle(color:Color(0xFF92400E))),
            const SizedBox(height:8),
          ],
          const SizedBox(height:10),
          if((deposit?['checkout_url']?.toString()??'').startsWith('https://') ||
             (deposit?['checkout_url']?.toString()??'').startsWith('http://'))
            _action('فتح طريقة الدفع المختارة',Icons.open_in_new,()=>launchUrl(
              Uri.parse(deposit!['checkout_url'].toString()),mode:LaunchMode.externalApplication)),
          const SizedBox(height:12),
          TextField(controller:_senderName,decoration:InputDecoration(labelText:'اسم مرسل التحويل'.tr())),
          const SizedBox(height:12),
          TextField(controller:_paymentReference,decoration:InputDecoration(labelText:trUiN(crypto!=null?'معرف المعاملة على الشبكة TX Hash (إلزامي)':'رقم عملية الدفع أو مرجع الحوالة (اختياري)'))),
          const SizedBox(height:12),
          TextField(controller:_depositNote,minLines:1,maxLines:3,
            decoration:InputDecoration(labelText:'ملاحظات أو توضيح (اختياري)'.tr())),
          const SizedBox(height:10),
          OutlinedButton.icon(onPressed:_busy ? null : _chooseDepositReceipt,
            icon:const Icon(Icons.attach_file),
            label:Text(trUi(_depositReceipt==null?'إرفاق إشعار التحويل (صورة أو PDF)':_depositReceipt!.name))),
          const SizedBox(height:16),
          _action('إرسال إثبات الدفع للمراجعة',Icons.send_outlined,
            live&&!_busy ? _sendDepositProof : null),
        ] else ...[
          const Icon(Icons.hourglass_top_rounded,color:Color(0xFF0E7490),size:45),
          const SizedBox(height:10),
          const TrText('تم تقديم طلب الشحن. الرصيد لا يضاف إلا بعد مراجعة التحصيل وموافقة المدير المالي أو مدير المنصة.',textAlign:TextAlign.center),
          const SizedBox(height:12),
          _action('العودة إلى محفظتي',Icons.wallet_outlined,()=>_openView('overview')),
        ],
      ])),
    ]);
  }

  Widget _withdrawPage(bool live,List accounts) => ListView(padding:const EdgeInsets.all(16),children:[
    _section('سحب رصيد محفظتي أو مستحقاتي',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const TrText('رصيد المحفظة الشخصي يُسحب لحسابك الشخصي المعتمد؛ مستحقات المهندسين والمكاتب تُسحب من رصيد المستحقات لحساب الاستلام الخاص بها. السحب يتطلب التوثيق ومراجعة الإدارة المالية.'),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(value:_withdrawSource, isExpanded:true,
        decoration:InputDecoration(labelText:'مصدر الأموال المراد سحبها'.tr()),
        items:[const DropdownMenuItem(value:'available',child:TrText('رصيد محفظتي الشخصي')),
          if (_data['role']=='engineer' || _data['role']=='office_owner')
            const DropdownMenuItem(value:'earnings_available',child:TrText('مستحقاتي المعتمدة'))],
        onChanged:_busy?null:(v)=>setState((){_withdrawSource=v??'available';_payoutAccountId=null;})),
      const SizedBox(height:12),
      OutlinedButton.icon(icon:const Icon(Icons.account_balance),
        onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>
          PayoutAccountScreen(officeAccount:_withdrawSource=='earnings_available' && _data['role']=='office_owner'))).then((_)=>_refresh()),
        label:Text(trUi(_withdrawSource=='available'?'بيانات حساب استلام رصيدي الشخصي':'بيانات حساب استلام المستحقات'))),
      const SizedBox(height:12),_currencyField(),
      const SizedBox(height:12),_moneyField('المبلغ المطلوب سحبه'),
      const SizedBox(height:12),
      DropdownButtonFormField<int>(value:_payoutAccountId,isExpanded:true,
        decoration:InputDecoration(labelText:'اختر حساب الاستلام المعتمد'.tr()),
        items:accounts.where((a)=>a is Map && a['is_verified']==true && a['currency']==_currency
          && (_withdrawSource=='available' ? a['office_id']==null : (_data['role']=='office_owner' ? a['office_id']!=null : a['office_id']==null)))
          .map<DropdownMenuItem<int>>((a)=>DropdownMenuItem(value:(a['id'] as num).toInt(),
            child:Text(trUi(a['account_type']=='crypto' ? '${a['crypto_asset']??''}/${a['crypto_network']??''} — ${a['crypto_address_masked']??''}' : '${a['beneficiary_name']??'حساب'} — ${a['currency']}'),overflow:TextOverflow.ellipsis))).toList(),
        onChanged:_busy ? null : (v)=>setState(()=>_payoutAccountId=v)),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:live&&!_busy ? ()=>_post('/wallet/withdrawals/otp',const {}) : null,
        icon:const Icon(Icons.mail_outline),label:const TrText('إرسال رمز سحب OTP إلى بريدي')),
      const SizedBox(height:8),
      TextField(controller:_otp,enabled:!_busy,keyboardType:TextInputType.number,maxLength:6,
        decoration:InputDecoration(labelText:'رمز السحب (6 أرقام)'.tr())),
      _action('تقديم طلب السحب للمراجعة',Icons.account_balance_wallet_outlined,
        live&&!_busy ? _withdraw : null),
    ])),
  ]);

  Widget _paymentsPage(bool live) => ListView(padding:const EdgeInsets.all(16),children:[
    _section('الدفع من المحفظة',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const TrText('يمكن الدفع بعد شحن الرصيد واعتماد المدير المالي أو مدير المنصة. يُعرض المبلغ النهائي قبل أي خصم.'),
      const SizedBox(height:12),
      _action('إنشاء استشارة',Icons.add_circle_outline,()async{
        await Navigator.push(context,MaterialPageRoute(builder:(_)=>const CreateConsultationScreen()));
        if(mounted) _refresh();
      }),
      const SizedBox(height:10),
      _action('مشاريعي',Icons.apartment_outlined,()=>Navigator.push(context,
        MaterialPageRoute(builder:(_)=>const ProjectsScreen()))),
      const SizedBox(height:10),
      _action('تصفح الباقات والعروض',Icons.local_offer_outlined,_browsePackages),
      const SizedBox(height: 10),
      _action('شراء باقة من رصيد المحفظة', Icons.account_balance_wallet_outlined,
          _browseWalletPackages),
    ])),
    _section('استشارات بانتظار الدفع',Column(children:[
      for(final item in (_data['payable_consultations'] is List?_data['payable_consultations'] as List:const []))
        if(item is Map) ListTile(title:Text(trUi(item['title']?.toString()??'استشارة')),
          subtitle:Text('${item['final_price']} ${item['currency'] ?? 'ILS'}'),
          trailing:TextButton(onPressed:live&&!_busy ? (){
            _consultationId.text=item['id'].toString();_quoteThenPay(consultation:true);
          }:null,child:const TrText('دفع من المحفظة'))),
    ])),
    _section('دفعات المشاريع المستحقة',Column(children:[
      for(final item in (_data['payable_installments'] is List?_data['payable_installments'] as List:const []))
        if(item is Map) ListTile(title:TrText('مشروع ${item['project_id']} — قسط ${item['id']}'),
          subtitle:Text('${item['amount']} ${item['currency']}'),
          trailing:TextButton(onPressed:live&&!_busy ? (){
            _projectId.text=item['project_id'].toString();_installmentId.text=item['id'].toString();
            _quoteThenPay(consultation:false);
          }:null,child:const TrText('تسديد'))),
    ])),
  ]);

  @override
  Widget build(BuildContext context) {
    final live=_data['live']==true;
    final balances=_data['balances'] is Map ? Map<String,dynamic>.from(_data['balances'] as Map):<String,dynamic>{};
    final methods=_data['payment_methods'] is List ? _data['payment_methods'] as List:const [];
    final accounts=_data['payout_accounts'] is List ? _data['payout_accounts'] as List:const [];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF050813) : _walletBg;
    final card = dark ? const Color(0xFF0D1B31) : const Color(0xFFFFFFFF);
    return Theme(data: Theme.of(context).copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: dark ? const Color(0xFF00D2FF) : _walletCyan,
          surface: dark ? const Color(0xFF101A34) : card),
      inputDecorationTheme: InputDecorationTheme(
        filled:true,fillColor: dark ? const Color(0xFF0B1427) : const Color(0xFFF0F4FA),
        labelStyle:TextStyle(color: dark ? const Color(0xFF94A3B8) : _walletMuted),
        hintStyle:TextStyle(color: dark ? const Color(0xFF94A3B8) : _walletMuted),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),
          borderSide:BorderSide(color:dark ? const Color(0xFF22355E) : _walletBorder)),
        focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),
          borderSide:BorderSide(color:dark ? const Color(0xFF00D2FF) : _walletCyan)),
      ),
    ),child: Scaffold(
      backgroundColor:bg,
      appBar:AppBar(backgroundColor:bg,
        leading:_view=='overview' ? null : IconButton(icon:const Icon(Icons.arrow_back),onPressed:()=>_openView('overview')),
        title:Text(trUi(_view=='deposit'?'شحن محفظتي':_view=='withdraw'?'طلب سحب الأموال':_view=='payments'?'الدفع من محفظتي':'محفظتي'),style:TextStyle(fontWeight:FontWeight.w800,color:(Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface))),
        actions:[IconButton(onPressed:_loading ? null : _refresh,icon:const Icon(Icons.refresh_rounded))]),
      body:_loading ? const Center(child:CircularProgressIndicator())
        : _error!=null && _data.isEmpty ? Center(child:Padding(
            padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(trUi(_error!),textAlign:TextAlign.center),
            const SizedBox(height:14),OutlinedButton.icon(onPressed:_refresh,
              icon:const Icon(Icons.refresh),label:const TrText('إعادة المحاولة'))])))
        : _view=='deposit' ? _depositWizard(live,methods)
        : _view=='withdraw' ? _withdrawPage(live,accounts)
        : _view=='payments' ? _paymentsPage(live)
        : _walletOverview(live,balances),
    ));
  }
}
