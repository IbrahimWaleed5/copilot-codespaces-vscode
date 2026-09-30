import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';
import '../services/drawing_markup_offline_store.dart';
import '../services/drawing_markup_sync_service.dart';
import '../theme/app_theme.dart';

class ProjectDrawingMarkupScreen extends StatefulWidget {
  const ProjectDrawingMarkupScreen({
    super.key,
    required this.projectId,
    required this.fileId,
    required this.versionId,
    required this.fileTitle,
    required this.versionNumber,
    required this.originalName,
  });

  final int projectId;
  final int fileId;
  final int versionId;
  final String fileTitle;
  final int versionNumber;
  final String originalName;

  @override
  State<ProjectDrawingMarkupScreen> createState() =>
      _ProjectDrawingMarkupScreenState();
}

class _ProjectDrawingMarkupScreenState
    extends State<ProjectDrawingMarkupScreen> {
  final DrawingMarkupOfflineStore _store = DrawingMarkupOfflineStore.instance;
  final DrawingMarkupSyncService _sync = DrawingMarkupSyncService.instance;

  List<Map<String, dynamic>> _layers = <Map<String, dynamic>>[];
  int _activeIndex = -1;
  bool _loading = true;
  bool _saving = false;
  bool _canCreate = false;
  bool _canManage = false;
  String? _error;
  File? _sourceFile;
  bool _isImage = false;
  double _imageAspect = 1 / 1.414;
  String _tool = 'pen';
  Map<String, dynamic>? _liveElement;
  Size _boardSize = const Size(1, 1);

  Map<String, dynamic>? get _active =>
      _activeIndex >= 0 && _activeIndex < _layers.length
          ? _layers[_activeIndex]
          : null;

  bool get _editable => _active != null && _active?['can_edit'] != false;

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
      await _store.init();
      var meta = await _store.meta(
        projectId: widget.projectId,
        fileId: widget.fileId,
        versionId: widget.versionId,
      );

      if (await _sync.hasConnection()) {
        try {
          final remote = await ApiService.fetchProjectFileMarkups(
            projectId: widget.projectId,
            fileId: widget.fileId,
            versionId: widget.versionId,
          );
          await _store.saveMeta(
            projectId: widget.projectId,
            fileId: widget.fileId,
            versionId: widget.versionId,
            meta: remote,
          );
          if (remote['markups'] is List) {
            await _store.cacheServerMarkups(
              projectId: widget.projectId,
              fileId: widget.fileId,
              versionId: widget.versionId,
              markups: remote['markups'] as List,
            );
          }
          meta = remote;
        } catch (_) {
          // Cached data remains usable when the server is temporarily offline.
        }
      }

      final permissions = meta['permissions'] is Map
          ? Map<String, dynamic>.from(meta['permissions'] as Map)
          : <String, dynamic>{};
      _canCreate = permissions['can_create'] == true;
      _canManage = permissions['can_manage'] == true;
      _layers = await _store.layers(
        projectId: widget.projectId,
        fileId: widget.fileId,
        versionId: widget.versionId,
      );
      if (_layers.isNotEmpty && _activeIndex < 0) _activeIndex = 0;
      if (_activeIndex >= _layers.length) _activeIndex = _layers.length - 1;

      await _loadSourceFile(meta);
    } catch (e) {
      _error = 'تعذر فتح مساحة الـMarkup: $e'.tr();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSourceFile(Map<String, dynamic> meta) async {
    final version = meta['version'] is Map
        ? Map<String, dynamic>.from(meta['version'] as Map)
        : <String, dynamic>{};
    final mime = version['mime_type']?.toString().toLowerCase() ?? '';
    final name = version['original_name']?.toString() ?? widget.originalName;
    final lower = name.toLowerCase();
    _isImage = mime.startsWith('image/') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');

    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/drawing_version_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final cached = File(
      '${cacheDir.path}/${widget.projectId}_${widget.fileId}_${widget.versionId}_${safe.isEmpty ? 'version' : safe}',
    );

    if (await cached.exists() && await cached.length() > 0) {
      _sourceFile = cached;
    } else if (await _sync.hasConnection()) {
      try {
        final downloaded = await ApiService.downloadProjectFileVersion(
          projectId: widget.projectId,
          fileId: widget.fileId,
          versionId: widget.versionId,
          fileName: name,
        );
        _sourceFile = await downloaded.copy(cached.path);
      } catch (_) {}
    }

    if (_isImage && _sourceFile != null && await _sourceFile!.exists()) {
      try {
        final bytes = await _sourceFile!.readAsBytes();
        final image = await _decodeImage(bytes);
        if (image.height > 0) _imageAspect = image.width / image.height;
        image.dispose();
      } catch (_) {}
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  void _newLayer() {
    if (!_canCreate) return;
    final layer = <String, dynamic>{
      'client_uuid': _store.newUuid(),
      'title': 'ملاحظات V${widget.versionNumber}'.tr(),
      'page_number': 1,
      'status': 'draft',
      'elements': <Map<String, dynamic>>[],
      'server_version': 0,
      'can_edit': true,
      '_sync_state': 'local',
    };
    setState(() {
      _layers.insert(0, layer);
      _activeIndex = 0;
    });
  }

  List<Map<String, dynamic>> _elements(Map<String, dynamic>? layer) {
    final raw = layer?['elements'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: true);
  }

  void _setElements(List<Map<String, dynamic>> elements) {
    final layer = _active;
    if (layer == null) return;
    layer['elements'] = elements;
  }

  Offset _normalized(Offset local) => Offset(
        (local.dx / math.max(1, _boardSize.width)).clamp(0.0, 1.0).toDouble(),
        (local.dy / math.max(1, _boardSize.height)).clamp(0.0, 1.0).toDouble(),
      );

  Map<String, double> _point(Offset p) => {'x': p.dx, 'y': p.dy};

  void _startDrawing(DragStartDetails details) {
    if (!_editable) return;
    if (_active == null) {
      _newLayer();
      if (_active == null) return;
    }
    final p = _normalized(details.localPosition);
    if (_tool == 'text') return;
    setState(() {
      if (_tool == 'pen') {
        _liveElement = {
          'type': 'pen',
          'points': [_point(p)],
          'color': '#EF4444',
          'width': 3.0,
        };
      } else {
        _liveElement = {
          'type': _tool,
          'start': _point(p),
          'end': _point(p),
          'color': '#EF4444',
          'width': 3.0,
        };
      }
    });
  }

  void _updateDrawing(DragUpdateDetails details) {
    final live = _liveElement;
    if (live == null) return;
    final p = _normalized(details.localPosition);
    setState(() {
      if (live['type'] == 'pen') {
        (live['points'] as List).add(_point(p));
      } else {
        live['end'] = _point(p);
      }
    });
  }

  void _endDrawing(DragEndDetails details) {
    final live = _liveElement;
    if (live == null) return;
    final elements = _elements(_active)..add(Map<String, dynamic>.from(live));
    setState(() {
      _setElements(elements);
      _liveElement = null;
      if (_active != null) _active!['_sync_state'] = 'local';
    });
  }

  Future<void> _addText(TapUpDetails details) async {
    if (_tool != 'text' || !_editable) return;
    if (_active == null) _newLayer();
    if (_active == null) return;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('إضافة ملاحظة نصية'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(hintText: 'اكتب الملاحظة'.tr()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const TrText('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const TrText('إضافة'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (text == null || text.isEmpty || !mounted) return;
    final at = _normalized(details.localPosition);
    final elements = _elements(_active)
      ..add({
        'type': 'text',
        'at': _point(at),
        'text': text,
        'color': '#EF4444',
        'size': 18.0,
      });
    setState(() {
      _setElements(elements);
      _active!['_sync_state'] = 'local';
    });
  }

  Future<void> _editLayerMeta() async {
    final layer = _active;
    if (layer == null || !_editable) return;
    final titleController = TextEditingController(
      text: layer['title']?.toString() ?? '',
    );
    final pageController = TextEditingController(
      text: (layer['page_number'] ?? 1).toString(),
    );
    var isShared = layer['status'] == 'shared';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('إعدادات طبقة الملاحظات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'اسم الطبقة'.tr()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'رقم الصفحة'.tr()),
                ),
                if (_canManage) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const TrText('طبقة مشتركة'),
                    subtitle: const TrText('تظهر للعميل فقط عندما تكون هذه النسخة نفسها متاحة له.',
                    ),
                    value: isShared,
                    onChanged: (value) =>
                        setDialogState(() => isShared = value),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const TrText('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'title': titleController.text.trim(),
                  'page_number': int.tryParse(pageController.text.trim()) ?? 1,
                  'status': _canManage && isShared ? 'shared' : 'draft',
                }),
                child: const TrText('حفظ الإعدادات'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), titleController.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), pageController.dispose);
    if (result == null || !mounted) return;
    setState(() {
      layer['title'] = result['title'];
      layer['page_number'] = result['page_number'];
      layer['status'] = result['status'];
      layer['_sync_state'] = 'local';
    });
  }

  Future<void> _save() async {
    final layer = _active;
    if (layer == null || !_editable || _saving) return;
    setState(() => _saving = true);
    try {
      final uuid = await _store.queueSave(
        projectId: widget.projectId,
        fileId: widget.fileId,
        versionId: widget.versionId,
        markup: layer,
      );
      layer['client_uuid'] = uuid;
      final result = await _sync.syncScope(
        projectId: widget.projectId,
        fileId: widget.fileId,
        versionId: widget.versionId,
      );
      await _reloadLocal();
      if (!mounted) return;
      final message = result.offline
          ? 'تم الحفظ على الجهاز وسيُزامن تلقائيًا عند عودة الإنترنت.'
          : result.conflicts > 0
              ? 'تم الحفظ محليًا، ويوجد تعارض يحتاج قرارك.'
              : result.failed > 0
                  ? 'تم الحفظ محليًا لكن فشلت المزامنة حاليًا؛ سيُعاد المحاولة.'
                  : 'تم حفظ ومزامنة الـMarkup.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TrText('تعذر حفظ الـMarkup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reloadLocal() async {
    final currentUuid = _active?['client_uuid']?.toString();
    final items = await _store.layers(
      projectId: widget.projectId,
      fileId: widget.fileId,
      versionId: widget.versionId,
    );
    var next = items.indexWhere(
      (item) => item['client_uuid']?.toString() == currentUuid,
    );
    if (next < 0 && items.isNotEmpty) next = 0;
    if (mounted) {
      setState(() {
        _layers = items;
        _activeIndex = next;
      });
    }
  }

  Future<void> _resolveConflict({required bool useServer}) async {
    final uuid = _active?['client_uuid']?.toString();
    if (uuid == null) return;
    if (useServer) {
      await _store.useServerConflict(uuid);
    } else {
      await _store.forceLocalConflict(uuid);
      await _sync.syncScope(
        projectId: widget.projectId,
        fileId: widget.fileId,
        versionId: widget.versionId,
      );
    }
    await _reloadLocal();
  }

  Future<void> _resolveLayer() async {
    final id = _asInt(_active?['id']) ?? _asInt(_active?['_server_id']);
    if (!_canManage || id == null) return;
    setState(() => _saving = true);
    try {
      await ApiService.resolveProjectFileMarkup(
        projectId: widget.projectId,
        fileId: widget.fileId,
        versionId: widget.versionId,
        markupId: id,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Markup — V${widget.versionNumber}'),
          actions: [
            if (_sourceFile != null)
              IconButton(
                tooltip: 'فتح الملف الأصلي'.tr(),
                onPressed: () => OpenFilex.open(_sourceFile!.path),
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            IconButton(
              tooltip: 'مزامنة'.tr(),
              onPressed: _saving ? null : _load,
              icon: const Icon(Icons.sync_rounded),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(onPressed: _load, child: Text(trUi(_error!))),
        ),
      );
    }

    return Column(
      children: [
        _layerBar(),
        _toolBar(),
        if (_active?['_sync_state'] == 'conflict') _conflictBar(),
        Expanded(child: _drawingBoard()),
      ],
    );
  }

  Widget _layerBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
        border: Border(bottom: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _layers.isEmpty
                ? TrText('لا توجد طبقات ملاحظات',
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _activeIndex >= 0 ? _activeIndex : null,
                      items: List.generate(_layers.length, (index) {
                        final layer = _layers[index];
                        final state = layer['_sync_state']?.toString() ?? 'synced';
                        return DropdownMenuItem(
                          value: index,
                          child: Text(
                            '${layer['title'] ?? 'Markup ${index + 1}'} • ${layer['status'] ?? 'draft'} • $state',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      onChanged: (index) {
                        if (index != null) setState(() => _activeIndex = index);
                      },
                    ),
                  ),
          ),
          if (_canCreate) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'طبقة جديدة'.tr(),
              onPressed: _newLayer,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
          if (_active != null && _editable) ...[
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'إعدادات الطبقة'.tr(),
              onPressed: _editLayerMeta,
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'حفظ'.tr(),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toolBar() {
    final tools = <(String, IconData, String)>[
      ('pen', Icons.draw_outlined, 'قلم'),
      ('line', Icons.horizontal_rule_rounded, 'خط'),
      ('arrow', Icons.arrow_forward_rounded, 'سهم'),
      ('rect', Icons.crop_square_rounded, 'مستطيل'),
      ('ellipse', Icons.circle_outlined, 'دائرة'),
      ('text', Icons.text_fields_rounded, 'نص'),
    ];
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        children: [
          for (final item in tools)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                selected: _tool == item.$1,
                avatar: Icon(item.$2, size: 17),
                label: Text(trUi(item.$3)),
                onSelected: _editable
                    ? (_) => setState(() => _tool = item.$1)
                    : null,
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.undo_rounded, size: 17),
            label: const TrText('تراجع'),
            onPressed: !_editable || _active == null
                ? null
                : () {
                    final elements = _elements(_active);
                    if (elements.isEmpty) return;
                    setState(() {
                      elements.removeLast();
                      _setElements(elements);
                      _active!['_sync_state'] = 'local';
                    });
                  },
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.layers_clear_outlined, size: 17),
            label: const TrText('مسح الطبقة'),
            onPressed: !_editable || _active == null
                ? null
                : () {
                    setState(() {
                      _setElements(<Map<String, dynamic>>[]);
                      _active!['_sync_state'] = 'local';
                    });
                  },
          ),
          if (_canManage && _active?['status'] != 'resolved') ...[
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.task_alt_rounded, size: 17),
              label: const TrText('إغلاق الملاحظات'),
              onPressed: _saving ? null : _resolveLayer,
            ),
          ],
        ],
      ),
    );
  }

  Widget _conflictBar() {
    return Container(
      width: double.infinity,
      color: AppColors.danger.withValues(alpha: .13),
      padding: const EdgeInsets.all(10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Text(
            _active?['_last_error']?.toString() ??
                'يوجد تعارض مع نسخة أحدث على الخادم.'.tr(),
            style: const TextStyle(color: AppColors.red200),
          ),
          OutlinedButton(
            onPressed: () => _resolveConflict(useServer: true),
            child: const TrText('استخدام نسخة الخادم'),
          ),
          ElevatedButton(
            onPressed: () => _resolveConflict(useServer: false),
            child: const TrText('إعادة إرسال نسختي'),
          ),
        ],
      ),
    );
  }

  Widget _drawingBoard() {
    final aspect = _isImage ? _imageAspect.clamp(.25, 4.0).toDouble() : 1 / 1.414;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = math.max(1.0, constraints.maxWidth - 24);
        final maxH = math.max(1.0, constraints.maxHeight - 24);
        var width = maxW;
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }
        _boardSize = Size(width, height);

        final elements = _elements(_active);
        if (_liveElement != null) {
          elements.add(Map<String, dynamic>.from(_liveElement!));
        }

        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 20),
              ],
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _startDrawing,
              onPanUpdate: _updateDrawing,
              onPanEnd: _endDrawing,
              onTapUp: _addText,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isImage && _sourceFile != null)
                    Image.file(_sourceFile!, fit: BoxFit.fill)
                  else
                    _documentPlaceholder(),
                  CustomPaint(
                    painter: _MarkupPainter(elements),
                    size: Size.infinite,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _documentPlaceholder() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 48, color: Colors.black54),
              const SizedBox(height: 12),
              Text(
                trUi(widget.originalName),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const TrText('لملفات PDF/DWG افتح الأصل بجانب مساحة الملاحظات. الطبقة تبقى مرتبطة بهذه النسخة والصفحة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              if (_sourceFile != null) ...[
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: () => OpenFilex.open(_sourceFile!.path),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const TrText('فتح الملف الأصلي'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkupPainter extends CustomPainter {
  const _MarkupPainter(this.elements);

  final List<Map<String, dynamic>> elements;

  @override
  void paint(Canvas canvas, Size size) {
    for (final element in elements) {
      final type = element['type']?.toString();
      final paint = Paint()
        ..color = _parseColor(element['color']?.toString())
        ..strokeWidth = _number(element['width'], 3)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (type == 'pen') {
        final raw = element['points'];
        if (raw is! List || raw.length < 2) continue;
        final path = Path();
        final first = _offset(raw.first, size);
        path.moveTo(first.dx, first.dy);
        for (final point in raw.skip(1)) {
          final p = _offset(point, size);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      } else if (type == 'line' || type == 'arrow') {
        final a = _offset(element['start'], size);
        final b = _offset(element['end'], size);
        canvas.drawLine(a, b, paint);
        if (type == 'arrow') _drawArrow(canvas, a, b, paint);
      } else if (type == 'rect') {
        final a = _offset(element['start'], size);
        final b = _offset(element['end'], size);
        canvas.drawRect(Rect.fromPoints(a, b), paint);
      } else if (type == 'ellipse') {
        final a = _offset(element['start'], size);
        final b = _offset(element['end'], size);
        canvas.drawOval(Rect.fromPoints(a, b), paint);
      } else if (type == 'text') {
        final at = _offset(element['at'], size);
        final painter = TextPainter(
          text: TextSpan(
            text: trUiN(element['text']?.toString() ?? ''),
            style: TextStyle(
              color: paint.color,
              fontSize: _number(element['size'], 18),
              fontWeight: FontWeight.w700,
              backgroundColor: Colors.white.withValues(alpha: .72),
            ),
          ),
          textDirection: AppLanguage.instance.textDirection,
        )..layout(maxWidth: size.width * .7);
        painter.paint(canvas, at);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset a, Offset b, Paint paint) {
    final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
    const length = 15.0;
    const spread = .55;
    final p1 = Offset(
      b.dx - length * math.cos(angle - spread),
      b.dy - length * math.sin(angle - spread),
    );
    final p2 = Offset(
      b.dx - length * math.cos(angle + spread),
      b.dy - length * math.sin(angle + spread),
    );
    canvas.drawLine(b, p1, paint);
    canvas.drawLine(b, p2, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkupPainter oldDelegate) => true;

  static Offset _offset(dynamic raw, Size size) {
    if (raw is Map) {
      final x = _number(raw['x'], 0).clamp(0.0, 1.0).toDouble();
      final y = _number(raw['y'], 0).clamp(0.0, 1.0).toDouble();
      return Offset(x * size.width, y * size.height);
    }
    return Offset.zero;
  }

  static double _number(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Color _parseColor(String? raw) {
    final clean = (raw ?? '#EF4444').replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return AppColors.danger;
    return Color(clean.length == 6 ? 0xFF000000 | value : value);
  }
}
