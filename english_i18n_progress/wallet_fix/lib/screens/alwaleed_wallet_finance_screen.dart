import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';
import 'wallet_fx_finance_screen.dart';

/// Wallet-only finance queue. Existing payment dashboards are unchanged.
class AlwaleedWalletFinanceScreen extends StatefulWidget {
  const AlwaleedWalletFinanceScreen({super.key, this.initialQueue = 'deposits'});
  final String initialQueue;

  @override
  State<AlwaleedWalletFinanceScreen> createState() => _AlwaleedWalletFinanceScreenState();
}

class _AlwaleedWalletFinanceScreenState extends State<AlwaleedWalletFinanceScreen> {
  Map<String, dynamic> _data = {};
  String? _error;
  bool _loading = true;
  bool _busy = false;
  String _queue = 'deposits';
  DateTime _reportFrom = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _reportTo = DateTime.now();
  String _reportCurrency = '';
  bool _exportBusy = false;

  Future<Map<String, String>> _headers() async {
    final token = await ApiService.getAuthToken();
    if (token == null || token.isEmpty) throw Exception('يجب تسجيل الدخول.'.tr());
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json', 'Content-Type': 'application/json'};
  }

  Map<String, dynamic> _decoded(http.Response response) {
    dynamic body;
    try { body = jsonDecode(utf8.decode(response.bodyBytes)); }
    catch (_) { throw Exception('تعذر قراءة استجابة المحفظة (${response.statusCode}).'.tr()); }
    if (body is! Map) throw Exception('استجابة غير صالحة.'.tr());
    final result = Map<String, dynamic>.from(body);
    if (response.statusCode >= 400) throw Exception(result['message']?.toString() ?? 'تعذرت العملية.'.tr());
    return result;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {_loading = true; _error = null;});
    try {
      final response = await http.get(Uri.parse('${ApiService.baseUrl}/wallet/finance'), headers: await _headers());
      final result = _decoded(response);
      if (mounted) setState(() {_data = result; _loading = false;});
    } catch (e) {
      if (mounted) setState(() {_error = e.toString(); _loading = false;});
    }
  }

  @override
  void initState() { super.initState(); _queue = widget.initialQueue; _refresh(); }

  Future<void> _openDepositReceipt(Map deposit) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/wallet/deposits/${deposit['id']}/receipt'),
        headers: await _headers(),
      );
      if (response.statusCode != 200) {
        final message = switch (response.statusCode) {
          401 => 'انتهت جلسة الدخول. سجل الدخول مجددًا لتنزيل الإيصال.'.tr(),
          403 => 'ليس لديك صلاحية عرض إيصال هذا الطلب.'.tr(),
          404 => 'الإيصال غير موجود في تخزين السيرفر. يلزم مراجعة ملف الطلب ونسخة التخزين الاحتياطية.'.tr(),
          _ => 'تعذر تنزيل الإيصال من السيرفر (HTTP ${response.statusCode}).'.tr(),
        };
        throw Exception(message);
      }
      // Never save an HTML login/error page as a PDF. Trust the file signature,
      // not the receipt_path provided by the untrusted response payload.
      final bytes = response.bodyBytes;
      final isPdf = bytes.length > 4 &&
          bytes[0] == 0x25 && bytes[1] == 0x50 &&
          bytes[2] == 0x44 && bytes[3] == 0x46;
      final isJpg = bytes.length > 3 && bytes[0] == 0xFF &&
          bytes[1] == 0xD8 && bytes[2] == 0xFF;
      final isPng = bytes.length > 8 && bytes[0] == 0x89 &&
          bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
      final isWebp = bytes.length > 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      final extension = isPdf ? 'pdf' : isJpg ? 'jpg' :
          isPng ? 'png' : isWebp ? 'webp' : null;
      if (extension == null) {
        throw Exception('السيرفر لم يرجع ملف إيصال صالحًا؛ تحقق من مسار الملف وصلاحية التنزيل.'.tr());
      }
      final directory = await getTemporaryDirectory();
      final local = File('${directory.path}/wallet-receipt-${deposit['id']}.$extension');
      await local.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(local.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(trUi(e.toString().replaceFirst('Exception: ', ''))),
          duration: const Duration(seconds: 7),
        ));
      }
    }
  }

  Future<void> _review(String path, Map<String, dynamic> payload) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await http.post(Uri.parse('${ApiService.baseUrl}$path'),
        headers: await _headers(), body: jsonEncode(payload));
      final json = _decoded(res);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(json['message']?.toString() ?? 'تم حفظ المراجعة.'.tr())));
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _form(String path, {required String title, required bool requiresRef,
    required bool verifyBank, required bool reason, bool approvalOtp = false,
    bool requestInfo = false, bool verifyCrypto = false,
    String defaultEmail = '', String? paymentCurrency, String? expectedPaymentAmount}) async {
    if (!mounted) return;
    // Field controllers belong to the dialog State. Disposing them immediately
    // after showDialog returns races with the route's reverse transition.
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _WalletFinanceReviewDialog(
        path: path,
        title: title,
        requiresRef: requiresRef,
        verifyBank: verifyBank,
        reason: reason,
        approvalOtp: approvalOtp,
        requestInfo: requestInfo,
        verifyCrypto: verifyCrypto,
        defaultEmail: defaultEmail,
        paymentCurrency: paymentCurrency, expectedPaymentAmount: expectedPaymentAmount,
      ),
    );
    if (!mounted) return;
    if (payload != null) await _review(path, payload);
  }

  String _payoutLabel(Map item) {
    final raw = item['payout_label'];
    Map<String,dynamic> details = {};
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) details = Map<String,dynamic>.from(decoded);
    } catch (_) {}
    if (details['type'] == 'crypto') {
      return '${details['name'] ?? ''} • ${details['crypto_asset'] ?? ''} / ${details['crypto_network'] ?? ''} • ${details['crypto_address_masked'] ?? '—'}';
    }
    return '${details['name'] ?? ''} • ${details['bank'] ?? details['type'] ?? ''} • '
        '${details['iban_masked'] ?? details['account_number_masked'] ?? ''}';
  }

  Color get _bg => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF071426) : const Color(0xFFF5F8FE);
  Color get _panel => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0D1B31) : const Color(0xFFFFFFFF);
  Color get _card => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF131D33) : const Color(0xFFFFFFFF);
  Color get _edge => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF263447) : const Color(0xFFE9F0FA);
  Color get _muted => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static const _cyan = Color(0xFF0284C7);
  static const _green = Color(0xFF10B981);
  static const _rose = Color(0xFFF43F5E);
  static const _amber = Color(0xFFF59E0B);
  static const _indigo = Color(0xFF818CF8);

  String _fmtMoney(dynamic minor, String currency) {
    final value = (minor is num ? minor : num.tryParse('$minor') ?? 0).toDouble() /
        (currency == 'JOD' ? 1000 : 100);
    final places = currency == 'JOD' ? 3 : 2;
    final fixed = value.toStringAsFixed(places).split('.');
    final digits = fixed[0];
    final b = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      b.write(digits[i]);
      if ((digits.length - i - 1) % 3 == 0 && i < digits.length - 1) b.write(',');
    }
    return '${b.toString()}.${fixed[1]}';
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _reportFrom : _reportTo,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _cyan),
          dialogTheme: DialogThemeData(backgroundColor: Theme.of(ctx).colorScheme.surface),
        ),
        child: child!,
      ),
    );
    if (selected != null && mounted) {
      setState(() { if (from) { _reportFrom = selected; } else { _reportTo = selected; } });
    }
  }

  Future<void> _exportReport(String format) async {
    if (_exportBusy) return;
    if (_reportFrom.isAfter(_reportTo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('تاريخ البداية يجب أن يسبق تاريخ النهاية.')),
      );
      return;
    }
    setState(() => _exportBusy = true);
    try {
      final url = Uri.parse('${ApiService.baseUrl}/wallet/finance/report/export')
          .replace(queryParameters: {
        'start': _date(_reportFrom), 'end': _date(_reportTo),
        'currency': _reportCurrency, 'format': format,
      });
      final response = await http.get(url, headers: await _headers());
      if (response.statusCode == 429) {
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        throw Exception(retryAfter != null && retryAfter > 0
            ? 'تم تجاوز حد تصدير التقارير مؤقتًا. أعد المحاولة بعد $retryAfter ثانية.'
            : 'طلبات تصدير كثيرة. انتظر قليلًا ثم حاول مرة أخرى.');
      }
      if (response.statusCode == 403) {
        throw Exception('ليس لديك صلاحية تصدير التقرير؛ اطلب من مدير المنصة تفعيل صلاحية تقارير المالية.'.tr());
      }
      if (response.statusCode == 401) {
        throw Exception('انتهت جلسة الدخول. سجّل الدخول مجددًا ثم حاول التصدير.'.tr());
      }
      if (response.statusCode >= 400) {
        throw Exception('تعذر تصدير التقرير (${response.statusCode}). راجع سجلات الخادم.'.tr());
      }
      final mime = response.headers['content-type'] ?? '';
      if (mime.contains('json') || mime.contains('html')) {
        throw Exception('لم يرجع الخادم ملف التقرير. راجع صلاحية التقرير وإعدادات Laravel.'.tr());
      }
      final directory = await getTemporaryDirectory();
      final extension = format == 'pdf' ? 'pdf' : 'csv';
      final local = File('${directory.path}/wallet-report-${_date(_reportFrom)}-${_date(_reportTo)}.$extension');
      await local.writeAsBytes(response.bodyBytes, flush: true);
      await OpenFilex.open(local.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.toString()))));
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  String _receivingDetails(Map w) {
    final d=Map<String,dynamic>.from(w['receiving_details'] as Map);
    return [
      'بيانات التحويل — الإدارة المالية فقط',
      'المستفيد: ${d['beneficiary_name'] ?? ''}',
      'الوسيلة: ${d['account_type'] ?? ''} · ${d['bank_name'] ?? d['payout_provider'] ?? ''}',
      'رقم الحساب: ${d['account_number'] ?? ''}',
      'IBAN: ${d['iban'] ?? ''}',
      'SWIFT: ${d['swift_code'] ?? ''}',
      'PayPal: ${d['paypal_email'] ?? ''}',
      'الفرع: ${d['branch_name'] ?? ''}',
      'العنوان: ${d['beneficiary_address'] ?? ''}',
    ].where((line)=>!line.endsWith(': ')).join('\n');
  }

  Widget _panelBox(Widget child, {EdgeInsets padding = const EdgeInsets.all(16),
      Color? outline, Color? color}) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: (color ?? _panel).withValues(alpha: .86), borderRadius: BorderRadius.circular(17),
      border: Border.all(color: outline ?? (Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: .085) : const Color(0xFFD9E4F2))),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 22, offset: const Offset(0, 8))],
    ),
    child: child,
  );

  Widget _smallText(String text, {Color? color, double size = 12,
    FontWeight weight = FontWeight.w400, TextAlign? align, bool translate = true}) => Text(translate ? trUi(text) : text,
    textAlign: align, style: TextStyle(color: color ?? _muted, fontSize: size, fontWeight: weight, height: 1.55));

  Widget _headerLine(IconData icon, String label, {Color color = _cyan, String? trailing}) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
      Icon(icon, color: color, size: 18), const SizedBox(width: 8),
      Expanded(child: Text(trUi(label), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 16, fontWeight: FontWeight.w800))),
      if (trailing != null) _pill(trailing, color),
    ]));

  Widget _pill(String label, Color foreground, {Color? background}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background ?? foreground.withValues(alpha: .11),
      border: Border.all(color: foreground.withValues(alpha: .25)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(trUi(label), style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _action(String text, IconData icon, VoidCallback? onTap,
      {Color color = _cyan, bool primary = false}) {
    return Opacity(opacity: onTap == null ? .42 : 1, child: Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: primary ? LinearGradient(colors: [color, color.withValues(alpha: .68)]) : null,
            color: primary ? null : color.withValues(alpha: .10),
            border: Border.all(color: primary ? color.withValues(alpha: .4) : color.withValues(alpha: .35)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: primary ? [BoxShadow(color: color.withValues(alpha: .15), blurRadius: 15)] : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: primary ? Colors.white : color), const SizedBox(width: 7),
            Flexible(
              child: Text(trUi(text), softWrap: true, style: TextStyle(
                color: primary ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    ));
  }

  Widget _requestAmount(Map item) {
    final currency = item['currency']?.toString() ?? 'ILS';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: _cyan.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: _cyan.withValues(alpha: .35))),
      child: Text('${_fmtMoney(item['amount_minor'], currency)} $currency',
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _cyan)),
    );
  }

  String _statusLabel(String raw) {
    const statuses = {
      'pending':'قيد المراجعة والتدقيق', 'draft':'مسودة',
      'approved':'معتمد — بانتظار التسوية', 'completed':'تم السحب بنجاح',
      'rejected':'مرفوض', 'needs_info':'بانتظار معلومات',
      'awaiting_payment':'بانتظار التحويل', 'cancelled':'ملغى',
    };
    return statuses[raw] ?? raw;
  }

  Widget _header() => _panelBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      _action('محفظتي', Icons.arrow_forward_rounded, () => Navigator.maybePop(context)),
      const Spacer(),
      Stack(children: [
        _action('طلبات معلّقة', Icons.notifications_outlined, () => setState(() => _queue = _pendingDeposits > 0 ? 'deposits' : 'withdrawals')),
        if (_pendingDeposits + _pendingWithdrawals > 0)
          const Positioned(top: 3, left: 4, child: CircleAvatar(backgroundColor: _rose, radius: 4)),
      ]),
    ]),
    const SizedBox(height: 15),
    Row(children: [
      Container(width: 10, height: 10, decoration: const BoxDecoration(color: _cyan, shape: BoxShape.circle)),
      const SizedBox(width: 9),
      const Expanded(child: TrText('المحفظة — المراجعة المالية والتدقيق',
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 19, fontWeight: FontWeight.w800))),
    ]),
    const SizedBox(height: 5),
    _smallText('بوابة الرقابة والتحقق من الحوالات المصرفية ومطابقة القيود المالية'),
  ]));

  int get _pendingDeposits => (_data['deposits'] is List ? _data['deposits'] as List : const [])
      .where((d) => d is Map && d['status'] == 'pending').length;
  int get _pendingWithdrawals => (_data['withdrawals'] is List ? _data['withdrawals'] as List : const [])
      .where((w) => w is Map && const ['pending', 'approved'].contains(w['status'])).length;

  Widget _tabs(bool wide) {
    final items = <Widget>[
      _queueButton('deposits', 'دفعات الشحن بانتظار المراجعة', _pendingDeposits, Icons.history),
      _queueButton('withdrawals', 'طلبات السحب والتحويل', _pendingWithdrawals, Icons.north_east),
    ];
    return _panelBox(Column(children: [
      wide ? Row(children: [Expanded(child: items[0]), const SizedBox(width: 10), Expanded(child: items[1])])
          : Column(children: [items[0], const SizedBox(height: 8), items[1]]),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: TextButton.icon(
        onPressed: _loading || _busy ? null : _refresh, icon: const Icon(Icons.refresh, size: 15),
        label: const TrText('تحديث قائمة الطلبات'),
        style: TextButton.styleFrom(foregroundColor: _muted),
      )),
    ]), padding: const EdgeInsets.all(8));
  }

  Widget _queueButton(String key, String title, int count, IconData icon) {
    final selected = _queue == key;
    return _action('$title   $count', icon, () => setState(() => _queue = key),
        color: selected ? _cyan : _muted, primary: selected);
  }

  Widget _reportPanel(bool wide) => _panelBox(Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _headerLine(Icons.assessment_outlined, 'تقرير حركات المحفظة المالية'),
    _smallText('تصدير قيود المحفظة فقط — لا يُعد هذا تقرير الإيراد أو تقرير عمولات المنصة؛ توجد تقارير الإيرادات الشاملة بمركز التقارير المحاسبية.'),
    const SizedBox(height: 14),
    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _action('من: ${_date(_reportFrom)}', Icons.calendar_month_outlined, () => _pickDate(from: true)),
      _action('إلى: ${_date(_reportTo)}', Icons.calendar_today_outlined, () => _pickDate(from: false)),
      Container(width: wide ? 150 : 170, height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(11), border: Border.all(color: _edge)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _reportCurrency, isExpanded: true, dropdownColor: _panel,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
          items: const [DropdownMenuItem(value: '', child: TrText('العملة: الكل')),
            DropdownMenuItem(value: 'ILS', child: TrText('ILS (شيكل)')),
            DropdownMenuItem(value: 'USD', child: TrText('USD (دولار)')),
            DropdownMenuItem(value: 'JOD', child: TrText('JOD (دينار)')),
            DropdownMenuItem(value: 'SAR', child: TrText('SAR (ريال سعودي)'))],
          onChanged: (v) => setState(() => _reportCurrency = v ?? ''),
        )),
      ),
      _action('CSV / Excel', Icons.table_chart_outlined,
          _exportBusy ? null : () => _exportReport('csv'), color: _green, primary: true),
      _action('PDF', Icons.picture_as_pdf_outlined,
          _exportBusy ? null : () => _exportReport('pdf'), color: const Color(0xFF8B5CF6), primary: true),
    ]),
  ]), padding: const EdgeInsets.all(20));

  Widget _metric(Map row) {
    final c = row['currency']?.toString() ?? 'ILS';
    final names = {'ILS':'شيكل إسرائيلي', 'USD':'دولار أمريكي', 'JOD':'دينار أردني', 'SAR':'ريال سعودي'};
    return _panelBox(Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _smallText('المستحق بالعملة (${names[c] ?? c}) • ${row['bucket'] ?? ''}', size: 11),
        const SizedBox(height: 5),
        Text('${_fmtMoney(row['total_minor'], c)}  $c',
          textDirection: TextDirection.ltr,
          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontWeight: FontWeight.w800, fontSize: 22)),
      ])),
      Container(width: 44, height: 44, decoration: BoxDecoration(color: _cyan.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12), border: Border.all(color: _cyan.withValues(alpha: .25))),
        child: const Icon(Icons.account_balance_wallet_outlined, color: _cyan)),
    ]));
  }

  Widget _balances(bool wide) {
    final balances = _data['liabilities_by_currency'] is List
        ? (_data['liabilities_by_currency'] as List).whereType<Map>().toList() : <Map>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _headerLine(Icons.toll_outlined, 'الأرصدة المستحقة للمستخدمين حسب العملة'),
      if (balances.isEmpty) _empty('لا توجد أرصدة مستحقة حاليًا', Icons.account_balance_wallet_outlined)
      else LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth > 860 ? 3 : constraints.maxWidth > 540 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final row in balances)
          SizedBox(width: width, child: _metric(row))]);
      }),
    ]);
  }

  Widget _empty(String message, IconData icon) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 33, horizontal: 15),
    decoration: BoxDecoration(color: _panel.withValues(alpha: .54),
      borderRadius: BorderRadius.circular(13), border: Border.all(color: _edge)),
    child: Column(children: [Icon(icon, color: _muted, size: 32),
      const SizedBox(height: 9), _smallText(message, color: Color(0xFF475569))]),
  );

  String _moneyFromMinor(dynamic value, String currency) {
    final minor = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    final precision = currency == 'JOD' ? 3 : 2;
    return (minor / (currency == 'JOD' ? 1000 : 100)).toStringAsFixed(precision);
  }

  Widget _depositCard(Map d) {
    final status = d['status']?.toString() ?? '';
    final reviewable = const ['pending', 'needs_info', 'awaiting_payment'].contains(status);
    final live = _data['live'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(color: _panel.withValues(alpha: .86), borderRadius: BorderRadius.circular(17),
        border: Border.all(color: status == 'pending' ? _cyan.withValues(alpha: .33) : _edge),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 19)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Wrap(spacing: 9, runSpacing: 9, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _requestAmount(d), _pill(_statusLabel(status), status == 'pending' ? _amber : _muted),
          ])),
        Padding(padding: const EdgeInsets.all(15), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${d['user_name'] ?? '—'}  •  ${d['user_email'] ?? '—'}',
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          _smallText('المرجع: ${d['reference'] ?? '—'}', size: 11),
          _smallText('مرجع العميل: ${d['user_payment_reference'] ?? '—'}  •  وسيلة الدفع: ${d['platform_payment_method_id'] ?? '—'}', size: 11),
          if (d['payment_currency'] != null) _smallText('حوالة بعملتين: المحصّل ${_moneyFromMinor(d['payment_amount_minor'], '${d['payment_currency']}')} ${d['payment_currency']}، والمستحق للمحفظة ${_moneyFromMinor(d['amount_minor'], '${d['currency']}')} ${d['currency']}.', color: _amber),
          const SizedBox(height: 12),
          _panelBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _smallText('${trUi('اسم مرسل التحويل')}: ${d['sender_name'] ?? '—'}', translate: false, color: Theme.of(context).colorScheme.onSurfaceVariant),
            if (d['receipt_path'] != null) ...[
              const SizedBox(height: 6),
              _action('تنزيل إيصال الإيداع للمقارنة بكشف البنك', Icons.file_download_outlined,
                  _busy ? null : () => _openDepositReceipt(d)),
            ],
          ]), padding: const EdgeInsets.all(11), color: _bg),
          if (reviewable) ...[
            const SizedBox(height: 13),
            if (d['crypto_snapshot'] != null)
              _smallText('عملة رقمية: تحقق من العنوان والشبكة والأصل ومؤشر نجاح المعاملة وتأكيداتها.', color: _amber),
            const SizedBox(height: 7),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (status == 'pending') _action('اعتماد بعد التأكد من التحصيل', Icons.done_all,
                _busy || !live ? null : () => _form('/wallet/finance/deposits/${d['id']}/approve',
                  title:'اعتماد الإيداع بعد التحقق من كشف الحساب'.tr(), requiresRef:true,
                  verifyBank:true, reason:true, verifyCrypto:d['crypto_snapshot'] != null,
                  paymentCurrency:d['payment_currency']?.toString(),
                  expectedPaymentAmount:d['payment_currency'] == null ? null :
                    _moneyFromMinor(d['payment_amount_minor'], '${d['payment_currency']}')),
                color:_green, primary:true),
              _action('رفض الطلب', Icons.block,
                _busy ? null : () => _form('/wallet/finance/deposits/${d['id']}/reject',
                    title:'رفض الإيداع'.tr(), requiresRef:false,verifyBank:false,reason:true), color:_rose),
              _action('إرسال بريد وطلب معلومات', Icons.mail_outline,
                _busy ? null : () => _form('/wallet/finance/deposit/${d['id']}/information',
                  title:'طلب توضيح من العميل'.tr(), requiresRef:false, verifyBank:false,
                  reason:false,requestInfo:true,defaultEmail:d['user_email']?.toString() ?? ''),
                color:_indigo),
            ]),
          ],
        ])),
      ]),
    );
  }

  Widget _withdrawalCard(Map w) {
    final status = w['status']?.toString() ?? '';
    final live = _data['live'] == true;
    Map? crypto;
    if (w['crypto_destination'] is Map) crypto = w['crypto_destination'] as Map;
    return _panelBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _requestAmount(w), _pill(_statusLabel(status), status == 'approved' ? _green : _amber),
      ]),
      const SizedBox(height: 9),
      Text('${w['user_name'] ?? '—'} • ${w['user_email'] ?? '—'}',
        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 13, fontWeight: FontWeight.w700)),
      _smallText('مرجع الطلب: ${w['reference'] ?? '—'}'),
      const SizedBox(height: 11),
      _smallText('مصدر الرصيد: ${w['source_bucket']=='available'?'رصيد المحفظة الشخصي':'مستحقات مهندس / مكتب'}'),
      _panelBox(_smallText('حساب الاستلام المعتمد: ${_payoutLabel(w)}', color: Theme.of(context).colorScheme.onSurfaceVariant),
        padding: const EdgeInsets.all(11), color: _bg),
      if (w['receiving_details'] is Map) ...[
        const SizedBox(height: 8),
        _panelBox(SelectableText(trUi(_receivingDetails(w)), textDirection: AppLanguage.instance.textDirection,
          style: TextStyle(fontSize:12, color: Theme.of(context).colorScheme.onSurface)),
          padding: const EdgeInsets.all(11),color:_bg),
      ],
      if (crypto != null) ...[
        const SizedBox(height: 8),
        _pill('عملة رقمية: تحقق من الشبكة والعنوان قبل الإرسال', _amber),
        _smallText('${crypto['asset'] ?? ''} / ${crypto['network'] ?? ''}'),
        SelectableText('${crypto['address'] ?? ''}',
          textDirection: TextDirection.ltr, style: const TextStyle(color: _cyan, fontSize: 11)),
      ],
      const SizedBox(height: 10),
      if (status == 'pending') Wrap(spacing: 8, runSpacing: 8, children: [
        _action('إرسال OTP إلى بريد المدير', Icons.mark_email_read_outlined,
          _busy || !live ? null : () => _review('/wallet/finance/withdrawals/${w['id']}/approval-otp', const {}),
          color:_amber),
        _action('اعتماد السحب بعد OTP — دون تحويل', Icons.verified_outlined,
          _busy || !live ? null : () => _form('/wallet/finance/withdrawals/${w['id']}/approve',
            title:'اعتماد السحب برمز OTP'.tr(), requiresRef:false, verifyBank:false,
            reason:true,approvalOtp:true), color:_cyan, primary:true),
      ]),
      if (status == 'approved') _action('تأكيد التسوية بعد تنفيذ التحويل', Icons.task_alt,
        _busy || !live ? null : () => _form('/wallet/finance/withdrawals/${w['id']}/complete',
          title:'إتمام تحويل المستفيد فعليًا'.tr(), requiresRef:true, verifyBank:true,
          reason:false,verifyCrypto:crypto != null), color:_green, primary:true),
      if (const ['pending', 'needs_info'].contains(status)) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _action('رفض وإلغاء الحجز', Icons.block,
            _busy ? null : () => _form('/wallet/finance/withdrawals/${w['id']}/reject',
              title:'رفض السحب وإعادة الرصيد المحجوز'.tr(),requiresRef:false,verifyBank:false,reason:true), color:_rose),
          _action('طلب معلومات بالبريد', Icons.mail_outline,
            _busy ? null : () => _form('/wallet/finance/withdrawal/${w['id']}/information',
              title:'طلب توضيح'.tr(),requiresRef:false, verifyBank:false,reason:false,
              requestInfo:true,defaultEmail:w['user_email']?.toString() ?? ''), color:_indigo),
        ]),
      ],
      if (status == 'approved') ...[const SizedBox(height: 8),
        _smallText('بعد الاعتماد يبقى المبلغ محجوزًا حتى تسوية بنكية موثقة.', color:_amber)],
    ]), padding:const EdgeInsets.all(15));
  }

  Future<void> _allocate(Map item) async {
    final agreed = await showDialog<bool>(context:context, builder:(ctx) => AlertDialog(
      title:const TrText('اعتماد إضافة المستحق'),
      content:const TrText('هل تحققت من تحصيل الدفع، انتهاء النزاع وعدم صرف هذا المستحق مسبقًا؟'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const TrText('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const TrText('تأكيد'))],
    ));
    if (agreed == true) {
      await _review('/wallet/finance/earnings/${item['type']}/${item['id']}/allocate', const {});
    }
  }

  Widget _earnings() {
    final earnings = _data['pending_earnings'] is List
        ? (_data['pending_earnings'] as List).whereType<Map>().toList() : <Map>[];
    return _panelBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _headerLine(Icons.inventory_2_outlined, 'مستحقات جاهزة للتخصيص في المحفظة', trailing:'${earnings.length} مستحق'),
      _smallText('قبل الاعتماد تحقق من تحصيل الدفع، انتهاء فترة النزاع وعدم وجود طلب سحب خارجي وتوفر الأموال لدى مزود الدفع.', color:_amber),
      const SizedBox(height: 12),
      if (earnings.isEmpty) _empty('لا توجد مستحقات جاهزة حاليًا', Icons.folder_open_outlined)
      else ...earnings.map((e) => Padding(padding:const EdgeInsets.only(bottom:10), child: _panelBox(Column(
        crossAxisAlignment: CrossAxisAlignment.start,children:[
          Text('${e['beneficiary'] ?? '—'}',style:TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),fontWeight:FontWeight.bold)),
          _smallText('${e['type']} رقم ${e['id']} • مرجع ${e['origin'] ?? '—'}'),
          _smallText('${e['amount']} ${e['currency'] ?? ''}',color:_cyan,size:15,weight:FontWeight.w700),
          const SizedBox(height:7),
          _action('اعتماد وإضافة المستحق إلى المحفظة',Icons.done_all,
            _busy || _data['live'] != true ? null : () => _allocate(e), color:_cyan, primary:true),
        ]),color:_bg,padding:const EdgeInsets.all(12)))),
    ]), padding:const EdgeInsets.all(17));
  }

  Widget _depositQueue() {
    final deposits = _data['deposits'] is List
        ? (_data['deposits'] as List).whereType<Map>().toList() : <Map>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _headerLine(Icons.receipt_long_outlined,'طلبات الإيداع والشحن',trailing:'$_pendingDeposits قيد المراجعة'),
      _smallText('تأكد من كشف البنك المباشر وليس الإيصال وحده. يجب مطابقة رقم الحركة والقيمة المحصلة فعلًا.', color:_amber),
      const SizedBox(height:13),
      if (deposits.isEmpty) _empty('لا توجد طلبات إيداع حاليًا', Icons.inbox_outlined)
      else ...deposits.map(_depositCard),
    ]);
  }

  Widget _withdrawalQueue() {
    final withdrawals = _data['withdrawals'] is List
        ? (_data['withdrawals'] as List).whereType<Map>().toList() : <Map>[];
    return _panelBox(Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
      _headerLine(Icons.currency_exchange,'طلبات سحب المستحقات',color:_indigo,trailing:'$_pendingWithdrawals طلب'),
      _smallText('اعتماد OTP لا يعني تنفيذ الحوالة؛ تُؤكد التسوية بعد التحويل الفعلي.'),
      const SizedBox(height:12),
      if (withdrawals.isEmpty) _empty('لا توجد طلبات سحب معلقة حاليًا', Icons.check_circle_outline)
      else ...withdrawals.map((w)=>Padding(padding:const EdgeInsets.only(bottom:10),child:_withdrawalCard(w))),
    ]),padding:const EdgeInsets.all(17));
  }

  Widget _footer() => _panelBox(Column(children: [
    const Icon(Icons.gavel_outlined,color:_amber,size:20),
    const SizedBox(height:6),
    _smallText('السياسة الرقابية لمنع الازدواج المالي والتدقيق المباشر',color:Color(0xFF475569),weight:FontWeight.w700,align:TextAlign.center),
    const SizedBox(height:5),
    _smallText('لا تُضاف مستحقات المهندسين والمكاتب تلقائيًا إلى المحفظة. يتم الاعتماد المالي بعد التحقق من الاستحقاق وعدم وجود حجز أو استرداد، واستبعاد المستحق من طابور الصرف القديم.',align:TextAlign.center),
  ]),color:_bg);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: AppLanguage.instance.textDirection,
    child: Theme(data: Theme.of(context).copyWith(
      scaffoldBackgroundColor:_bg,
      colorScheme:Theme.of(context).colorScheme.copyWith(primary:_cyan,surface:_panel),
      appBarTheme:AppBarTheme(backgroundColor:_bg,foregroundColor:(Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
      textTheme:Theme.of(context).textTheme.apply(fontFamily:'Cairo'),
    ),child:Scaffold(
      backgroundColor:_bg,
      appBar:AppBar(title:const TrText('المحفظة — التدقيق المالي',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
        actions:[IconButton(onPressed:_loading || _busy ? null : _refresh,icon:const Icon(Icons.refresh))]),
      body:_loading ? const Center(child:CircularProgressIndicator(color:_cyan))
          : _error != null ? Center(child:Padding(padding:const EdgeInsets.all(20),
             child:Column(mainAxisSize:MainAxisSize.min,children:[
               Text(trUi(_error!),textAlign:TextAlign.center,style:const TextStyle(color:_rose)),
               const SizedBox(height:15),_action('إعادة المحاولة',Icons.refresh,_refresh),
             ])))
          : LayoutBuilder(builder:(context,constraints){
              final wide = constraints.maxWidth >= 720;
              final contentWidth = constraints.maxWidth > 1100 ? 1100.0 : constraints.maxWidth;
              return RefreshIndicator(color:_cyan,onRefresh:_refresh,child:SingleChildScrollView(
                physics:const AlwaysScrollableScrollPhysics(),
                child:Center(child:ConstrainedBox(constraints:BoxConstraints(maxWidth:contentWidth),
                  child:Padding(padding:EdgeInsets.symmetric(horizontal:wide ? 22 : 13,vertical:17),
                    child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                      _header(), const SizedBox(height:14),
                      _tabs(wide), const SizedBox(height:18),
                      if (_data['live'] != true) ...[
                        _panelBox(_smallText('العمليات المالية معطلة حتى تفعيل التشغيل الآمن.',color:_amber)),
                        const SizedBox(height:17),
                      ],
                      _reportPanel(wide),const SizedBox(height:20),
                      _balances(wide),const SizedBox(height:22),
                      if (_queue == 'deposits') _depositQueue() else _withdrawalQueue(),
                      const SizedBox(height:12),
                      if (_queue == 'deposits') _panelBox(Column(
                        crossAxisAlignment:CrossAxisAlignment.start,children:[
                          _headerLine(Icons.currency_exchange,'طلبات سحب المستحقات',color:_indigo,trailing:'$_pendingWithdrawals طلب'),
                          _smallText('طلبات السحب والتحويل بانتظار اعتماد المسؤول وإتمام التسوية.'),
                          const SizedBox(height:12),
                          _action('عرض طلبات السحب',Icons.arrow_back,
                              ()=>setState(()=>_queue='withdrawals'),color:_indigo),
                        ])) else _panelBox(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          _headerLine(Icons.receipt_long_outlined,'طلبات الإيداع والشحن',trailing:'$_pendingDeposits طلب'),
                          _action('عرض طلبات الإيداع',Icons.arrow_back,()=>setState(()=>_queue='deposits')),
                        ])),
                      const SizedBox(height:13),_earnings(),
                      const SizedBox(height:16),
                      _action('إدارة أسعار الصرف وطلبات التحويل',Icons.currency_exchange,
                        ()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WalletFxFinanceScreen())),
                        color:_cyan,primary:true),
                      const SizedBox(height:17),_footer(),const SizedBox(height:20),
                    ]),
                  ),
                )),
              ));
            }),
    )),
  );
}

/// Owns the input controllers until Flutter finally unmounts the dialog.
/// This prevents TextField from reattaching to disposed controllers during
/// the closing animation on Android (and the subsequent framework assertion).
class _WalletFinanceReviewDialog extends StatefulWidget {
  const _WalletFinanceReviewDialog({
    required this.path,
    required this.title,
    required this.requiresRef,
    required this.verifyBank,
    required this.reason,
    required this.approvalOtp,
    required this.requestInfo,
    required this.verifyCrypto,
    required this.defaultEmail,
    this.paymentCurrency, this.expectedPaymentAmount,
  });

  final String path;
  final String title;
  final bool requiresRef;
  final bool verifyBank;
  final bool reason;
  final bool approvalOtp;
  final bool requestInfo;
  final bool verifyCrypto;
  final String defaultEmail;
  final String? paymentCurrency;
  final String? expectedPaymentAmount;

  @override
  State<_WalletFinanceReviewDialog> createState() => _WalletFinanceReviewDialogState();
}

class _WalletFinanceReviewDialogState extends State<_WalletFinanceReviewDialog> {
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  final _provider = TextEditingController();
  final _verifiedPayment = TextEditingController();
  final _otp = TextEditingController();
  late final TextEditingController _recipientEmail;
  bool _confirmed = false;
  bool _confirmedCrypto = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _recipientEmail = TextEditingController(text: widget.defaultEmail);
  }

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    _provider.dispose();
    _verifiedPayment.dispose();
    _otp.dispose();
    _recipientEmail.dispose();
    super.dispose();
  }

  void _confirm() {
    final path = widget.path;
    String? error;
    if (widget.requiresRef && _reference.text.trim().length < 6) {
      error = 'أدخل مرجع التحويل الصحيح.'.tr();
    } else if (widget.requiresRef && path.contains('deposits') && _provider.text.trim().isEmpty) {
      error = 'أدخل البنك أو مزود الدفع.'.tr();
    } else if (widget.requestInfo && _notes.text.trim().length < 10) {
      error = 'أدخل تفاصيل المعلومات المطلوبة.'.tr();
    } else if (path.contains('deposits') && (widget.reason || widget.requiresRef) && _notes.text.trim().length < 10) {
      error = 'أدخل ملاحظات التحقق أو سبب القرار.'.tr();
    } else if (path.contains('withdrawals') && widget.reason && _notes.text.trim().length < 8) {
      error = 'أدخل سبب القرار.'.tr();
    } else if (widget.paymentCurrency != null && _verifiedPayment.text.trim() != widget.expectedPaymentAmount) {
      error = 'تحقّق من كشف البنك ثم أدخل مبلغ الدفع المحصّل المطابق بعملة ${widget.paymentCurrency}.'.tr();
    } else if (widget.verifyBank && !_confirmed) {
      error = 'يلزم التحقق الفعلي من التحويل قبل التأكيد.'.tr();
    } else if (widget.verifyCrypto && !_confirmedCrypto) {
      error = 'يلزم التحقق من التحويل الرقمي قبل التأكيد.'.tr();
    } else if (widget.approvalOtp && !RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())) {
      error = 'أدخل رمز OTP المكوّن من 6 أرقام.'.tr();
    } else if (widget.requestInfo && !_recipientEmail.text.trim().contains('@')) {
      error = 'أدخل عنوان بريد صحيح.'.tr();
    }
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{
      if (widget.requiresRef) 'external_reference': _reference.text.trim(),
      if (widget.requiresRef && path.contains('deposits')) 'provider': _provider.text.trim(),
      if (widget.reason || (widget.requiresRef && path.contains('deposits'))) 'review_note': _notes.text.trim(),
      if (widget.verifyBank) 'bank_transfer_verified': true,
      if (widget.paymentCurrency != null) 'verified_payment_amount': _verifiedPayment.text.trim(),
      if (widget.verifyCrypto) 'crypto_transfer_verified': true,
      if (widget.verifyCrypto && path.contains('deposits')) 'crypto_received_verified': true,
      if (widget.approvalOtp) 'approval_otp': _otp.text.trim(),
      if (widget.requestInfo) 'recipient_email': _recipientEmail.text.trim(),
      if (widget.requestInfo) 'message': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFFFFFFFF),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    title: Text(trUi(widget.title),
      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800)),
    content: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.requestInfo) TextField(
          controller: _recipientEmail, keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'البريد الذي تريد إرسال طلب التوضيح إليه'.tr())),
        if (widget.approvalOtp) TextField(
          controller: _otp, maxLength: 6, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'رمز OTP المرسل إلى بريد المدير المالي / مدير المنصة'.tr())),
        if (widget.requiresRef) TextField(
          controller: _reference,
          decoration: InputDecoration(labelText: 'مرجع التحويل البنكي المؤكد'.tr())),
        if (widget.requiresRef && widget.path.contains('deposits')) TextField(
          controller: _provider,
          decoration: InputDecoration(labelText: 'البنك / مزود الدفع'.tr())),
        if (widget.reason || widget.requestInfo ||
            (widget.requiresRef && widget.path.contains('deposits'))) TextField(
          controller: _notes, minLines: 2, maxLines: 3,
          decoration: InputDecoration(labelText: 'ملاحظة المراجع والسبب'.tr())),
        if (widget.paymentCurrency != null) ...[
          TrText('تأكد من تحصيل ${widget.expectedPaymentAmount} ${widget.paymentCurrency} فعلًا قبل الاعتماد.'),
          TextField(controller: _verifiedPayment, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'المبلغ المحصّل فعليًا (${widget.paymentCurrency})'.tr())),
        ],
        if (widget.verifyBank) CheckboxListTile(
          value: _confirmed,
          onChanged: (v) => setState(() => _confirmed = v ?? false),
          title: const TrText('تحققت بنفسي من تنفيذ التحويل في كشف البنك/المزود.')),
        if (widget.verifyCrypto) CheckboxListTile(
          value: _confirmedCrypto,
          onChanged: (v) => setState(() => _confirmedCrypto = v ?? false),
          title: const TrText('تحققت من الشبكة والعنوان ونجاح TX Hash وتأكيدات التحويل الرقمي.')),
        if (_validationError != null) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(trUi(_validationError!), style: const TextStyle(color: Color(0xFFF43F5E)))),
      ],
    )),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(),
        child: const TrText('إلغاء')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
        onPressed: _confirm,
        child: const TrText('تأكيد')),
    ],
  );
}
