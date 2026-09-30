import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../i18n/i18n.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SupportKnowledgeScreen extends StatefulWidget {
  final bool adminMode;

  const SupportKnowledgeScreen({super.key, this.adminMode = false});

  @override
  State<SupportKnowledgeScreen> createState() => _SupportKnowledgeScreenState();
}

class _SupportKnowledgeScreenState extends State<SupportKnowledgeScreen> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
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
      final data = widget.adminMode
          ? await ApiService.fetchAdminFaq()
          : await ApiService.fetchSupportKnowledge(q: _search.text.trim());
      final raw = data['items'] as List? ?? const [];
      final items = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل قاعدة المعرفة.'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleItems {
    if (!widget.adminMode) return _items;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((item) {
      final haystack = [
        item['question'],
        item['answer'],
        item['category'],
        item['keywords'],
      ].where((e) => e != null).join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trUi(message)),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  int _asInt(dynamic value, [int fallback = 0]) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final normalized = value.toString().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  Future<void> _openEditor([Map<String, dynamic>? article]) async {
    if (!widget.adminMode) return;
    final question = TextEditingController(text: article?['question']?.toString() ?? '');
    final answer = TextEditingController(text: article?['answer']?.toString() ?? '');
    final category = TextEditingController(text: article?['category']?.toString() ?? '');
    final keywords = TextEditingController(text: article?['keywords']?.toString() ?? '');
    final sortOrder = TextEditingController(text: '${_asInt(article?['sort_order'], 100)}');
    var active = _asBool(article?['is_active'], fallback: true);
    var isPublic = _asBool(article?['is_public'], fallback: true);
    var aiEnabled = _asBool(article?['ai_enabled'], fallback: true);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(article == null ? 'مقالة جديدة'.tr() : 'تعديل المقالة'.tr()),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: question,
                    maxLength: 1000,
                    decoration: InputDecoration(labelText: 'السؤال / العنوان'.tr()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: answer,
                    minLines: 6,
                    maxLines: 12,
                    maxLength: 20000,
                    decoration: InputDecoration(labelText: 'الإجابة المعتمدة'.tr()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: category,
                    decoration: InputDecoration(labelText: 'القسم'.tr()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: keywords,
                    decoration: InputDecoration(labelText: 'الكلمات المفتاحية'.tr()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sortOrder,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'الترتيب'.tr()),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (v) => setDialogState(() => active = v),
                    title: Text('مفعلة'.tr()),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: isPublic,
                    onChanged: (v) => setDialogState(() => isPublic = v),
                    title: Text('تظهر للعميل'.tr()),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: aiEnabled,
                    onChanged: (v) => setDialogState(() => aiEnabled = v),
                    title: Text('يستخدمها AI'.tr()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء'.tr()),
            ),
            FilledButton.icon(
              onPressed: () {
                if (question.text.trim().isEmpty || answer.text.trim().isEmpty) {
                  _toast('السؤال والإجابة مطلوبان.'.tr(), error: true);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.save_outlined),
              label: Text('حفظ'.tr()),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        final result = await ApiService.saveAdminFaq(
          id: article == null ? null : _asInt(article['id']),
          question: question.text.trim(),
          answer: answer.text.trim(),
          category: category.text.trim(),
          keywords: keywords.text.trim(),
          sortOrder: _asInt(sortOrder.text, 100),
          isPublic: isPublic,
          aiEnabled: aiEnabled,
          isActive: active,
        );
        _toast(result['message']?.toString() ?? 'تم الحفظ.'.tr());
        await _load();
      } on ApiException catch (e) {
        _toast(e.message, error: true);
      }
    }

    Future<void>.delayed(const Duration(milliseconds: 600), question.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), answer.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), category.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), keywords.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), sortOrder.dispose);
  }

  Future<void> _delete(Map<String, dynamic> article) async {
    if (!widget.adminMode) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('حذف المقالة؟'.tr()),
        content: Text('سيتم حذف المقالة من قاعدة المعرفة نهائيًا.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('حذف'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await ApiService.deleteAdminFaq(_asInt(article['id']));
      _toast(result['message']?.toString() ?? 'تم الحذف.'.tr());
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = _visibleItems;
    final surface = dark ? const Color(0xFF0B1930) : Colors.white;
    final border = dark ? const Color(0xFF18375F) : const Color(0xFFD9E5F3);

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF061226) : const Color(0xFFF4F8FF),
        appBar: AppBar(
          title: Text('قاعدة معرفة الدعم'.tr()),
          actions: [
            IconButton(
              tooltip: 'تحديث'.tr(),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: widget.adminMode
            ? FloatingActionButton.extended(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
                label: Text('مقالة جديدة'.tr()),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.adminMode
                          ? 'المقالات المفعّل لها AI تدخل مباشرة في سياق مساعد الدعم.'.tr()
                          : 'راجع الإجابات المعتمدة قبل الرد على العميل. المقالات المفعّلة للـAI يستخدمها المساعد أيضًا.'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => widget.adminMode ? setState(() {}) : _load(),
                      onChanged: widget.adminMode ? (_) => setState(() {}) : null,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'ابحث في السؤال أو الإجابة أو الكلمات المفتاحية...'.tr(),
                        suffixIcon: IconButton(
                          tooltip: 'بحث'.tr(),
                          onPressed: widget.adminMode ? () => setState(() {}) : _load,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : items.isEmpty
                          ? Center(child: Text('لا توجد مقالات مطابقة.'.tr()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final category = item['category']?.toString().trim();
                                  final ai = _asBool(item['ai_enabled']);
                                  final pub = _asBool(item['is_public']);
                                  final active = _asBool(item['is_active']);
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Wrap(
                                          spacing: 7,
                                          runSpacing: 7,
                                          children: [
                                            if (category != null && category.isNotEmpty)
                                              _Tag(label: category, icon: Icons.folder_outlined),
                                            if (ai)
                                              _Tag(label: 'يستخدمها AI'.tr(), icon: Icons.auto_awesome_outlined),
                                            if (pub)
                                              _Tag(label: 'ظاهرة للعملاء'.tr(), icon: Icons.public_rounded),
                                            if (widget.adminMode)
                                              _Tag(
                                                label: active ? 'مفعلة'.tr() : 'غير مفعلة'.tr(),
                                                icon: active ? Icons.check_circle_outline : Icons.pause_circle_outline,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          trUi(item['question']?.toString() ?? '—'),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 9),
                                        Text(
                                          trUi(item['answer']?.toString() ?? '—'),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            height: 1.65,
                                          ),
                                        ),
                                        if ((item['keywords']?.toString() ?? '').trim().isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            '${'كلمات مفتاحية'.tr()}: ${item['keywords']}'.tr(),
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.visibility_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            const SizedBox(width: 5),
                                            Text('${_asInt(item['views'])} ${'مشاهدة'.tr()}'.tr()),
                                            const SizedBox(width: 16),
                                            Icon(Icons.thumb_up_alt_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            const SizedBox(width: 5),
                                            Text('${_asInt(item['helpful_count'])} ${'مفيد'.tr()}'.tr()),
                                            const Spacer(),
                                            if (widget.adminMode) ...[
                                              IconButton(
                                                tooltip: 'تعديل'.tr(),
                                                onPressed: () => _openEditor(item),
                                                icon: const Icon(Icons.edit_outlined),
                                              ),
                                              IconButton(
                                                tooltip: 'حذف'.tr(),
                                                color: AppColors.danger,
                                                onPressed: () => _delete(item),
                                                icon: const Icon(Icons.delete_outline_rounded),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Tag({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF102B4C) : const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(trUi(label), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44),
              const SizedBox(height: 12),
              Text(trUi(message), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('إعادة المحاولة'.tr()),
              ),
            ],
          ),
        ),
      );
}
