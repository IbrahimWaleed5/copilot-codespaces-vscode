import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../utils/app_file_picker.dart';
import 'project_bim_clashes_screen.dart';

class ProjectBimScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectBimScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectBimScreen> createState() => _ProjectBimScreenState();
}

class _ProjectBimScreenState extends State<ProjectBimScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchProjectBim(widget.projectId);
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _models => ((_data?['models'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  List<Map<String, dynamic>> get _runs => ((_data?['runs'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  List<Map<String, dynamic>> get _versions {
    final rows = <Map<String, dynamic>>[];
    for (final model in _models) {
      final title = model['title']?.toString() ?? 'BIM';
      for (final raw in (model['versions'] as List? ?? const [])) {
        if (raw is Map) {
          final v = Map<String, dynamic>.from(raw);
          v['_model_title'] = title;
          rows.add(v);
        }
      }
    }
    return rows;
  }

  Map<String, dynamic> get _permissions => Map<String, dynamic>.from(
        (_data?['permissions'] as Map?) ?? const <String, dynamic>{},
      );

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
  }

  Future<File?> _pickModelFile() async {
    final picked = await AppFilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['ifc', 'ifczip', 'glb', 'gltf', 'rvt', 'nwc', 'nwd', 'dwg', 'dxf', 'zip'],
      dialogTitle: 'اختر نموذج BIM',
    );
    if (picked == null || picked.path == null) return null;
    return File(picked.path!);
  }

  Future<File?> _pickJson({String title = 'اختر ملف JSON'}) async {
    final picked = await AppFilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      dialogTitle: title.tr(),
    );
    if (picked == null || picked.path == null) return null;
    return File(picked.path!);
  }

  Future<void> _createModel() async {
    final modelFile = await _pickModelFile();
    if (modelFile == null || !mounted) return;
    final titleController = TextEditingController();
    final disciplineController = TextEditingController();
    final descriptionController = TextEditingController();
    File? manifest;

    final payload = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('رفع نموذج BIM جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: InputDecoration(labelText: 'اسم النموذج'.tr())),
                  const SizedBox(height: 10),
                  TextField(controller: disciplineController, decoration: InputDecoration(labelText: 'التخصص'.tr())),
                  const SizedBox(height: 10),
                  TextField(controller: descriptionController, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: 'الوصف'.tr())),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.data_object_rounded),
                    title: Text(trUi(manifest == null ? 'Elements Manifest JSON (اختياري)' : manifest!.path.split(Platform.pathSeparator).last)),
                    subtitle: const TrText('اختياري كـ fallback؛ ملفات IFC يمكن كشفها هندسيًا مباشرة على الخادم'),
                    trailing: TextButton(
                      onPressed: () async {
                        final f = await _pickJson();
                        if (f != null) setLocal(() => manifest = f);
                      },
                      child: const TrText('اختيار'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  Navigator.pop(dialogContext, {
                    'title': title,
                    'discipline': disciplineController.text.trim(),
                    'description': descriptionController.text.trim(),
                  });
                },
                child: const TrText('رفع'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), titleController.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), disciplineController.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), descriptionController.dispose);
    if (payload == null) return;

    setState(() => _busy = true);
    try {
      final response = await ApiService.createProjectBimModel(
        projectId: widget.projectId,
        title: payload['title']!,
        discipline: payload['discipline'],
        description: payload['description'],
        modelFile: modelFile,
        elementsManifest: manifest,
      );
      _snack(response['message']?.toString() ?? 'تم رفع نموذج BIM.');
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadVersion(Map<String, dynamic> model) async {
    final modelFile = await _pickModelFile();
    if (modelFile == null || !mounted) return;
    File? manifest;
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: TrText('إصدار جديد — ${model['title'] ?? ''}'),
          content: const TrText('هل تريد إرفاق Elements Manifest JSON مع هذا الإصدار؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('بدون Manifest')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('إرفاق JSON')),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice) manifest = await _pickJson();

    setState(() => _busy = true);
    try {
      final response = await ApiService.uploadProjectBimVersion(
        projectId: widget.projectId,
        modelId: int.parse(model['id'].toString()),
        modelFile: modelFile,
        elementsManifest: manifest,
      );
      _snack(response['message']?.toString() ?? 'تم رفع إصدار BIM.');
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openViewer(Map<String, dynamic> version) async {
    setState(() => _busy = true);
    try {
      final data = await ApiService.fetchProjectBimViewerLink(
        projectId: widget.projectId,
        versionId: int.parse(version['id'].toString()),
      );
      final url = data['url']?.toString();
      if (url == null || url.isEmpty) throw ApiException('تعذر إنشاء رابط العارض.');
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      if (!ok) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(Map<String, dynamic> version) async {
    setState(() => _busy = true);
    try {
      final file = await ApiService.downloadProjectBimVersion(
        projectId: widget.projectId,
        versionId: int.parse(version['id'].toString()),
        fileName: version['original_name']?.toString() ?? 'bim-model',
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runClash() async {
    final versions = _versions;
    if (versions.isEmpty) {
      _snack('ارفع نموذج BIM أولًا.');
      return;
    }
    int? primaryId = int.tryParse(versions.first['id'].toString());
    int? secondaryId;
    String engine = 'auto';
    String clashType = 'intersection';
    bool allowTouching = false;
    final titleController = TextEditingController();
    final toleranceController = TextEditingController(text: '0.002');

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('تشغيل Clash Detection'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: InputDecoration(labelText: 'اسم التشغيل (اختياري)'.tr())),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: InputDecoration(labelText: 'الإصدار A'.tr()),
                    child: DropdownButton<int>(
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      value: primaryId,
                      items: versions.map((v) => DropdownMenuItem(
                        value: int.tryParse(v['id'].toString()),
                        child: Text('${v['_model_title']} — V${v['version_number']} (${v['elements_count'] ?? 0} عنصر)'.tr()),
                      )).toList(),
                      onChanged: (v) => setLocal(() => primaryId = v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: InputDecoration(labelText: 'الإصدار B'.tr()),
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      value: secondaryId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: TrText('Self Clash — نفس الإصدار')),
                        ...versions.map((v) => DropdownMenuItem<int?>(
                          value: int.tryParse(v['id'].toString()),
                          child: Text('${v['_model_title']} — V${v['version_number']}'),
                        )),
                      ],
                      onChanged: (v) => setLocal(() => secondaryId = v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: InputDecoration(labelText: 'محرك الكشف'.tr()),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      value: engine,
                      items: const [
                        DropdownMenuItem(value: 'auto', child: TrText('Auto — IFC Geometry ثم AABB')),
                        DropdownMenuItem(value: 'ifc_geometry', child: TrText('IfcOpenShell Geometry — IFC خام')),
                        DropdownMenuItem(value: 'metadata_aabb', child: TrText('Manifest AABB — فحص أولي')),
                      ],
                      onChanged: (v) => setLocal(() => engine = v ?? 'auto'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: InputDecoration(labelText: 'نوع Clash'.tr()),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      value: clashType,
                      items: const [
                        DropdownMenuItem(value: 'intersection', child: TrText('Intersection — اختراق هندسي')),
                        DropdownMenuItem(value: 'collision', child: TrText('Collision — تماس/تصادم')),
                        DropdownMenuItem(value: 'clearance', child: TrText('Clearance — مسافة أمان')),
                      ],
                      onChanged: (v) => setLocal(() => clashType = v ?? 'intersection'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: toleranceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Tolerance / Clearance بالمتر'.tr()),
                  ),
                  if (clashType == 'collision')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: allowTouching,
                      onChanged: (v) => setLocal(() => allowTouching = v),
                      title: const TrText('احتساب التلامس السطحي'),
                    ),
                  const SizedBox(height: 8),
                  TrText('ملفات IFC الخام تستخدم IfcOpenShell Geometry مباشرة عند اختيار Auto/IFC. Manifest AABB يبقى fallback للفحص الأولي.',
                    style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: primaryId == null ? null : () => Navigator.pop(dialogContext, {
                  'primary': primaryId,
                  'secondary': secondaryId,
                  'title': titleController.text.trim(),
                  'tolerance': double.tryParse(toleranceController.text.trim()) ?? 0.002,
                  'engine': engine,
                  'clash_type': clashType,
                  'allow_touching': allowTouching,
                }),
                child: const TrText('تشغيل'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), titleController.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), toleranceController.dispose);
    if (result == null) return;

    setState(() => _busy = true);
    try {
      final response = await ApiService.runProjectBimClash(
        projectId: widget.projectId,
        primaryVersionId: result['primary'] as int,
        secondaryVersionId: result['secondary'] as int?,
        title: result['title']?.toString(),
        tolerance: result['tolerance'] as double,
        engine: result['engine']?.toString() ?? 'auto',
        clashType: result['clash_type']?.toString() ?? 'intersection',
        allowTouching: result['allow_touching'] == true,
      );
      _snack(response['message']?.toString() ?? 'اكتمل Clash Detection.');
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importReport() async {
    final versions = _versions;
    if (versions.isEmpty) return;
    final report = await _pickJson(title: 'اختر تقرير Clash JSON');
    if (report == null || !mounted) return;
    int? primaryId = int.tryParse(versions.first['id'].toString());
    int? secondaryId;
    final result = await showDialog<List<int?>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('ربط تقرير Clash بالإصدارات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  isExpanded: true,
                  value: primaryId,
                  items: versions.map((v) => DropdownMenuItem(value: int.tryParse(v['id'].toString()), child: Text('${v['_model_title']} — V${v['version_number']}'))).toList(),
                  onChanged: (v) => setLocal(() => primaryId = v),
                ),
                DropdownButton<int?>(
                  isExpanded: true,
                  value: secondaryId,
                  items: [const DropdownMenuItem<int?>(value: null, child: TrText('نفس الإصدار')), ...versions.map((v) => DropdownMenuItem<int?>(value: int.tryParse(v['id'].toString()), child: Text('${v['_model_title']} — V${v['version_number']}')))],
                  onChanged: (v) => setLocal(() => secondaryId = v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(onPressed: primaryId == null ? null : () => Navigator.pop(dialogContext, [primaryId, secondaryId]), child: const TrText('استيراد')),
            ],
          ),
        ),
      ),
    );
    if (result == null || result.first == null) return;
    setState(() => _busy = true);
    try {
      final response = await ApiService.importProjectBimClashReport(
        projectId: widget.projectId,
        primaryVersionId: result.first!,
        secondaryVersionId: result.length > 1 ? result[1] : null,
        report: report,
      );
      _snack(response['message']?.toString() ?? 'تم استيراد التقرير.');
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text('BIM — ${widget.projectTitle}'),
          actions: [
            if (_busy) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        floatingActionButton: _permissions['can_upload'] == true
            ? FloatingActionButton.extended(onPressed: _busy ? null : _createModel, icon: const Icon(Icons.view_in_ar_rounded), label: const TrText('رفع BIM'))
            : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(trUi(_error!), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const TrText('إعادة المحاولة'))])));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.view_in_ar_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)), SizedBox(width: 8), Text('BIM Workspace', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]),
                const SizedBox(height: 8),
                TrText('${_models.length} نموذج • ${_versions.length} إصدار • ${_runs.length} Clash Run', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                const SizedBox(height: 8),
                TrText('GLB/GLTF يفتح في عارض 3D. ملفات IFC تدعم Clash هندسي مباشر عبر IfcOpenShell؛ RVT/NWC/NWD تبقى قابلة للتنزيل/المعالجة عبر مزود خارجي.', style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                if (_permissions['can_manage'] == true) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(onPressed: _busy ? null : _runClash, icon: const Icon(Icons.hub_outlined), label: const TrText('تشغيل Clash')),
                    OutlinedButton.icon(onPressed: _busy ? null : _importReport, icon: const Icon(Icons.upload_file_rounded), label: const TrText('استيراد تقرير')),
                  ]),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const TrText('النماذج والإصدارات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_models.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: TrText('لا توجد نماذج BIM بعد.'))))
          else
            ..._models.map(_modelCard),
          const SizedBox(height: 18),
          const Text('Clash Runs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_runs.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: TrText('لا توجد عمليات Clash بعد.')))
          else
            ..._runs.map(_runCard),
        ],
      ),
    );
  }

  Widget _modelCard(Map<String, dynamic> model) {
    final versions = ((model['versions'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(trUi(model['title']?.toString() ?? 'BIM'), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${model['discipline'] ?? 'بدون تخصص'} • ${versions.length} إصدار'.tr()),
        trailing: _permissions['can_upload'] == true ? IconButton(onPressed: _busy ? null : () => _uploadVersion(model), icon: const Icon(Icons.add_circle_outline_rounded)) : null,
        children: versions.map((version) {
          final format = version['format']?.toString().toUpperCase() ?? '';
          final viewable = const ['GLB', 'GLTF'].contains(format);
          return ListTile(
            title: Text('V${version['version_number']} — ${version['original_name'] ?? ''}'),
            subtitle: TrText('$format • عناصر: ${version['elements_count'] ?? 0}'),
            leading: Icon(viewable ? Icons.threed_rotation_rounded : Icons.description_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
            trailing: Wrap(children: [
              if (viewable) IconButton(onPressed: _busy ? null : () => _openViewer(version), tooltip: 'فتح 3D'.tr(), icon: const Icon(Icons.visibility_outlined)),
              IconButton(onPressed: _busy ? null : () => _download(version), tooltip: 'تنزيل'.tr(), icon: const Icon(Icons.download_outlined)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _runCard(Map<String, dynamic> run) {
    final open = run['open_clashes'] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(Icons.hub_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
        title: Text(trUi(run['title']?.toString() ?? 'Clash Run'), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${run['mode'] ?? ''} • إجمالي ${run['total_clashes'] ?? 0} • مفتوح $open'.tr()),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjectBimClashesScreen(projectId: widget.projectId, runId: int.parse(run['id'].toString()), title: run['title']?.toString() ?? 'Clashes'))).then((_) => _load()),
      ),
    );
  }
}
