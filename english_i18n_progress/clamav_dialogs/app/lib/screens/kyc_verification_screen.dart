import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../utils/app_file_picker.dart';
import 'local_face_verification_screen.dart';
import 'didit_verification_screen.dart';

class KycVerificationScreen extends StatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  final _legalName = TextEditingController();
  final _identityNumber = TextEditingController();
  final _nationality = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _countryCode = TextEditingController(text: 'PS');
  Map<String, dynamic>? _data;
  final Map<String, File> _documents = {};
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Map<String, dynamic>? _faceVerification;
  bool _startingFace = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _legalName.dispose();
    _identityNumber.dispose();
    _nationality.dispose();
    _dateOfBirth.dispose();
    _countryCode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiService.fetchKyc();
      if (!mounted) return;
      if (data['ready'] == false) {
        setState(() => _error = data['message']?.toString() ?? 'KYC غير مجهز على الخادم.');
        return;
      }
      final user = Map<String, dynamic>.from(data['user'] as Map? ?? const {});
      _legalName.text = user['legal_name']?.toString() ?? '';
      _nationality.text = user['nationality']?.toString() ?? '';
      _dateOfBirth.text = user['date_of_birth']?.toString() ?? '';
      _countryCode.text = (user['country_code']?.toString() ?? _countryCode.text).toUpperCase();
      Map<String, dynamic>? face;
      try {
        final faceResult = await ApiService.fetchKycFaceVerificationStatus();
        final rawFace = faceResult['verification'];
        if (rawFace is Map) face = Map<String, dynamic>.from(rawFace);
      } catch (_) {}
      if (!mounted) return;
      setState(() { _data = data; _faceVerification = face; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message.isEmpty ? 'تعذر تحميل بيانات التوثيق من الخادم.' : e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر فتح مركز التوثيق. حدّث التطبيق ثم أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(String type) async {
    final picked = await AppFilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    final path = picked?.path;
    if (path != null && mounted) setState(() => _documents[type] = File(path));
  }


  Future<void> _startFace3d() async {
    if (_startingFace) return;
    if (_legalName.text.trim().length < 3 || _identityNumber.text.trim().length < 4) {
      AppFeedback.error('اكتب الاسم القانوني ورقم الهوية أولاً.');
      return;
    }
    final identityFront = _documents['identity_front'];
    if (identityFront == null) {
      AppFeedback.error('ارفع صورة الوجه الأمامي للهوية أولاً حتى تتم المطابقة التلقائية.');
      return;
    }
    setState(() => _startingFace = true);
    try {
      await ApiService.prepareKycFaceVerification(
        legalName: _legalName.text,
        identityNumber: _identityNumber.text,
        identityFront: identityFront,
        identityBack: _documents['identity_back'],
      );
      final result = await ApiService.startKycFaceVerification();
      final verification = Map<String, dynamic>.from(result['verification'] as Map? ?? const {});
      if (mounted) setState(() => _faceVerification = verification);

      final provider = verification['provider']?.toString() ?? '';
      if (provider == 'local_free') {
        if (!mounted) return;
        final verified = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => LocalFaceVerificationScreen(
              onSubmit: (front, blink, left, right) => ApiService.submitKycLocalFaceVerification(
                front: front,
                blink: blink,
                left: left,
                right: right,
              ),
            ),
          ),
        );
        if (verified != null && mounted) {
          await _refreshFace3d();
        }
        return;
      }

      if (provider == 'didit') {
        final url = verification['verification_url']?.toString() ?? '';
        if (!url.startsWith('https://')) throw ApiException('تعذر فتح جلسة التحقق من الهوية.');
        if (!mounted) return;
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => DiditVerificationScreen(url: url)),
        );
        if (mounted) await _refreshFace3d();
        return;
      }

      throw ApiException('مزود التحقق الحالي يحتاج جلسة خارجية. غيّر BIOMETRIC_PROVIDER إلى local_free لاستخدام الفحص داخل التطبيق.');
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    } finally {
      if (mounted) setState(() => _startingFace = false);
    }
  }

  Future<void> _refreshFace3d() async {
    try {
      final result = await ApiService.fetchKycFaceVerificationStatus();
      final raw = result['verification'];
      if (mounted) setState(() => _faceVerification = raw is Map ? Map<String, dynamic>.from(raw) : null);
      final status = _faceVerification?['status']?.toString() ?? '';
      final auto = _faceVerification?['auto_decision']?.toString() ?? '';
      final pct = _faceVerification?['face_match_percent'];
      final pctText = pct is num ? ' (${pct.toStringAsFixed(1)}%)' : '';
      if (auto == 'waiting') {
        AppFeedback.success('اجتزت التحقق من الهوية$pctText. سيتم توثيق حسابك تلقائيًا خلال 15 دقيقة تقريبًا.');
      } else if (auto == 'verified') {
        AppFeedback.success('تم توثيق حسابك بنجاح$pctText.');
      } else if (auto == 'rejected') {
        AppFeedback.error('لم يتم توثيق حسابك تلقائيًا$pctText، وأُحيل طلبك إلى الإدارة للمراجعة.');
      } else if (status == 'matched') {
        AppFeedback.success('أكد الذكاء الاصطناعي تطابق الوجه مع الهوية بنجاح.');
      }
      if (status == 'review_required') AppFeedback.info('اكتمل الفحص والنتيجة تحتاج مراجعة بشرية قبل الاعتماد.');
      if (status == 'failed') AppFeedback.error('لم يجتز فحص الحيوية أو مطابقة الهوية. ابدأ جلسة جديدة.');
      if (status == 'pending' && _faceVerification?['provider']?.toString() == 'didit') {
        AppFeedback.info('نتيجة التحقق قيد المعالجة، وستظهر خلال لحظات. اسحب الصفحة للتحديث.');
      }
    } on ApiException catch (e) { AppFeedback.error(e.message); }
  }

  Future<void> _submit() async {
    if (_legalName.text.trim().length < 3 || _identityNumber.text.trim().length < 4) {
      AppFeedback.error('اكتب الاسم القانوني ورقم الهوية/جواز السفر.');
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await ApiService.submitUserKyc(
        legalName: _legalName.text,
        identityNumber: _identityNumber.text,
        dateOfBirth: _dateOfBirth.text,
        nationality: _nationality.text,
        countryCode: _countryCode.text.trim().isEmpty ? 'PS' : _countryCode.text.trim().toUpperCase(),
        documents: _documents,
      );
      AppFeedback.success(result['message']?.toString() ?? 'تم إرسال طلب التوثيق.');
      _identityNumber.clear();
      _documents.clear();
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openOfficeKyc(Map<String, dynamic> entry) async {
    final office = Map<String, dynamic>.from(entry['office'] as Map? ?? const {});
    final kyc = Map<String, dynamic>.from(entry['kyc'] as Map? ?? const {});
    final officeId = int.tryParse('${office['id']}');
    if (officeId == null) return;

    final legalName = TextEditingController(text: kyc['legal_name']?.toString() ?? office['name']?.toString() ?? '');
    final identity = TextEditingController();
    final officeCountry = TextEditingController(text: kyc['country_code']?.toString() ?? _countryCode.text);
    final files = <String, File>{};
    final required = List<Map<String, dynamic>>.from(
      (kyc['required_documents'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    bool busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0E1626) : Theme.of(context).colorScheme.surface),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 18 + MediaQuery.viewInsetsOf(sheetContext).bottom),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TrText('توثيق مكتب ${office['name'] ?? ''}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    _KycTextField(controller: legalName, label: 'الاسم القانوني للمكتب'),
                    const SizedBox(height: 10),
                    _KycTextField(controller: identity, label: 'رقم تسجيل المكتب / هوية المالك'),
                    const SizedBox(height: 10),
                    _KycTextField(controller: officeCountry, label: 'رمز الدولة (PS / SA / AE...)'),
                    const SizedBox(height: 14),
                    ...required.map((doc) {
                      final type = doc['type']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _KycUploadTile(
                          title: doc['label']?.toString() ?? type,
                          fileName: files[type]?.path.split(Platform.pathSeparator).last,
                          onTap: busy
                              ? null
                              : () async {
                                  final picked = await AppFilePicker.pickFile(
                                    type: FileType.custom,
                                    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
                                  );
                                  final path = picked?.path;
                                  if (path != null) setSheetState(() => files[type] = File(path));
                                },
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF06111D) : const Color(0xFFF5F8FE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              if (legalName.text.trim().length < 3 || identity.text.trim().length < 4) {
                                AppFeedback.error('أدخل الاسم القانوني ورقم التسجيل/الهوية.');
                                return;
                              }
                              setSheetState(() => busy = true);
                              try {
                                final result = await ApiService.submitOfficeKyc(
                                  officeId: officeId,
                                  legalName: legalName.text,
                                  identityNumber: identity.text,
                                  countryCode: officeCountry.text.trim().isEmpty ? 'PS' : officeCountry.text.trim().toUpperCase(),
                                  documents: files,
                                );
                                AppFeedback.success(result['message']?.toString() ?? 'تم إرسال توثيق المكتب.');
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                await _load();
                              } on ApiException catch (e) {
                                AppFeedback.error(e.message);
                              } finally {
                                if (sheetContext.mounted) setSheetState(() => busy = false);
                              }
                            },
                      child: Text(trUi(busy ? 'جاري الإرسال...' : 'إرسال توثيق المكتب'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 600), legalName.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), identity.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), officeCountry.dispose);
  }

  String _statusLabel(String value) => switch (value) {
        'not_started' => 'غير موثق',
        'pending' => 'بانتظار المراجعة',
        'under_review' => 'قيد المراجعة',
        'needs_more_info' => 'مطلوب معلومات إضافية',
        'verified' => 'موثق',
        'rejected' => 'مرفوض',
        'expired' => 'منتهي',
        'suspended' => 'معلّق',
        _ => value,
      };

  Color _statusColor(String status) {
    if (status == 'verified') return (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF047857));
    if (status == 'pending' || status == 'under_review' || status == 'needs_more_info') return (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFF92400E));
    return (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB7185) : const Color(0xFFBE123C));
  }

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(_data?['user'] as Map? ?? const {});
    final required = List<Map<String, dynamic>>.from(
      (user['required_documents'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    final offices = List<Map<String, dynamic>>.from(
      (_data?['offices'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    final status = user['status']?.toString() ?? 'not_started';
    final locked = status == 'verified' || status == 'suspended';

    final dark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = dark ? const Color(0xFF101828) : const Color(0xFFF7FAFF);
    final headerFg = dark ? const Color(0xFFF8FAFC) : const Color(0xFF10223B);
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF080C15) : Theme.of(context).scaffoldBackgroundColor),
        appBar: AppBar(
          backgroundColor: headerBg,
          foregroundColor: headerFg,
          iconTheme: IconThemeData(color: headerFg),
          titleTextStyle: TextStyle(color: headerFg, fontSize: 16, fontWeight: FontWeight.w900),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: headerBg,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          ),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 8,
          title: Row(
            children: [
              const _ShieldIcon(),
              const SizedBox(width: 9),
              TrText('بوابة الأمان والتحقق', style: TextStyle(color: headerFg, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Center(child: _StatusPill(label: 'الحالة: ', value: _statusLabel(status), compact: true)),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
            : _error != null
                ? _KycError(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    color: const Color(0xFF06B6D4),
                    onRefresh: _load,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final mainForm = _buildMainForm(user, required, status, locked);
                        final side = _buildSideInfo();
                        return ListView(
                          padding: EdgeInsets.fromLTRB(wide ? 28 : 14, 22, wide ? 28 : 14, 34),
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1240),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const _KycHero(),
                                    const SizedBox(height: 20),
                                    if (wide)
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 2, child: mainForm),
                                          const SizedBox(width: 22),
                                          Expanded(child: side),
                                        ],
                                      )
                                    else ...[
                                      mainForm,
                                      const SizedBox(height: 14),
                                      side,
                                    ],
                                    if (offices.isNotEmpty) ...[
                                      const SizedBox(height: 18),
                                      ...offices.map((entry) => Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: _OfficeKycCard(entry: entry, statusLabel: _statusLabel, onTap: () => _openOfficeKyc(entry)),
                                          )),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildMainForm(Map<String, dynamic> user, List<Map<String, dynamic>> required, String status, bool locked) {
    final color = _statusColor(status);
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: 'توثيق حسابك الشخصي'.tr(), subtitle: 'يرجى تعبئة البيانات بدقة طبقاً للمستند الرسمي لتفادي رفض الطلب'.tr()),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final cards = [
                _StatusCard(label: 'الحالة', value: _statusLabel(status), valueColor: color),
                _StatusCard(label: 'رقم الهوية', value: user['identity_number_masked']?.toString() ?? 'غير مضاف'),
                _StatusCard(label: 'انتهاء التوثيق', value: user['expires_at']?.toString().split('T').first ?? '—'),
              ];
              return GridView.count(
                crossAxisCount: compact ? 2 : 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: compact ? 1.55 : 1.65,
                children: cards,
              );
            },
          ),
          if ((user['review_notes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoticeBox(text: user['review_notes'].toString(), warning: true),
          ],
          if ((user['rejection_reason']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoticeBox(text: user['rejection_reason'].toString(), error: true),
          ],
          if (!locked) ...[
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth >= 560;
                final fields = [
                  _KycTextField(controller: _legalName, label: 'الاسم القانوني الكامل (كما يظهر في الهوية)', hint: 'أدخل الاسم الثلاثي أو الرباعي'),
                  _KycTextField(controller: _identityNumber, label: 'رقم الهوية الوطنية / جواز السفر', hint: 'أدخل رقم الهوية أو الجواز'),
                  _KycTextField(controller: _nationality, label: 'الجنسية', hint: 'مثال: فلسطين'),
                  _KycTextField(controller: _dateOfBirth, label: 'تاريخ الميلاد', hint: 'YYYY-MM-DD'),
                ];
                if (!twoCols) {
                  return Column(children: [for (int i = 0; i < fields.length; i++) ...[fields[i], if (i != fields.length - 1) const SizedBox(height: 11)]]);
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: fields.map((field) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: field)).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1C31) : Theme.of(context).colorScheme.surface), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x3344E5FF))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TrText('تحقق حيوية الوجه داخل التطبيق', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Builder(builder: (context) {
                  final status = _faceVerification?['status']?.toString() ?? '';
                  final match = (((_faceVerification?['match_score'] as num?)?.toDouble() ?? 0) * 100).round();
                  final live = (((_faceVerification?['liveness_score'] as num?)?.toDouble() ?? 0) * 100).round();
                  final risk = _faceVerification?['risk_level']?.toString() ?? '';
                  final text = status == 'matched'
                      ? '✓ AI أكد التطابق. المطابقة $match% • الحيوية $live% • مستوى المخاطر ${risk.isEmpty ? 'منخفض' : risk}.'
                      : status == 'review_required'
                          ? 'اكتمل فحص AI بنتيجة حدّية ($match%). تم تحويلها لمراجعة بشرية بدل الرفض التلقائي.'
                          : 'يحلل AI عدة لقطات ArcFace مع Anti‑Spoofing واتساق الجلسة ويقارنها بوجه الهوية تلقائياً.';
                  return Text(trUi(text), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.5));
                }),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(onPressed: _startingFace ? null : _startFace3d, icon: const Icon(Icons.face_retouching_natural), label: Text(trUi(_startingFace ? 'جاري التجهيز...' : 'فتح كاميرا التحقق'))),
                  OutlinedButton.icon(onPressed: _refreshFace3d, icon: const Icon(Icons.refresh), label: const TrText('تحديث النتيجة')),
                ]),
              ]),
            ),
            TrText('المستندات المطلوبة للتحقق', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE2E8F0) : Theme.of(context).colorScheme.onSurface), fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 4),
            TrText('يرجى رفع صور واضحة وملونة. الملفات المقبولة JPG / PNG / WEBP / PDF.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10, height: 1.6)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth >= 560;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: required.map((doc) {
                    final type = doc['type']?.toString() ?? '';
                    final tile = _KycUploadTile(
                      title: doc['label']?.toString() ?? type,
                      fileName: _documents[type]?.path.split(Platform.pathSeparator).last,
                      selfie: type == 'selfie',
                      onTap: _sending ? null : () => _pick(type),
                    );
                    return SizedBox(width: twoCols && type != 'selfie' ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth, child: tile);
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: TrText('🔒 جميع المستندات تحفظ في تخزين خاص ومحمي.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10))),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF087CA8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _sending ? null : _submit,
                  child: Text(trUi(_sending ? 'جاري الإرسال...' : 'إرسال للمراجعة والتوثيق'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSideInfo() {
    return Column(
      children: [
        _GlassCard(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title: 'متى يُطلب KYC؟'.tr()),
              SizedBox(height: 13),
              _PolicyPoint('عند العمليات المالية وسحب الأرباح وفق سياسة المنصة.'),
              _PolicyPoint('قبل صرف مستحقات المهندسين والاستشاريين المعتمدين.'),
              _PolicyPoint('قبل صرف مستحقات المكاتب الهندسية والشركات.'),
              _PolicyPoint('عند حل النزاعات أو إجراء تغييرات حساسة في بيانات الحساب.'),
            ],
          ),
        ),
        SizedBox(height: 12),
        _NoticeBox(text: 'لن نطلب منك أبداً رقم البطاقة البنكية الكامل أو رمز الأمان الثلاثي CVV ضمن إجراءات KYC.'.tr(), warning: true),
        SizedBox(height: 12),
        _GlassCard(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _TrustRow(icon: Icons.lock_outline_rounded, title: 'تخزين خاص ومحمّي'.tr(), subtitle: 'وثائق KYC لا تظهر للعامة وتبقى ضمن التخزين الخاص.'.tr()),
              SizedBox(height: 12),
              _TrustRow(icon: Icons.verified_outlined, title: 'مراجعة موثقة', subtitle: 'كل خطوة مراجعة أو فتح مستند يتم تسجيلها.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShieldIcon extends StatelessWidget {
  const _ShieldIcon();
  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF2563EB)]),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 19),
      );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;
  const _StatusPill({required this.label, required this.value, this.compact = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 5 : 6),
        decoration: BoxDecoration(
          color: const Color(0x1AF59E0B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x4DF59E0B)),
        ),
        child: Text('$label$value', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFFBBF24) : Color(0xFF92400E)), fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

class _KycHero extends StatelessWidget {
  const _KycHero();
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KYC & Identity Verification', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490)), fontSize: 11, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          TrText('مركز توثيق الهوية الرسمية', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A)), fontSize: 26, fontWeight: FontWeight.w900)),
          SizedBox(height: 7),
          TrText('توثيق الهوية يحمي المدفوعات والسحوبات والحسابات المهنية. المستندات تُحفظ في بيئة خاصة ومحمية ولا تظهر للعامة.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Color(0xFF475569)), fontSize: 12, height: 1.7)),
        ],
      );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassCard({required this.child, required this.padding});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF131C31) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155) : const Color(0xFFDCE6F3)),
          boxShadow: [BoxShadow(color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0x33000000) : const Color(0x0F0F172A), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: child,
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 6, height: 20, decoration: BoxDecoration(color: const Color(0xFF06B6D4), borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 8),
            Expanded(child: Text(trUi(title), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A)), fontSize: 16, fontWeight: FontWeight.w900))),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(trUi(subtitle!), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Color(0xFF475569)), fontSize: 10, height: 1.6)),
          ],
        ],
      );
}

class _StatusCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatusCard({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF202B41) : const Color(0xFFF0F5FC), borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF45546B) : const Color(0xFFD6E3F2))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(trUi(label), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Color(0xFF475569)), fontSize: 9)),
          const SizedBox(height: 5),
          Text(trUi(value), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: valueColor ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)), fontWeight: FontWeight.w900, fontSize: 11)),
        ]),
      );
}

class _KycTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  const _KycTextField({required this.controller, required this.label, this.hint});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trUi(label), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Color(0xFF475569)), fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A)), fontSize: 12),
            decoration: InputDecoration(
              hintText: trUiN(hint),
              hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0E1626) : const Color(0xFFFFFFFF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF475569) : const Color(0xFFC8D8EA)))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
            ),
          ),
        ],
      );
}

class _KycUploadTile extends StatelessWidget {
  final String title;
  final String? fileName;
  final bool selfie;
  final VoidCallback? onTap;
  const _KycUploadTile({required this.title, required this.fileName, required this.onTap, this.selfie = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF19273D) : const Color(0xFFF4F8FD), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF475569) : const Color(0xFFD4E2F2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(trUi(title), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE2E8F0) : Color(0xFF334155)), fontSize: 11, fontWeight: FontWeight.w800))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0x1A06B6D4), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x4D06B6D4))), child: TrText('إلزامي', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490)), fontSize: 8, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 9),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              constraints: BoxConstraints(
                minHeight: selfie ? 92.0 : 84.0,
              ),
              decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF101C2D) : const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF475569) : const Color(0xFFC8D8EA))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(selfie ? Icons.photo_camera_outlined : Icons.cloud_upload_outlined, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490)), size: 27),
                const SizedBox(height: 6),
                Text(trUi(fileName == null ? (selfie ? 'اختر صورة سيلفي واضحة مع الهوية' : 'اضغط لاختيار ملف') : fileName!), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fileName == null ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490)), fontSize: 10, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                const Text('JPG, PNG, WEBP, PDF', style: TextStyle(color: Color(0xFF64748B), fontSize: 8)),
              ]),
            ),
          ),
        ]),
      );
}

class _PolicyPoint extends StatelessWidget {
  final String text;
  const _PolicyPoint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 18, height: 18, margin: const EdgeInsets.only(top: 1), decoration: BoxDecoration(color: const Color(0x1A06B6D4), shape: BoxShape.circle, border: Border.all(color: const Color(0x4D06B6D4))), child: Icon(Icons.check_rounded, size: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490)))),
          const SizedBox(width: 8),
          Expanded(child: Text(trUi(text), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Color(0xFF475569)), fontSize: 10, height: 1.6))),
        ]),
      );
}

class _NoticeBox extends StatelessWidget {
  final String text;
  final bool warning;
  final bool error;
  const _NoticeBox({required this.text, this.warning = false, this.error = false});
  @override
  Widget build(BuildContext context) {
    final color = error ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB7185) : const Color(0xFFBE123C)) : warning ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFF92400E)) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: color.withValues(alpha: .07), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: .24))),
      child: Text(trUi(text), style: TextStyle(color: color, fontSize: 10, height: 1.7)),
    );
  }
}

class _TrustRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _TrustRow({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFE8EFF8)), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490)), size: 17)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trUi(title), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A)), fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(trUi(subtitle), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Color(0xFF475569)), fontSize: 9, height: 1.5))])),
      ]);
}

class _OfficeKycCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String Function(String) statusLabel;
  final VoidCallback onTap;
  const _OfficeKycCard({required this.entry, required this.statusLabel, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final office = Map<String, dynamic>.from(entry['office'] as Map? ?? const {});
    final kyc = Map<String, dynamic>.from(entry['kyc'] as Map? ?? const {});
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0x1A7C3AED), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.business_outlined, color: Color(0xFFC4B5FD))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trUi(office['name']?.toString() ?? 'مكتب هندسي'), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(trUi(statusLabel(kyc['status']?.toString() ?? 'not_started')), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9))])),
        OutlinedButton(onPressed: onTap, child: const TrText('توثيق', style: TextStyle(fontSize: 10))),
      ]),
    );
  }
}

class _KycError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _KycError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shield_outlined, color: Color(0xFF06B6D4), size: 42),
              const SizedBox(height: 10),
              TrText('تعذر تحميل مركز التوثيق', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A)), fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 7),
              Text(trUi(message), textAlign: TextAlign.center, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Color(0xFF475569)), fontSize: 11, height: 1.6)),
              const SizedBox(height: 13),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const TrText('إعادة المحاولة')),
            ]),
          ),
        ),
      );
}
