import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'ai_premium_screen.dart';
import 'assistant_settings_screen.dart';
import 'login_screen.dart';
import 'support_ticket_screen.dart';

class SmartAssistantScreen extends StatefulWidget {
  final String sourceRoute;
  final String sourceTitle;

  const SmartAssistantScreen({
    super.key,
    this.sourceRoute = 'flutter_smart_assistant',
    this.sourceTitle = 'المساعد الذكي في التطبيق',
  });

  @override
  State<SmartAssistantScreen> createState() => _SmartAssistantScreenState();
}

class _SmartAssistantScreenState extends State<SmartAssistantScreen> {
  final _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode(debugLabel: 'assistant-message-input');
  final _scrollController = ScrollController();
  final _drawerSearchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int? _ticketId;
  int _lastMessageId = 0;
  Map<String, dynamic>? _ticket;
  Map<String, dynamic> _aiEntitlement = const {};
  Map<String, dynamic> _assistantCapabilities = const {};
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _typing = false;
  String? _error;
  Timer? _pollTimer;
  bool _guest = false;
  File? _selectedFile;
  double _fileUploadProgress = 0;
  Timer? _fileUploadTimer;
  String _conversationQuery = '';
  final List<Map<String, dynamic>> _conversations = [];
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  String _assistantMode = 'fast';
  int? _draftProjectId;
  int? _draftLibraryId;
  bool _speechReady = false;
  bool _voiceListening = false;
  bool _voiceConversation = false;
  String _voiceTranscript = '';
  String? _speechLocaleId;
  bool _userNearBottom = true;
  bool _userScrolling = false;
  bool _supportIssueDetected = false;
  bool _draggingAssistantFile = false;

  static List<String> get _quickPrompts => [
    'لخص حالتي في المنصة'.tr(),
    'أنشئ تقرير حالة المشروع Word وPDF واحفظه في ملفات المشروع'.tr(),
    'أنشئ BOQ من بيانات المشروع بصيغة Excel'.tr(),
    'جهز عرض سعر فني ومالي Word وPDF'.tr(),
    'أنشئ محضر آخر اجتماع Word وPDF'.tr(),
    'حوّل محضر الاجتماع الأخير إلى مهام للمشروع'.tr(),
    'أنشئ BOQ للمشروع واعتمده داخل المشروع'.tr(),
    'أنشئ لي ملف Flutter Dart كامل'.tr(),
    'جهز لي ZIP ملفات استبدال للكود'.tr(),
    'ولد لي صورة واجهة معمارية مودرن'.tr(),
    'أين أتابع مشاريعي؟'.tr(),
  ];

  @override
  void initState() {
    super.initState();
    // Immersive sticky can prevent the Android IME from appearing on some devices.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _scrollController.addListener(_handleScrollPosition);
    _openInitialConversation();
    _initVoice();
    _pollTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!_loading && !_sending && _ticketId != null) {
        _refresh(silent: true, onlyNew: true);
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pollTimer?.cancel();
    _speech.cancel();
    _tts.stop();
    _fileUploadTimer?.cancel();
    _messageFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _drawerSearchController.dispose();
    super.dispose();
  }


  Future<void> _openInitialConversation() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final hasToken = await ApiService.hasAuthToken();
      if (!mounted) return;

      if (!hasToken) {
        setState(() {
          _guest = true;
          _ticketId = null;
          _ticket = null;
          _conversations.clear();
          _messages
            ..clear()
            ..add(_guestWelcomeMessage());
        });
        return;
      }

      _guest = false;
      final history = await ApiService.fetchSupportBotConversations();
      if (!mounted) return;
      final rows = List<dynamic>.from(history['conversations'] as List? ?? const []);
      final entitlement = Map<String, dynamic>.from(history['ai_entitlement'] as Map? ?? const {});

      setState(() {
        _conversations
          ..clear()
          ..addAll(rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        if (entitlement.isNotEmpty) _aiEntitlement = entitlement;
      });

      if (_conversations.isNotEmpty) {
        // لا نفتح تلقائيًا محادثة AI سبق تحويلها لموظف الدعم.
        // نختار أحدث جلسة bot فقط، أو نبدأ مسودة AI جديدة.
        final botIndex = _conversations.indexWhere(
          (item) => item['support_mode']?.toString() == 'bot',
        );
        if (botIndex >= 0) {
          final latestId = int.tryParse(_conversations[botIndex]['id']?.toString() ?? '');
          if (latestId != null) {
            await _start(ticketId: latestId);
            return;
          }
        }
      }

      _beginLocalDraftConversation();
      await _refreshAssistantSettings();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تشغيل المساعد الذكي.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Keep typing available even if an old support ticket has been closed or
  // handed to an employee. A tap starts a new local AI draft in that case;
  // the previous ticket remains saved on the server.
  void _showMessageKeyboard() {
    if (!mounted) return;
    final currentMode = _guest ? 'guest' : (_ticket?['support_mode']?.toString() ?? 'bot');
    final currentStatus = _guest ? 'open' : (_ticket?['status']?.toString() ?? 'open');
    if (!_guest && (currentStatus == 'closed' ||
        currentStatus == 'resolved' || currentMode != 'bot')) {
      debugPrint('AI_INPUT: old ticket not writable; opening a new AI draft');
      _beginLocalDraftConversation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activateMessageKeyboard();
      });
      return;
    }
    _activateMessageKeyboard();
  }

  void _activateMessageKeyboard() {
    if (!mounted) return;
    _messageFocusNode.requestFocus();
    debugPrint('AI_INPUT: tap, requested focus; focused=${_messageFocusNode.hasFocus}, sending=$_sending');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_messageFocusNode.hasFocus) return;
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      if (mounted) debugPrint('AI_INPUT: Android TextInput.show requested');
    });
  }

  void _beginLocalDraftConversation({int? projectId, int? libraryId}) {
    if (!mounted) return;
    setState(() {
      _ticketId = null;
      _ticket = null;
      _draftProjectId = projectId;
      _draftLibraryId = libraryId;
      _lastMessageId = 0;
      _supportIssueDetected = false;
      _messages
        ..clear()
        ..add(_welcomeMessage());
      _selectedFile = null;
      _fileUploadProgress = 0;
    });
    _messageController.clear();
  }

  Future<int?> _ensureConversationCreated() async {
    if (_guest) return null;
    if (_ticketId != null) return _ticketId;

    final data = await ApiService.startSupportBot(
      forceNewAiSession: true,
      projectId: _draftProjectId,
      libraryId: _draftLibraryId,
    );
    if (!mounted) return null;
    final ticket = Map<String, dynamic>.from(data['ticket'] as Map? ?? const {});
    final id = int.tryParse(ticket['id']?.toString() ?? '');
    if (id == null) return null;

    setState(() {
      _ticket = ticket;
      _ticketId = id;
      final entitlement = Map<String, dynamic>.from(data['ai_entitlement'] as Map? ?? const {});
      if (entitlement.isNotEmpty) _aiEntitlement = entitlement;
    });
    return id;
  }

  Future<void> _start({int? ticketId, bool forceNewOnOpen = false, int? projectId, int? libraryId}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _typing = false;
      });
    }

    try {
      final hasToken = await ApiService.hasAuthToken();
      if (!mounted) return;

      if (!hasToken) {
        setState(() {
          _guest = true;
          _ticketId = null;
          _ticket = null;
          _aiEntitlement = const {};
          _conversations.clear();
          _messages
            ..clear()
            ..add(_guestWelcomeMessage());
        });
        return;
      }

      _guest = false;
      final data = await ApiService.startSupportBot(
        ticketId: ticketId,
        forceNewAiSession: forceNewOnOpen && ticketId == null,
        projectId: projectId,
        libraryId: libraryId,
      );
      if (!mounted) return;
      _applyStartPayload(data);
      await _refreshAssistantSettings();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تشغيل المساعد الذكي.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyStartPayload(Map<String, dynamic> data) {
    final ticket = Map<String, dynamic>.from(data['ticket'] as Map? ?? const {});
    final rawMessages = List<dynamic>.from(data['messages'] as List? ?? const []);
    final loadedMessages = _cleanMessages(
      rawMessages
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
    final entitlement = Map<String, dynamic>.from(data['ai_entitlement'] as Map? ?? const {});
    final conversations = List<dynamic>.from(data['conversations'] as List? ?? const []);

    setState(() {
      _ticket = ticket;
      if (entitlement.isNotEmpty) _aiEntitlement = entitlement;
      _ticketId = int.tryParse(ticket['id']?.toString() ?? '');
      _draftProjectId = int.tryParse('${ticket['project_id'] ?? ''}');
      _draftLibraryId = int.tryParse('${ticket['library_id'] ?? ''}');
      _conversations
        ..clear()
        ..addAll(conversations.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      _lastMessageId = int.tryParse(data['last_message_id']?.toString() ?? '') ?? 0;
      _messages
        ..clear()
        ..addAll(loadedMessages);
    });
  }


  bool _isAutoSupportNotice(Map<String, dynamic> message) {
    final senderType = message['sender_type']?.toString() ?? '';
    final text = message['message']?.toString() ?? '';
    return senderType == 'system' &&
        (text.contains('تم إرسال رسالتك إلى موظف الدعم') ||
            text.contains('تم وضع المحادثة في قائمة انتظار الدعم'));
  }

  List<Map<String, dynamic>> _cleanMessages(List<Map<String, dynamic>> messages) {
    return messages.where((message) => !_isAutoSupportNotice(message)).toList();
  }

  Map<String, dynamic> _welcomeMessage() {
    return {
      'sender_type': 'bot',
      'message': 'مرحبًا بك 👋 أنا مساعد منصة الوليد الهندسية. أقدر أساعدك في المشاريع، الاستشارات، المدفوعات، لوحة المكتب، ومشاكل الحساب. اسألني مباشرة أو اختر أحد الاقتراحات.',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _guestWelcomeMessage() {
    return {
      'sender_type': 'bot',
      'message': 'مرحبًا 👋 أنا المساعد الذكي لمنصة الوليد الهندسية. يمكنك تجربتي كزائر. عند إنشاء حسابك تحصل على 100 Credit مجانية، وتحفظ محادثاتك وتعود لأي محادثة في أي وقت.',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _pageContext() {
    return {
      'route': widget.sourceRoute,
      'title': widget.sourceTitle,
      'path': 'flutter://smart-assistant',
      'parameters': {
        if (_ticketId != null) 'ticket_id': _ticketId.toString(),
        if ((_ticket?['project_id'] ?? _draftProjectId) != null) 'project_id': '${_ticket?['project_id'] ?? _draftProjectId}',
        if ((_ticket?['library_id'] ?? _draftLibraryId) != null) 'library_id': '${_ticket?['library_id'] ?? _draftLibraryId}',
      },
    };
  }

  List<Map<String, dynamic>> get _assistantProfiles {
    final raw = _aiEntitlement['assistant_profiles'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [
      {'key':'fast','label':'إجابة سريعة'.tr(),'description':'إجابة مباشرة وسريعة'.tr(),'credits':1,'enabled':true,'requires_plan':'AI Free','base_mode':'chat'},
      {'key':'smart','label':'إجابة ذكية'.tr(),'description':'شرح أوضح وتحليل أفضل'.tr(),'credits':2,'enabled':true,'requires_plan':'AI Free','base_mode':'chat'},
      {'key':'programming','label':'حلول برمجية'.tr(),'description':'كود وأخطاء وتحليل تقني'.tr(),'credits':3,'enabled':false,'requires_plan':'AI Plus','base_mode':'thinking'},
      {'key':'engineering','label':'حلول هندسية'.tr(),'description':'مخططات وحسابات وتحليل هندسي'.tr(),'credits':4,'enabled':false,'requires_plan':'AI Plus','base_mode':'thinking'},
      {'key':'design3d','label':'تصميم وتحليل 3D'.tr(),'description':'نمذجة وتصميم ثلاثي الأبعاد'.tr(),'credits':6,'enabled':false,'requires_plan':'AI Pro','base_mode':'work'},
      {'key':'expert','label':'خبير متقدم'.tr(),'description':'أعلى عمق للحالات المعقدة'.tr(),'credits':8,'enabled':false,'requires_plan':'AI Pro','base_mode':'work'},
    ];
  }

  Map<String, dynamic> _profile(String key) {
    for (final item in _assistantProfiles) {
      if (item['key']?.toString() == key) return item;
    }
    return _assistantProfiles.first;
  }

  int _profileCost(String key) => int.tryParse('${_profile(key)['credits'] ?? 1}') ?? 1;
  String _baseModeForProfile(String key) => _profile(key)['base_mode']?.toString() ?? 'chat';

  Map<String, dynamic> get _planCapabilities =>
      Map<String, dynamic>.from(_aiEntitlement['capabilities'] as Map? ?? const {});

  bool _isModeAllowed(String mode) {
    if (_guest) return mode == 'fast';
    return _profile(mode)['enabled'] != false;
  }

  String _requiredPlanForMode(String mode) => _profile(mode)['requires_plan']?.toString() ?? 'AI Free';

  void _changeAssistantMode(String mode) {
    if (!_isModeAllowed(mode)) {
      final required = _requiredPlanForMode(mode);
      setState(() => _assistantMode = 'fast');
      _snack('${_profile(mode)['label'] ?? 'هذا المستوى'} يحتاج باقة $required أو أعلى.');
      return;
    }
    setState(() => _assistantMode = mode);
  }

  int get _voiceTurnCost => int.tryParse('${_aiEntitlement['voice_turn_credits_cost'] ?? 2}') ?? 2;

  bool get _voicePluginEnabled =>
      !_guest && _planCapabilities['voice'] == true && _assistantCapabilities['voice'] != false;

  bool get _filePluginEnabled =>
      !_guest && _planCapabilities['file_analysis'] == true && _assistantCapabilities['file_analysis'] != false;

  Future<void> _refreshAssistantSettings() async {
    if (_guest) return;
    try {
      final data = await ApiService.fetchAssistantSettings();
      final capabilities = Map<String, dynamic>.from(data['capabilities'] as Map? ?? const {});
      if (mounted) setState(() => _assistantCapabilities = capabilities);
    } catch (_) {}
  }

  Future<void> _initVoice() async {
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _voiceListening = false);
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _voiceListening = false);
        },
      );

      String? localeId;
      if (ready) {
        final locales = await _speech.locales();
        for (final locale in locales) {
          if (locale.localeId.toLowerCase().startsWith('ar')) {
            localeId = locale.localeId;
            break;
          }
        }
        localeId ??= (await _speech.systemLocale())?.localeId;
      }

      await _tts.setLanguage('ar-SA');
      await _tts.setSpeechRate(0.47);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        if (!mounted || !_voiceConversation || _sending) return;
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _voiceConversation && !_sending) {
            _startVoiceListening(conversation: true);
          }
        });
      });

      if (mounted) {
        setState(() {
          _speechReady = ready;
          _speechLocaleId = localeId;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _speechReady = false);
    }
  }

  Future<void> _startVoiceListening({bool conversation = false}) async {
    if (!_voicePluginEnabled) {
      final planAllowsVoice = !_guest && _planCapabilities['voice'] == true;
      _snack(planAllowsVoice
          ? 'فعّل الصوت من الإعدادات > Plugins.'
          : 'المحادثة الصوتية تحتاج باقة AI Plus أو أعلى.');
      return;
    }
    if (_sending) return;
    if (!_speechReady) await _initVoice();
    if (!_speechReady) {
      _snack('التعرف على الكلام غير متاح على هذا الجهاز.');
      return;
    }

    await _tts.stop();
    if (_speech.isListening) await _speech.stop();

    if (mounted) {
      setState(() {
        if (conversation) _voiceConversation = true;
        _voiceListening = true;
        _voiceTranscript = '';
      });
    }

    try {
      await _speech.listen(
        onResult: (result) async {
          final words = result.recognizedWords.trim();
          if (mounted) setState(() => _voiceTranscript = words);
          if (result.finalResult && words.isNotEmpty) {
            await _speech.stop();
            if (mounted) setState(() => _voiceListening = false);
            await _send(words, 'voice');
          }
        },
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          autoPunctuation: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 3),
          localeId: _speechLocaleId,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _voiceListening = false);
        _snack('تعذر بدء الاستماع للصوت.');
      }
    }
  }

  Future<void> _toggleOneTurnVoice() async {
    if (_voiceListening) {
      await _speech.stop();
      if (mounted) setState(() => _voiceListening = false);
      return;
    }
    await _startVoiceListening();
  }

  Future<void> _toggleVoiceConversation() async {
    if (_voiceConversation) {
      await _endVoiceConversation();
      return;
    }
    if (mounted) setState(() => _voiceConversation = true);
    await _startVoiceListening(conversation: true);
  }

  Future<void> _endVoiceConversation() async {
    await _speech.stop();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _voiceConversation = false;
      _voiceListening = false;
      _voiceTranscript = '';
    });
  }

  Future<void> _speakAssistantReply(String text) async {
    final clean = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'[`*_>#-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return;
    await _speech.stop();
    if (mounted) setState(() => _voiceListening = false);
    await _tts.stop();
    await _tts.speak(clean);
  }

  Future<void> _refresh({bool silent = false, bool onlyNew = false}) async {
    if (_guest) return;
    final shouldFollow = _userNearBottom && !_userScrolling;
    final id = _ticketId;
    if (id == null) return;

    try {
      final data = await ApiService.fetchSupportBotMessages(
        id,
        afterId: onlyNew ? _lastMessageId : 0,
      );
      if (!mounted) return;

      final ticket = Map<String, dynamic>.from(data['ticket'] as Map? ?? const {});
      final rawMessages = List<dynamic>.from(data['messages'] as List? ?? const []);
      final loadedMessages = _cleanMessages(
        rawMessages
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );

      setState(() {
        _ticket = ticket;
        if (onlyNew) {
          for (final message in loadedMessages) {
            final idValue = int.tryParse(message['id']?.toString() ?? '') ?? 0;
            final exists = idValue > 0 && _messages.any((item) => item['id']?.toString() == idValue.toString());
            if (!exists) _messages.add(message);
          }
        } else {
          _messages
            ..clear()
            ..addAll(loadedMessages.isEmpty ? [_welcomeMessage()] : loadedMessages);
        }
        _lastMessageId = int.tryParse(data['last_message_id']?.toString() ?? '') ?? _lastMessageId;
        for (final message in _messages) {
          _lastMessageId = _maxInt(_lastMessageId, int.tryParse(message['id']?.toString() ?? '') ?? 0);
        }
      });
      if (shouldFollow && loadedMessages.isNotEmpty) {
        _scrollToBottom(force: true);
      }
    } on ApiException catch (e) {
      if (mounted && !silent) _snack(e.message);
    } catch (_) {
      if (mounted && !silent) _snack('تعذر تحديث محادثة المساعد.');
    }
  }

  Future<void> _pickAssistantFile() async {
    if (!_filePluginEnabled && !_guest) {
      _snack('فعّل تحليل الملفات من الإعدادات > Plugins.');
      return;
    }
    if (_guest) {
      _showGuestAccountSheet();
      return;
    }
    if (_sending) return;

    try {
      final picked = await FilePicker.pickFile(type: FileType.any);
      if (picked?.path == null || !mounted) return;
      setState(() {
        _selectedFile = File(picked!.path!);
        _fileUploadProgress = 0;
      });
    } catch (_) {
      if (mounted) _snack('تعذر اختيار الملف.');
    }
  }

  Future<void> _acceptDroppedAssistantFiles(DropDoneDetails details) async {
    if (_sending) return;
    if (_guest) {
      if (mounted) setState(() => _draggingAssistantFile = false);
      _showGuestAccountSheet();
      return;
    }
    if (!_filePluginEnabled) {
      if (mounted) setState(() => _draggingAssistantFile = false);
      _snack('فعّل تحليل الملفات من الإعدادات > Plugins.');
      return;
    }

    final droppedFiles = details.files;
    if (droppedFiles.isEmpty) {
      if (mounted) setState(() => _draggingAssistantFile = false);
      return;
    }

    final dropped = droppedFiles.first;
    final path = dropped.path;
    if (path.trim().isEmpty) {
      if (mounted) setState(() => _draggingAssistantFile = false);
      _snack('تعذر قراءة مسار الملف المسحوب.');
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      if (mounted) setState(() => _draggingAssistantFile = false);
      _snack('تعذر الوصول إلى الملف المسحوب.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _draggingAssistantFile = false;
      _selectedFile = file;
      _fileUploadProgress = 0;
    });

    if (droppedFiles.length > 1) {
      _snack('تم اختيار أول ملف. أرسل كل ملف في رسالة مستقلة ليتم تحليله بدقة.');
    }
  }

  void _setAssistantDragState(bool value) {
    if (!mounted || _draggingAssistantFile == value) return;
    if (_guest || _sending || !_filePluginEnabled) {
      if (_draggingAssistantFile) setState(() => _draggingAssistantFile = false);
      return;
    }
    setState(() => _draggingAssistantFile = value);
  }

  String _attachmentKind(File file) {
    final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
    if (RegExp(r'\.(png|jpe?g|webp|gif|bmp|heic|heif)$').hasMatch(name)) return 'image';
    if (name.endsWith('.pdf')) return 'pdf';
    if (RegExp(r'\.(csv|tsv|xlsx?|ods)$').hasMatch(name)) return 'sheet';
    if (RegExp(r'\.(docx?|odt|rtf)$').hasMatch(name)) return 'document';
    if (RegExp(r'\.(pptx?|odp)$').hasMatch(name)) return 'presentation';
    if (RegExp(r'\.(mp3|wav|m4a|aac|ogg|flac)$').hasMatch(name)) return 'audio';
    if (RegExp(r'\.(mp4|mov|mkv|avi|webm|m4v)$').hasMatch(name)) return 'video';
    if (RegExp(r'\.(txt|md|json|xml|ya?ml|log|ini|php|dart|js|ts|html|css|py|java|kt|c|cpp|cs|go|rs|sql|sh)$').hasMatch(name)) return 'text';
    if (RegExp(r'\.(zip|rar|7z|tar|gz)$').hasMatch(name)) return 'archive';
    return 'file';
  }

  void _startUploadAnimation() {
    _fileUploadTimer?.cancel();
    if (mounted) setState(() => _fileUploadProgress = .06);
    _fileUploadTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (!mounted) return;
      if (_fileUploadProgress >= .92) {
        timer.cancel();
        return;
      }
      setState(() {
        _fileUploadProgress = (_fileUploadProgress + .035).clamp(0.0, .92).toDouble();
      });
    });
  }

  void _finishUploadAnimation({bool failed = false}) {
    _fileUploadTimer?.cancel();
    if (!mounted) return;
    setState(() => _fileUploadProgress = failed ? 0 : 1);
  }

  Future<void> _send([String? quickText, String inputSource = 'text', bool regenerate = false]) async {
    var id = _ticketId;
    final text = (quickText ?? _messageController.text).trim();
    final file = quickText == null ? _selectedFile : null;

    if (_sending) return;
    if (file == null && text.isEmpty) return;
    if (file != null && text.length < 3) {
      _snack('اكتب ماذا تريد من المساعد أن يحلل في الملف.');
      return;
    }

    if (!_guest && id == null) {
      try {
        id = await _ensureConversationCreated();
      } on ApiException catch (e) {
        if (mounted) _snack(e.message);
        return;
      } catch (_) {
        if (mounted) _snack('تعذر بدء المحادثة.');
        return;
      }
      if (id == null) return;
    }

    final localText = text;
    final attachmentName = file?.path.split(Platform.pathSeparator).last;
    final attachmentSize = file == null ? null : file.lengthSync();

    if (file != null) _startUploadAnimation();

    setState(() {
      _sending = true;
      _typing = true;
      if (!regenerate) {
        _messages.add({
          'sender_type': 'customer',
          'message': localText.isEmpty ? 'ملف مرفق' : localText,
          'created_at': DateTime.now().toIso8601String(),
          '_local': true,
          if (file != null) '_attachment_path': file.path,
          if (attachmentName != null) '_attachment_name': attachmentName,
          if (attachmentSize != null) '_attachment_size': attachmentSize,
          if (file != null) '_attachment_kind': _attachmentKind(file),
          if (file != null) '_attachment_uploading': true,
        });
      }
    });

    _messageController.clear();
    _scrollToBottom(force: true);

    try {
      final result = file != null
          ? await ApiService.analyzeSupportBotFile(
              ticketId: id!,
              message: text,
              file: file,
              pageContext: _pageContext(),
              assistantProfile: _assistantMode,
            )
          : _guest
              ? await ApiService.sendGuestAssistantMessage(
                  message: text,
                  pageContext: _pageContext(),
                )
              : await ApiService.sendSupportBotMessage(
                  ticketId: id!,
                  message: text,
                  pageContext: _pageContext(),
                  assistantMode: _baseModeForProfile(_assistantMode),
                  assistantProfile: _assistantMode,
                  inputSource: inputSource,
                  regenerate: regenerate,
                );

      if (!mounted) return;

      final ticket = Map<String, dynamic>.from(result['ticket'] as Map? ?? const {});
      final botMessage = result['message'] is Map
          ? Map<String, dynamic>.from(result['message'] as Map)
          : null;
      final notice = result['notice']?.toString();
      final entitlement = Map<String, dynamic>.from(result['ai_entitlement'] as Map? ?? const {});
      final showNotice = notice != null &&
          notice.isNotEmpty &&
          !notice.contains('تم إرسال رسالتك إلى موظف الدعم') &&
          !notice.contains('تم وضع المحادثة في قائمة انتظار الدعم');

      if (file != null) _finishUploadAnimation();
      setState(() {
        _typing = false;
        if (file != null) {
          _selectedFile = null;
          for (final item in _messages.reversed) {
            if (item['_attachment_path']?.toString() == file.path) {
              item['_attachment_uploading'] = false;
              item['_attachment_progress'] = 1.0;
              break;
            }
          }
        }
        if (ticket.isNotEmpty) {
          _ticket = ticket;
          _ticketId = int.tryParse(ticket['id']?.toString() ?? '') ?? _ticketId;
        }
        if (entitlement.isNotEmpty) _aiEntitlement = entitlement;
        _supportIssueDetected = result['support_issue_detected'] == true ||
            result['show_feedback_buttons'] == true ||
            result['show_transfer_button'] == true;
        final customerId = int.tryParse(result['customer_message_id']?.toString() ?? '') ?? 0;
        _lastMessageId = _maxInt(_lastMessageId, customerId);

        if (botMessage != null && (botMessage['message']?.toString().trim().isNotEmpty ?? false)) {
          final thinking = result['thinking']?.toString() ?? '';
          if (thinking.trim().isNotEmpty && (botMessage['ai_thinking']?.toString().trim().isEmpty ?? true)) {
            botMessage['ai_thinking'] = thinking;
          }
          final botId = int.tryParse(botMessage['id']?.toString() ?? '') ?? 0;
          final exists = botId > 0 && _messages.any((item) => item['id']?.toString() == botId.toString());
          if (!exists) _messages.add(botMessage);
          _lastMessageId = _maxInt(_lastMessageId, botId);
        }

        if (showNotice) {
          _messages.add({
            'sender_type': 'system',
            'message': notice,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      });

      _scrollToBottom(force: true);

      if (botMessage != null && inputSource == 'voice') {
        final spokenText = botMessage['message']?.toString() ?? '';
        if (spokenText.trim().isNotEmpty) {
          await _speakAssistantReply(spokenText);
        }
      }

      if (botMessage == null && !_guest && file == null) {
        await _refresh(onlyNew: true);
      }
    } on ApiException catch (e) {
      if (file != null) _finishUploadAnimation(failed: true);
      if (mounted) {
        final entitlement = Map<String, dynamic>.from(e.data?['ai_entitlement'] as Map? ?? const {});
        final returnedTicket = Map<String, dynamic>.from(e.data?['ticket'] as Map? ?? const {});
        setState(() {
          _typing = false;
          if (entitlement.isNotEmpty) _aiEntitlement = entitlement;
          if (returnedTicket.isNotEmpty) {
            _ticket = returnedTicket;
            _ticketId = int.tryParse(returnedTicket['id']?.toString() ?? '') ?? _ticketId;
          }
        });

        final usageLimitBlocked = entitlement['usage_limit_blocked'] == true;
        if (usageLimitBlocked) {
          _snack(e.message);
        } else if (e.statusCode == 402 ||
            e.data?['code']?.toString() == 'ai_credits_exhausted' ||
            e.data?['code']?.toString() == 'ai_file_analysis_requires_upgrade') {
          _snack('${e.message} افتح «ترقية المساعد» من القائمة بالأعلى.');
        } else {
          _snack(e.message);
        }
      }
    } catch (_) {
      if (file != null) _finishUploadAnimation(failed: true);
      if (mounted) {
        setState(() => _typing = false);
        _snack('تعذر إرسال الرسالة إلى المساعد.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleAiAgentAction(Map<String, dynamic> action, String command) async {
    if (_guest || _sending) return;
    final ticketId = _ticketId;
    final actionId = action['id']?.toString() ?? action['uuid']?.toString() ?? '';
    final previewHash = action['preview_hash']?.toString() ?? action['payload_hash']?.toString() ?? '';
    if (ticketId == null || actionId.isEmpty || previewHash.length != 64) {
      _snack('تعذر التحقق من مسودة المساعد. حدّث المحادثة وحاول مجددًا.');
      return;
    }

    String? instruction;
    if (command == 'edit') {
      final controller = TextEditingController();
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const TrText('تعديل المسودة'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: 'مثال: غيّر المسؤول عن المهمة الأولى إلى أحمد، وعدّل الموعد إلى 2026-10-05'.tr(),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('تحديث المسودة')),
          ],
        ),
      );
      instruction = controller.text.trim();
      controller.dispose();
      if (accepted != true) return;
      if (instruction.length < 3) {
        _snack('اكتب التعديل المطلوب بوضوح.');
        return;
      }
    } else {
      final isConfirm = command == 'confirm';
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(isConfirm ? Icons.verified_user_outlined : Icons.cancel_outlined),
          title: Text(trUi(isConfirm ? 'اعتماد وتنفيذ؟' : 'إلغاء المسودة؟')),
          content: Text(
            trUi(isConfirm
                ? 'سيتم الآن تعديل بيانات المشروع فعليًا وفق المسودة التي راجعتها. المساعد مسموح له هنا فقط بإنشاء مهام من محضر الاجتماع أو إنشاء واعتماد BOQ.'
                : 'سيتم إلغاء هذه المسودة بدون تعديل أي سجل داخل المشروع.'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('رجوع')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(trUi(isConfirm ? 'اعتماد وتنفيذ' : 'إلغاء المسودة')),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }

    setState(() => _sending = true);
    try {
      final result = await ApiService.runSupportBotAgentAction(
        ticketId: ticketId,
        actionId: actionId,
        command: command,
        previewHash: previewHash,
        instruction: instruction,
      );
      if (!mounted) return;

      final responseAction = result['ai_action'] is Map
          ? Map<String, dynamic>.from(result['ai_action'] as Map)
          : <String, dynamic>{};
      final responseMessage = result['message'] is Map
          ? Map<String, dynamic>.from(result['message'] as Map)
          : null;
      final entitlement = Map<String, dynamic>.from(result['ai_entitlement'] as Map? ?? const {});
      final finalStatus = responseAction['status']?.toString() ??
          (command == 'confirm' ? 'executed' : command == 'cancel' ? 'cancelled' : 'superseded');

      setState(() {
        for (final item in _messages) {
          final itemAction = item['ai_action'];
          if (itemAction is Map &&
              (itemAction['id']?.toString() ?? itemAction['uuid']?.toString()) == actionId) {
            final mutable = Map<String, dynamic>.from(itemAction);
            mutable['status'] = command == 'edit' ? 'superseded' : finalStatus;
            item['ai_action'] = mutable;
          }
        }
        if (entitlement.isNotEmpty) _aiEntitlement = entitlement;
        if (responseMessage != null) {
          final responseId = int.tryParse(responseMessage['id']?.toString() ?? '') ?? 0;
          final exists = responseId > 0 && _messages.any((item) => item['id']?.toString() == responseId.toString());
          if (!exists) _messages.add(responseMessage);
          _lastMessageId = _maxInt(_lastMessageId, responseId);
        }
      });
      _scrollToBottom(force: true);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('تعذر تنفيذ أمر المساعد الآمن.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _regenerateLastAnswer() async {
    if (_guest || _sending) return;
    String? prompt;
    for (final item in _messages.reversed) {
      if (item['sender_type']?.toString() == 'customer') {
        final candidate = item['message']?.toString().trim() ?? '';
        if (candidate.isNotEmpty && !candidate.contains('📎')) {
          prompt = candidate;
          break;
        }
      }
    }
    if (prompt == null || prompt.isEmpty) {
      _snack('لا توجد رسالة سابقة لإعادة توليد الرد.');
      return;
    }
    await _send(prompt, 'text', true);
  }

  Future<void> _startNewAiSession() async {
    if (_guest) {
      setState(() {
        _messages
          ..clear()
          ..add(_guestWelcomeMessage());
      });
      _messageController.clear();
      setState(() => _selectedFile = null);
      return;
    }

    _beginLocalDraftConversation();
    _snack('محادثة جديدة جاهزة. لن تُحفظ إلا بعد إرسال أول رسالة.');
    _scrollToBottom(force: true);
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (_guest) return;
    try {
      final data = await ApiService.fetchSupportBotConversations();
      if (!mounted) return;
      final rows = List<dynamic>.from(data['conversations'] as List? ?? const []);
      final entitlement = Map<String, dynamic>.from(data['ai_entitlement'] as Map? ?? const {});
      setState(() {
        _conversations
          ..clear()
          ..addAll(rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        if (entitlement.isNotEmpty) _aiEntitlement = entitlement;
      });
    } on ApiException catch (e) {
      if (!silent && mounted) _snack(e.message);
    }
  }

  Future<void> _openConversation(int ticketId) async {
    await Navigator.of(context).maybePop();
    if (!mounted) return;
    await _start(ticketId: ticketId);
  }


  Future<void> _pickVisualAnalysisFile() async {
    if (_guest) { _showGuestAccountSheet(); return; }
    if (!_filePluginEnabled) { _snack('فعّل تحليل الملفات من الإعدادات > Plugins.'); return; }
    try {
      final picked = await FilePicker.pickFile(type: FileType.image);
      if (picked?.path == null || !mounted) return;
      setState(() {
        _selectedFile = File(picked!.path!);
        _fileUploadProgress = 0;
      });
      _snack('تم إرفاق الصورة للتحليل البصري. اكتب سؤالك ثم أرسل.');
    } catch (_) {
      if (mounted) _snack('تعذر اختيار الصورة.');
    }
  }

  Future<void> _openAiWorkspaceSection(String section) async {
    if (_guest) { _showGuestAccountSheet(); return; }
    try {
      final data = await ApiService.fetchAiWorkspace();
      if (!mounted) return;
      final rows = switch (section) {
        'projects' => List<dynamic>.from(data['projects'] as List? ?? const []),
        'libraries' => List<dynamic>.from(data['libraries'] as List? ?? const []),
        'tasks' => List<dynamic>.from(data['scheduled_tasks'] as List? ?? const []),
        _ => const <dynamic>[],
      };
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1220) : Theme.of(context).scaffoldBackgroundColor),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(trUi(section == 'projects' ? 'المشاريع النشطة' : section == 'libraries' ? 'المكتبة البرمجية (Library)' : 'المهام المجدولة'), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontWeight: FontWeight.w900, fontSize: 17))),
                        if (section == 'libraries') IconButton(onPressed: () async {
                          final c = TextEditingController();
                          final name = await showDialog<String>(context: sheetContext, builder: (d) => Directionality(textDirection: AppLanguage.instance.textDirection, child: AlertDialog(title: const TrText('مكتبة جديدة'), content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: 'اسم المكتبة'.tr())), actions: [TextButton(onPressed: ()=>Navigator.pop(d), child: const TrText('إلغاء')), FilledButton(onPressed: ()=>Navigator.pop(d, c.text.trim()), child: const TrText('إنشاء'))])));
                          if (name != null && name.isNotEmpty) { await ApiService.createAiLibrary(name: name); if (mounted) { Navigator.pop(sheetContext); await _openAiWorkspaceSection('libraries'); } }
                        }, icon: const Icon(Icons.create_new_folder_outlined, color: Color(0xFF1D4ED8))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE8EFF8)),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: TrText('لا توجد عناصر حالياً.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant))))
                        : ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemCount: rows.length,
                            itemBuilder: (_, index) {
                              final item = Map<String,dynamic>.from(rows[index] as Map);
                              final projectId = section == 'tasks' ? int.tryParse('${item['project_id']}') : (section == 'projects' ? int.tryParse('${item['id']}') : null);
                              final libraryId = section == 'libraries' ? int.tryParse('${item['id']}') : null;
                              final title = section == 'tasks' ? (item['title']?.toString() ?? 'مهمة') : (item['title']?.toString() ?? item['name']?.toString() ?? 'عنصر');
                              final subtitle = section == 'tasks' ? (item['project_title']?.toString() ?? '') : (section == 'projects' ? '${item['number'] ?? ''}  •  ${item['status'] ?? ''}' : '${item['conversations_count'] ?? 0} محادثة');
                              return Card(
                                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111827) : Theme.of(context).colorScheme.surface),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Icon(section == 'projects' ? Icons.folder_open_rounded : section == 'libraries' ? Icons.library_books_outlined : Icons.schedule_rounded, color: const Color(0xFF1D4ED8)),
                                  title: Text(trUi(title), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontWeight: FontWeight.w800, fontSize: 13)),
                                  subtitle: subtitle.isEmpty ? null : Text(trUi(subtitle), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10.5)),
                                  onTap: () async {
                                    Navigator.pop(sheetContext);
                                    if (!mounted) return;
                                    await _openLinkedConversationPicker(projectId: projectId, libraryId: libraryId, label: title);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('تعذر تحميل مساحة AI.');
    }
  }

  Future<void> _openLinkedConversationPicker({int? projectId, int? libraryId, required String label}) async {
    try {
      final data = await ApiService.fetchAiWorkspaceConversations(projectId: projectId, libraryId: libraryId);
      final rows = List<dynamic>.from(data['conversations'] as List? ?? const []);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1220) : Theme.of(context).scaffoldBackgroundColor),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (sheetContext) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(trUi(label), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF1D4ED8)),
                    title: TrText('محادثة AI جديدة مرتبطة هنا', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontWeight: FontWeight.w800)),
                    onTap: () { Navigator.pop(sheetContext); _beginLocalDraftConversation(projectId: projectId, libraryId: libraryId); },
                  ),
                  if (rows.isNotEmpty) const Divider(color: Color(0xFFE8EFF8)),
                  ...rows.take(8).map((raw) {
                    final item = Map<String,dynamic>.from(raw as Map);
                    final id = int.tryParse('${item['id']}');
                    return ListTile(
                      leading: Icon(Icons.chat_bubble_outline_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant)),
                      title: Text(trUi(item['title']?.toString() ?? 'محادثة AI'), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE2E8F0) : Theme.of(context).colorScheme.onSurface), fontSize: 12.5)),
                      onTap: id == null ? null : () { Navigator.pop(sheetContext); _start(ticketId: id); },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) _beginLocalDraftConversation(projectId: projectId, libraryId: libraryId);
    }
  }

  Future<void> _renameConversation(int ticketId, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('إعادة تسمية المحادثة'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            decoration: InputDecoration(labelText: 'اسم المحادثة'.tr()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const TrText('حفظ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    try {
      await ApiService.renameSupportBotConversation(ticketId, title);
      await _loadConversations(silent: true);
      if (ticketId == _ticketId) await _start(ticketId: ticketId);
      if (mounted) _snack('تم تحديث اسم المحادثة.');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _archiveConversation(int ticketId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('أرشفة المحادثة؟'),
          content: const TrText('ستختفي المحادثة من السجل النشط ويمكنك بدء محادثة جديدة.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('أرشفة')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      final wasActive = ticketId == _ticketId;
      final message = await ApiService.archiveSupportBotConversation(ticketId);
      await _loadConversations(silent: true);
      if (wasActive) await _startNewAiSession();
      if (mounted) _snack(message);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _showConversationHistory() async {
    if (_guest) {
      _showGuestAccountSheet();
      return;
    }
    await _loadConversations(silent: true);
    if (!mounted) return;
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Widget _buildAssistantDrawer() {
    final normalized = _conversationQuery.trim().toLowerCase();
    final visible = _conversations.where((item) {
      if (normalized.isEmpty) return true;
      final haystack = '${item['title'] ?? ''} ${item['preview'] ?? ''}'.toLowerCase();
      return haystack.contains(normalized);
    }).toList();

    Widget navItem(IconData icon, String label, String section) {
      return ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        leading: Icon(icon, size: 19, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD7E5F8) : Theme.of(context).colorScheme.onSurface)),
        title: Text(trUi(label), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5EEF9) : Theme.of(context).colorScheme.onSurface))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () async {
          await Navigator.of(context).maybePop();
          if (!mounted) return;
          await _openAiPremium(section: section);
        },
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth <= 360 ? (screenWidth - 48) : 310.0;

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Drawer(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF050B14) : Theme.of(context).scaffoldBackgroundColor),
        surfaceTintColor: Colors.transparent,
        width: drawerWidth,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)]),
                      ),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TrText('مساعد منصة الوليد الهندسية', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface))),
                    ),
                    IconButton(onPressed: () async => await Navigator.of(context).maybePop(), icon: Icon(Icons.close_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _drawerSearchController,
                  onChanged: (value) => setState(() => _conversationQuery = value),
                  style: TextStyle(fontSize: 11.5, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                  decoration: InputDecoration(
                    hintText: 'البحث في المحادثات...'.tr(),
                    hintStyle: TextStyle(fontSize: 10.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant)),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant)),
                    filled: true, fillColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A1422) : Theme.of(context).colorScheme.surface),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x1F94A3B8))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x1F94A3B8))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB))),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 96),
                  children: [
                    navItem(Icons.chat_bubble_outline_rounded, 'المحادثات الحديثة', 'overview'),
                    ListTile(dense: true, leading: Icon(Icons.image_outlined, size: 19, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFD7E5F8) : Theme.of(context).colorScheme.onSurface)), title: TrText('الصور والتحليل البصري', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5EEF9) : Theme.of(context).colorScheme.onSurface))), onTap: () async { await Navigator.of(context).maybePop(); if (mounted) await _pickVisualAnalysisFile(); }),
                    ListTile(dense: true, leading: Icon(Icons.library_books_outlined, size: 19, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFD7E5F8) : Theme.of(context).colorScheme.onSurface)), title: TrText('المكتبة البرمجية (Library)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5EEF9) : Theme.of(context).colorScheme.onSurface))), onTap: () async { await Navigator.of(context).maybePop(); if (mounted) await _openAiWorkspaceSection('libraries'); }),
                    ListTile(dense: true, leading: Icon(Icons.folder_open_outlined, size: 19, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFD7E5F8) : Theme.of(context).colorScheme.onSurface)), title: TrText('المشاريع النشطة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5EEF9) : Theme.of(context).colorScheme.onSurface))), onTap: () async { await Navigator.of(context).maybePop(); if (mounted) await _openAiWorkspaceSection('projects'); }),
                    ListTile(dense: true, leading: Icon(Icons.schedule_rounded, size: 19, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFD7E5F8) : Theme.of(context).colorScheme.onSurface)), title: TrText('المهام المجدولة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5EEF9) : Theme.of(context).colorScheme.onSurface))), onTap: () async { await Navigator.of(context).maybePop(); if (mounted) await _openAiWorkspaceSection('tasks'); }),
                    navItem(Icons.workspace_premium_outlined, 'اشتراكات AI', 'subscription'),
                    navItem(Icons.insights_rounded, 'الاستخدام', 'usage'),
                    navItem(Icons.diamond_outlined, 'الخطط', 'plans'),
                    navItem(Icons.add_card_rounded, 'شراء Credits', 'credits'),
                    navItem(Icons.description_outlined, 'تحليل الملفات', 'files'),
                    ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -2),
                      leading: Icon(Icons.settings_outlined, size: 19, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFD7E5F8) : Theme.of(context).colorScheme.onSurface)),
                      title: TrText('الإعدادات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5EEF9) : Theme.of(context).colorScheme.onSurface))),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onTap: () async {
                        await Navigator.of(context).maybePop();
                        if (!mounted) return;
                        await _openAssistantSettings();
                      },
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(12, 14, 12, 7),
                      child: TrText('المحادثات الأخيرة', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant))),
                    ),
                    if (visible.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: TrText('لا توجد محادثات مطابقة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant))),
                      )
                    else
                      ...visible.take(12).map((item) {
                        final id = int.tryParse('${item['id']}') ?? 0;
                        final active = id == _ticketId;
                        return ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -2),
                          leading: Icon(Icons.chat_bubble_outline_rounded, size: 17, color: active ? const Color(0xFF1D4ED8) : const Color(0xFF475569)),
                          title: Text(trUi(item['title']?.toString() ?? 'محادثة AI'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w900 : FontWeight.w600, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : Theme.of(context).colorScheme.onSurface))),
                          tileColor: active ? const Color(0xFFFFFFFF) : Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          onTap: id <= 0 ? null : () async {
                            await Navigator.of(context).maybePop();
                            if (!mounted) return;
                            await _start(ticketId: id);
                          },
                          trailing: PopupMenuButton<String>(
                            padding: EdgeInsets.zero, iconSize: 17, iconColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant),
                            onSelected: (value) async {
                              await Navigator.of(context).maybePop();
                              if (!mounted) return;
                              if (value == 'rename') await _renameConversation(id, item['title']?.toString() ?? 'محادثة AI');
                              if (value == 'archive') await _archiveConversation(id);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: TrText('إعادة تسمية')),
                              PopupMenuItem(value: 'archive', child: TrText('أرشفة')),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF050B14) : Theme.of(context).scaffoldBackgroundColor), border: Border(top: BorderSide(color: Color(0x1494A3B8)))),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).maybePop();
                          if (!mounted) return;
                          await _startNewAiSession();
                        },
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 11)),
                        icon: const Icon(Icons.edit_note_rounded, size: 17),
                        label: const TrText('دردشة جديدة', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: _openAssistantSettings, icon: Icon(Icons.settings_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (!mounted) return;
    final hasToken = await ApiService.hasAuthToken();
    if (hasToken) await _start();
  }

  void _showGuestAccountSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.cyan300, size: 40),
                const SizedBox(height: 10),
                const TrText('احفظ محادثاتك واحصل على 100 Credit مجانية', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TrText('الزائر يستطيع تجربة المساعد، لكن سجل المحادثات والباقات والرصيد مرتبطة بحسابك.', textAlign: TextAlign.center, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.6)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openLogin();
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const TrText('تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _transfer() async {
    final id = _ticketId;
    if (id == null) return;

    try {
      final result = await ApiService.transferSupportBot(id);
      if (!mounted) return;
      final message = result['message']?.toString() ?? 'تم فتح تذكرة دعم بشري.';
      final humanTicketId = int.tryParse('${result['human_ticket_id'] ?? ''}');
      setState(() {
        _messages.add({
          'sender_type': 'system',
          'message': message,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      if (humanTicketId != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SupportTicketScreen(ticketId: humanTicketId)),
        );
      }
      await _refresh(onlyNew: true);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _resolve() async {
    final id = _ticketId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('تم حل المشكلة؟'),
          content: const TrText('سيتم إغلاق محادثة المساعد الحالية على أنها محلولة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const TrText('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const TrText('نعم، تم الحل'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final message = await ApiService.resolveSupportBot(id);
      if (!mounted) return;
      setState(() {
        _messages.add({
          'sender_type': 'system',
          'message': message,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      await _refresh(onlyNew: true);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _openAiPremium({String? section}) async {
    if (_guest) {
      _showGuestAccountSheet();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiPremiumScreen(initialSection: section)),
    );
    if (mounted) {
      try {
        final data = await ApiService.fetchAiPremium();
        final entitlement = Map<String, dynamic>.from(data['entitlement'] as Map? ?? const {});
        if (entitlement.isNotEmpty) setState(() => _aiEntitlement = entitlement);
      } catch (_) {}
    }
  }

  Future<void> _openAssistantSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AssistantSettingsScreen()),
    );
    if (mounted) await _refreshAssistantSettings();
  }

  void _showCreditsExhausted(String message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFF92400E), size: 38),
                const SizedBox(height: 10),
                const TrText('رصيد AI غير كافٍ', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(trUi(message), textAlign: TextAlign.center, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.5)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openAiPremium();
                  },
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const TrText('شراء باقة أو Credits'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _maxInt(int a, int b) => a > b ? a : b;

  void _snack(String message) {
    AppFeedback.auto(message);
  }

  void _handleScrollPosition() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distance = position.maxScrollExtent - position.pixels;
    _userNearBottom = distance <= 110;
  }

  bool _handleUserScrollNotification(UserScrollNotification notification) {
    _userScrolling = notification.direction != ScrollDirection.idle;
    if (!_userScrolling && _scrollController.hasClients) {
      _handleScrollPosition();
    }
    return false;
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_userNearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if ((_scrollController.position.pixels - target).abs() < 2) return;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _guest ? 'guest' : (_ticket?['support_mode']?.toString() ?? 'bot');
    final status = _guest ? 'open' : (_ticket?['status']?.toString() ?? 'open');
    final closed = status == 'resolved' || status == 'closed';
    final aiMode = mode == 'bot' || mode == 'guest';
    final hasCustomerMessage = _messages.any((item) => item['sender_type']?.toString() == 'customer');
    // فتح شاشة AI يعني بدء محادثة جديدة مباشرة، بدون شاشة ترحيب وسيطة.
    const showHome = false;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final exactMobileDesign = screenWidth <= 700;

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: true,
        endDrawer: _guest ? null : _buildAssistantDrawer(),
        drawerEnableOpenDragGesture: false,
        endDrawerEnableOpenDragGesture: true,
        body: _AssistantPlatformDropTarget(
          onDragEntered: (_) => _setAssistantDragState(true),
          onDragExited: (_) => _setAssistantDragState(false),
          onDragDone: (details) => _acceptDroppedAssistantFiles(details),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: exactMobileDesign ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF09090B) : const Color(0xFFF5F8FE)) : null,
                    gradient: exactMobileDesign
                        ? null
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              (Theme.of(context).brightness == Brightness.dark ? Color(0xFF020814) : Color(0xFFF5F8FE)),
                              (Theme.of(context).brightness == Brightness.dark ? Color(0xFF041020) : Color(0xFFF5F8FE)),
                              (Theme.of(context).brightness == Brightness.dark ? Color(0xFF020814) : Color(0xFFF5F8FE)),
                            ],
                          ),
                  ),
                  child: SafeArea(
                    child: _loading
                        ? const _LoadingState()
                        : _error != null
                            ? _ErrorState(message: _error!, onRetry: _openInitialConversation)
                            : Column(
                        children: [
                          if (!showHome)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth <= 700) {
                                  return _ExactAiMobileHeader(
                                    onMenu: _showConversationHistory,
                                    onNewChat: _startNewAiSession,
                                    onShare: () async {
                                      final text = _messages
                                          .map((e) => e['message']?.toString() ?? '')
                                          .where((e) => e.trim().isNotEmpty)
                                          .join('\n\n');
                                      await Clipboard.setData(ClipboardData(text: text));
                                      if (mounted) _snack('تم نسخ المحادثة.');
                                    },
                                    onOptions: _openAssistantSettings,
                                    selectedProfile: _assistantMode,
                                    profiles: _assistantProfiles,
                                    guest: _guest,
                                    onModeChanged: _changeAssistantMode,
                                  );
                                }
                                if (constraints.maxWidth <= 960) {
                                  return _MobileAssistantChatHeader(
                                    selectedMode: _assistantMode,
                                    guest: _guest,
                                    onMenu: _showConversationHistory,
                                    onModeChanged: (value) {
                                      if (_guest && value == 'work') {
                                        _showGuestAccountSheet();
                                        return;
                                      }
                                      _changeAssistantMode(value);
                                    },
                                  );
                                }
                                return _AssistantHeader(
                                  mode: mode,
                                  status: status,
                                  onBack: () => Navigator.maybePop(context),
                                  onRefresh: () => _refresh(),
                                  onNewAiSession: _startNewAiSession,
                                  showNewAiSession: !_guest && mode != 'bot',
                                  aiPlan: _guest ? 'وضع الزائر' : _aiEntitlement['plan_label']?.toString(),
                                  aiCreditsLabel: _guest
                                      ? null
                                      : (_aiEntitlement['unlimited'] == true
                                          ? '∞'
                                          : (_aiEntitlement['available_credits']?.toString() ?? '0')),
                                  onPremium: _openAiPremium,
                                  onHistory: _showConversationHistory,
                                  guest: _guest,
                                  onVoiceConversation: _voicePluginEnabled
                                      ? _toggleVoiceConversation
                                      : () => _snack('فعّل الصوت من الإعدادات > Plugins.'),
                                  voiceConversation: _voiceConversation,
                                  voiceEnabled: _voicePluginEnabled,
                                  voiceCost: _voiceTurnCost,
                                );
                              },
                            ),
                          if (!exactMobileDesign && !_guest && _aiEntitlement.isNotEmpty)
                            _AssistantUsageLimitsStrip(entitlement: _aiEntitlement),
                          if (MediaQuery.sizeOf(context).width > 960 &&
                              (_guest || mode == 'employee' || mode == 'waiting_employee'))
                            _ConversationStatus(
                              mode: mode,
                              status: status,
                              onTransfer: _guest || closed || mode != 'bot' || !_supportIssueDetected ? null : _transfer,
                              onResolve: _guest || closed || mode != 'bot' || !_supportIssueDetected ? null : _resolve,
                              onNewAiSession: _guest || mode == 'bot' ? null : _startNewAiSession,
                            ),
                          Expanded(
                            child: showHome
                                ? _AssistantHomeHero(
                                    selectedMode: _assistantMode,
                                    guest: _guest,
                                    onMenu: _showConversationHistory,
                                    onModeChanged: (value) {
                                      if (_guest && value == 'work') {
                                        _showGuestAccountSheet();
                                        return;
                                      }
                                      _changeAssistantMode(value);
                                    },
                                    onPrompt: (prompt) => _send(prompt),
                                  )
                                : NotificationListener<UserScrollNotification>(
                                    onNotification: _handleUserScrollNotification,
                                    child: RefreshIndicator(
                                      onRefresh: () => _refresh(),
                                      child: ListView.builder(
                                        controller: _scrollController,
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                        padding: EdgeInsets.fromLTRB(
                                          exactMobileDesign ? 14 : 24,
                                          exactMobileDesign ? 16 : 18,
                                          exactMobileDesign ? 14 : 24,
                                          exactMobileDesign ? 112 : 22,
                                        ),
                                        itemCount: _messages.length + (_typing ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (_typing && index == _messages.length) {
                                            return const _ThinkingBubble();
                                          }
                                          final item = _messages[index];
                                          final senderType = item['sender_type']?.toString() ?? '';
                                          final lastBotIndex = _messages.lastIndexWhere(
                                            (entry) => entry['sender_type']?.toString() == 'bot',
                                          );
                                          if (exactMobileDesign) {
                                            return _ExactMobileMessageBubble(
                                              message: item,
                                              onSpeak: senderType == 'bot'
                                                  ? () => _speakAssistantReply(item['message']?.toString() ?? '')
                                                  : null,
                                              onRegenerate: !_guest && senderType == 'bot' && index == lastBotIndex
                                                  ? _regenerateLastAnswer
                                                  : null,
                                              onAiAction: !_guest && senderType == 'bot'
                                                  ? _handleAiAgentAction
                                                  : null,
                                            );
                                          }
                                          return _MessageBubble(
                                            message: item,
                                            onSpeak: senderType == 'bot'
                                                ? () => _speakAssistantReply(item['message']?.toString() ?? '')
                                                : null,
                                            onRegenerate: !_guest && senderType == 'bot' && index == lastBotIndex
                                                ? _regenerateLastAnswer
                                                : null,
                                            onAiAction: !_guest && senderType == 'bot'
                                                ? _handleAiAgentAction
                                                : null,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                          ),
                          if (MediaQuery.sizeOf(context).width > 960 &&
                              !showHome &&
                              !closed &&
                              !_sending &&
                              aiMode &&
                              !hasCustomerMessage)
                            _QuickPrompts(
                              prompts: _quickPrompts,
                              onPrompt: _send,
                            ),
                          if (exactMobileDesign)
                            _ExactMobileComposer(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              onFocusRequested: _showMessageKeyboard,
                              sending: _sending,
                              enabled: true,
                              canAttach: !_guest && !closed && aiMode && _filePluginEnabled,
                              selectedFile: _selectedFile,
                              uploadProgress: _fileUploadProgress,
                              onAttach: _pickAssistantFile,
                              onClearAttachment: () => setState(() {
                                _selectedFile = null;
                                _fileUploadProgress = 0;
                              }),
                              onVoice: _toggleOneTurnVoice,
                              listening: _voiceListening,
                              voiceEnabled: aiMode && !closed && _voicePluginEnabled,
                              onSend: () => _send(),
                            )
                          else
                          _Composer(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            onFocusRequested: _showMessageKeyboard,
                            sending: _sending,
                            enabled: _guest || (!closed && aiMode),
                            canAttach: !_guest && !closed && aiMode && _filePluginEnabled,
                            selectedFile: _selectedFile,
                            uploadProgress: _fileUploadProgress,
                            disabledHint: (_guest || aiMode)
                                ? null
                                : 'هذه التذكرة مع الدعم. اضغط جلسة AI جديدة للرد الفوري.',
                            onAttach: _pickAssistantFile,
                            onClearAttachment: () => setState(() {
                              _selectedFile = null;
                              _fileUploadProgress = 0;
                            }),
                            onVoice: _toggleOneTurnVoice,
                            listening: _voiceListening,
                            voiceEnabled: aiMode && !closed && _voicePluginEnabled,
                            selectedMode: _assistantMode,
                            profiles: _assistantProfiles,
                            guest: _guest,
                            onModeChanged: (value) {
                              if (_guest && value != 'chat') {
                                _showGuestAccountSheet();
                                return;
                              }
                              _changeAssistantMode(value);
                            },
                            onSend: () => _send(),
                          ),
                        ],
                      ),
                  ),
                ),
              ),
              if (_draggingAssistantFile)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: const Color(0xD9020814),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 430),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1628) : Theme.of(context).colorScheme.surface),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)), width: 1.6),
                          boxShadow: const [
                            BoxShadow(color: Color(0x66000000), blurRadius: 34, offset: Offset(0, 16)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.file_download_outlined, size: 52, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490))),
                            SizedBox(height: 14),
                            TrText('أفلت الملف هنا',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 8),
                            TrText('صور، فيديو، صوت، PDF، Office، ملفات برمجية، مضغوطة وأي امتداد آخر',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF9FB2CE) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.6, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}



// desktop_drop targets desktop drag-and-drop. On mobile, render the same
// child directly so its native TextField receives touch/IME events normally.
class _AssistantPlatformDropTarget extends StatelessWidget {
  final Widget child;
  final void Function(dynamic) onDragEntered;
  final void Function(dynamic) onDragExited;
  final void Function(dynamic) onDragDone;

  const _AssistantPlatformDropTarget({
    required this.child,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDragDone,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) return child;
    return DropTarget(
      onDragEntered: (details) => onDragEntered(details),
      onDragExited: (details) => onDragExited(details),
      onDragDone: (details) => onDragDone(details),
      child: child,
    );
  }
}

class _ExactAiMobileHeader extends StatelessWidget {
  final VoidCallback onMenu;
  final VoidCallback onNewChat;
  final VoidCallback onShare;
  final VoidCallback onOptions;
  final String selectedProfile;
  final List<Map<String, dynamic>> profiles;
  final bool guest;
  final ValueChanged<String> onModeChanged;

  const _ExactAiMobileHeader({
    required this.onMenu,
    required this.onNewChat,
    required this.onShare,
    required this.onOptions,
    required this.selectedProfile,
    required this.profiles,
    required this.guest,
    required this.onModeChanged,
  });

  static const _versions = <String, String>{
    'fast': 'V1',
    'smart': 'V2',
    'programming': 'V3',
    'engineering': 'V4',
    'design3d': 'V5',
    'expert': 'V6',
  };

  Map<String, dynamic> get _activeProfile {
    for (final profile in profiles) {
      if (profile['key']?.toString() == selectedProfile) return profile;
    }
    return {'key': 'fast', 'label': 'إجابة سريعة'.tr(), 'credits': 1};
  }

  void _openVersionSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF171719) : Theme.of(context).scaffoldBackgroundColor),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            children: [
              TrText('اختر مستوى المساعد', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              TrText('يُحجز رصيد تقديري عند الإرسال، ثم يُخصم الاستهلاك الفعلي بعد الرد.',
                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFA1A1AA) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
              const SizedBox(height: 14),
              for (final profile in profiles)
                Builder(builder: (context) {
                  final key = profile['key']?.toString() ?? 'fast';
                  final allowed = guest ? key == 'fast' : profile['enabled'] != false;
                  final selected = key == selectedProfile;
                  final cost = int.tryParse('${profile['credits'] ?? 1}') ?? 1;
                  final version = _versions[key] ?? 'V1';
                  final label = profile['label']?.toString() ?? 'إجابة سريعة';
                  final description = profile['description']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Material(
                      color: selected ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF)) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF202024) : const Color(0xFFFFFFFF)),
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: allowed ? () {
                          Navigator.of(sheetContext).pop();
                          onModeChanged(key);
                        } : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(children: [
                            Icon(selected ? Icons.check_circle_rounded : (allowed ? Icons.auto_awesome_outlined : Icons.lock_outline_rounded),
                                color: selected ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA1A1AA) : const Color(0xFF475569)), size: 19),
                            const SizedBox(width: 9),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$version · $label', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: allowed ? Colors.white : const Color(0xFF71717A), fontWeight: FontWeight.w700, fontSize: 13)),
                              if (description.isNotEmpty) Text(trUi(description), maxLines: 2,
                                  overflow: TextOverflow.ellipsis, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFA1A1AA) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10)),
                            ])),
                            const SizedBox(width: 8),
                            Text(trUi(allowed ? 'حسب الاستهلاك' : (profile['requires_plan']?.toString() ?? 'ترقية')),
                                style: TextStyle(color: allowed ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)) : const Color(0xFF71717A), fontSize: 10, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget iconButton({required IconData icon, required VoidCallback onTap, required String tooltip}) {
      return Tooltip(
        message: trUiN(tooltip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA1A1AA) : Color(0xFF475569))),
          ),
        ),
      );
    }

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xE6121214) : const Color(0xFFF8FAFF)),
        border: Border(bottom: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF27272A) : const Color(0xFFD7E3F3)))),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconButton(icon: Icons.menu_rounded, onTap: onMenu, tooltip: 'فتح القائمة الجانبية'.tr()),
              iconButton(icon: Icons.add_rounded, onTap: onNewChat, tooltip: 'محادثة جديدة'.tr()),
            ],
          ),
          Expanded(
            child: Center(
              child: InkWell(
                onTap: () => _openVersionSelector(context),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xE617171A) : const Color(0xFFFFFFFF)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0x993F3F46) : const Color(0xFFD7E3F3))),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_versions[selectedProfile] ?? 'V1'} (${_activeProfile['label']?.toString() ?? 'إجابة سريعة'})'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE4E4E7) : const Color(0xFF17253C)),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFA1A1AA) : Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconButton(icon: Icons.share_outlined, onTap: onShare, tooltip: 'مشاركة المحادثة'.tr()),
              iconButton(icon: Icons.more_vert_rounded, onTap: onOptions, tooltip: 'خيارات إضافية'.tr()),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExactMobileMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback? onSpeak;
  final VoidCallback? onRegenerate;
  final Future<void> Function(Map<String, dynamic> action, String command)? onAiAction;

  const _ExactMobileMessageBubble({
    required this.message,
    this.onSpeak,
    this.onRegenerate,
    this.onAiAction,
  });

  static String? _timeLabel(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final senderType = message['sender_type']?.toString() ?? '';
    final own = senderType == 'customer';
    final system = senderType == 'system';
    final text = message['message']?.toString() ?? '';
    final time = _timeLabel(message['created_at']?.toString());
    final attachmentPath = message['_attachment_path']?.toString();
    final attachmentUrl = message['attachment_api_url']?.toString() ?? message['attachment_url']?.toString();
    final attachmentName = message['_attachment_name']?.toString() ?? message['attachment_name']?.toString() ?? (attachmentPath == null ? null : attachmentPath.split(Platform.pathSeparator).last);
    final attachmentSize = int.tryParse('${message['_attachment_size'] ?? message['attachment_size'] ?? ''}') ?? 0;
    final backendMime = message['attachment_mime']?.toString() ?? '';
    final attachmentKind = message['_attachment_kind']?.toString() ?? _backendAttachmentKind(backendMime, attachmentName);
    final attachmentUploading = message['_attachment_uploading'] == true;
    final attachmentError = message['_attachment_error'] == true;
    final aiAction = message['ai_action'] is Map
        ? Map<String, dynamic>.from(message['ai_action'] as Map)
        : null;

    if (system) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 7),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.dark ? const Color(0x9918171B) : const Color(0xFFEDF3FD)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xE627272A) : const Color(0xFFD7E3F3))),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF60A5FA) : Color(0xFF1D4ED8))),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  trUi(text),
                  style: GoogleFonts.tajawal(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA1A1AA) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (own) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 7),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF27272A) : Theme.of(context).colorScheme.surface),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(5),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0x803F3F46) : const Color(0xFFD7E3F3))),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty)
                      SelectableText(
                        trUi(text),
                        style: GoogleFonts.tajawal(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF4F4F5) : const Color(0xFF17253C)), fontSize: 14, height: 1.6),
                      ),
                    if ((attachmentPath != null || attachmentUrl != null) && attachmentName != null) ...[
                      const SizedBox(height: 9),
                      _MessageAttachmentCard(
                        name: attachmentName,
                        size: attachmentSize,
                        kind: attachmentKind,
                        path: attachmentPath,
                        url: attachmentUrl,
                        uploading: attachmentUploading,
                        error: attachmentError,
                      ),
                    ],
                  ],
                ),
              ),
              if (time != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 4),
                  child: TrText('$time  •  تم التسليم',
                    style: GoogleFonts.jetBrainsMono(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF71717A) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 9),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF6366F1)]),
                  boxShadow: [BoxShadow(color: Color(0x332563EB), blurRadius: 12)],
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 9),
              TrText('مساعد الوليد الهندسية',
                style: GoogleFonts.tajawal(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4D4D8) : const Color(0xFF24364F)), fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if ((message['ai_thinking']?.toString().trim() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: _ThinkingPanel(text: message['ai_thinking'].toString()),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ExactAssistantText(text: text),
          ),
          if ((attachmentPath != null || attachmentUrl != null) && attachmentName != null) ...[
            const SizedBox(height: 10),
            _MessageAttachmentCard(
              name: attachmentName,
              size: attachmentSize,
              kind: attachmentKind,
              path: attachmentPath,
              url: attachmentUrl,
              uploading: attachmentUploading,
              error: attachmentError,
            ),
          ],
          if (aiAction != null) ...[
            const SizedBox(height: 12),
            _AiAgentApprovalCard(action: aiAction, onAction: onAiAction),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              _ExactResponseIcon(icon: Icons.copy_rounded, tooltip: 'نسخ'.tr(), onTap: () => Clipboard.setData(ClipboardData(text: text))),
              if (onRegenerate != null)
                _ExactResponseIcon(icon: Icons.refresh_rounded, tooltip: 'إعادة التوليد'.tr(), onTap: onRegenerate!),
              _ExactResponseIcon(icon: Icons.thumb_up_alt_outlined, tooltip: 'إجابة مفيدة'.tr(), onTap: () {}),
              _ExactResponseIcon(icon: Icons.thumb_down_alt_outlined, tooltip: 'إجابة غير دقيقة'.tr(), onTap: () {}),
              if (onSpeak != null)
                _ExactResponseIcon(icon: Icons.volume_up_outlined, tooltip: 'استماع'.tr(), onTap: onSpeak!),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExactAssistantText extends StatelessWidget {
  final String text;
  const _ExactAssistantText({required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = text.split('```');
    final widgets = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      final raw = parts[i];
      if (raw.trim().isEmpty) continue;
      if (i.isOdd) {
        var code = raw;
        var language = 'Code';
        final firstBreak = code.indexOf('\n');
        if (firstBreak > 0 && firstBreak < 24) {
          final first = code.substring(0, firstBreak).trim();
          if (RegExp(r'^[A-Za-z0-9_+#.-]+$').hasMatch(first)) {
            language = first;
            code = code.substring(firstBreak + 1);
          }
        }
        widgets.add(_ExactCodeBlock(code: code.trim(), language: language));
      } else {
        widgets.add(
          SelectableText(
            trUi(raw.trim()),
            style: GoogleFonts.tajawal(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE4E4E7) : const Color(0xFF17253C)), fontSize: 14, height: 1.75),
          ),
        );
      }
      widgets.add(const SizedBox(height: 10));
    }
    if (widgets.isNotEmpty) widgets.removeLast();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}

class _ExactCodeBlock extends StatelessWidget {
  final String code;
  final String language;
  const _ExactCodeBlock({required this.code, required this.language});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111113) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF27272A) : Theme.of(context).colorScheme.surface)),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 20, offset: Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF18181B) : Theme.of(context).colorScheme.surface),
            child: Row(
              children: [
                const _ExactTrafficDot(Color(0xCCF43F5E)),
                const SizedBox(width: 5),
                const _ExactTrafficDot(Color(0xCCF59E0B)),
                const SizedBox(width: 5),
                const _ExactTrafficDot(Color(0xCC10B981)),
                const SizedBox(width: 10),
                Text(trUi(language), style: GoogleFonts.jetBrainsMono(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA1A1AA) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                InkWell(
                  onTap: () => Clipboard.setData(ClipboardData(text: code)),
                  borderRadius: BorderRadius.circular(7),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFA1A1AA) : Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 4),
                        TrText('نسخ الكود', style: GoogleFonts.tajawal(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4D4D8) : const Color(0xFF24364F)), fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              code,
              textDirection: TextDirection.ltr,
              style: GoogleFonts.jetBrainsMono(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4D4D8) : const Color(0xFF17253C)), fontSize: 11.5, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExactTrafficDot extends StatelessWidget {
  final Color color;
  const _ExactTrafficDot(this.color);
  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _ExactResponseIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ExactResponseIcon({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: trUiN(tooltip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 17, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA1A1AA) : Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _ExactMobileComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onFocusRequested;
  final bool sending;
  final bool enabled;
  final bool canAttach;
  final File? selectedFile;
  final double uploadProgress;
  final VoidCallback onAttach;
  final VoidCallback onClearAttachment;
  final VoidCallback onVoice;
  final bool listening;
  final bool voiceEnabled;
  final VoidCallback onSend;

  const _ExactMobileComposer({
    required this.controller,
    required this.focusNode,
    required this.onFocusRequested,
    required this.sending,
    required this.enabled,
    required this.canAttach,
    required this.selectedFile,
    required this.uploadProgress,
    required this.onAttach,
    required this.onClearAttachment,
    required this.onVoice,
    required this.listening,
    required this.voiceEnabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: (Theme.of(context).brightness == Brightness.dark
                ? const [Color(0x0009090B), Color(0xF209090B), Color(0xFF09090B)]
                : const [Color(0x00F5F8FE), Color(0xFFF5F8FE), Color(0xFFF5F8FE)]),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedFile != null)
              _SelectedAttachmentCard(
                file: selectedFile!,
                progress: uploadProgress,
                sending: sending,
                onRemove: onClearAttachment,
              ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xF217171A) : const Color(0xFFFFFFFF)),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xB33F3F46)),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 10))],
              ),
              child: Row(
                children: [
                  if (canAttach)
                    InkWell(
                      onTap: sending ? null : onAttach,
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF27272A) : Theme.of(context).colorScheme.surface), shape: BoxShape.circle),
                        child: const Icon(Icons.add_rounded, size: 21, color: Color(0xFFD4D4D8)),
                      ),
                    ),
                  if (canAttach) const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onTap: onFocusRequested,
                      enabled: true,
                      minLines: 1,
                      maxLines: 4,
                      textDirection: AppLanguage.instance.textDirection,
                      textInputAction: TextInputAction.newline,
                      style: GoogleFonts.tajawal(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF4F4F5) : const Color(0xFF17253C)), fontSize: 14, height: 1.4),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        hintText: trUiN(selectedFile != null ? 'اسأل عن الملف المرفق...' : 'اسأل أي سؤال برمجي أو اطرح خطأً...'),
                        hintStyle: GoogleFonts.tajawal(color: const Color(0xFF71717A), fontSize: 13),
                      ),
                      onSubmitted: (_) {
                        if (enabled && !sending) onSend();
                      },
                    ),
                  ),
                  if (voiceEnabled)
                    InkWell(
                      onTap: sending ? null : onVoice,
                      borderRadius: BorderRadius.circular(99),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(trUi(listening ? 'يستمع' : 'صوتي'), style: GoogleFonts.jetBrainsMono(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA1A1AA) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10.5)),
                            const SizedBox(width: 4),
                            Icon(listening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded, size: 17, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA1A1AA) : Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 3),
                  InkWell(
                    onTap: (!enabled || sending) ? null : onSend,
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (!enabled || sending) ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3F3F46) : const Color(0xFFE9F0FA)) : const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        boxShadow: (!enabled || sending) ? null : const [BoxShadow(color: Color(0x4D3B82F6), blurRadius: 14)],
                      ),
                      child: sending
                          ? Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A))),
                            )
                          : Icon(Icons.arrow_upward_rounded, size: 18, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            TrText('قد يقع الذكاء الاصطناعي في الخطأ أحياناً. تحقق دائماً من سلامة الأكواد والملفات البرمجية.',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF71717A) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantHomeHero extends StatelessWidget {
  final String selectedMode;
  final bool guest;
  final VoidCallback onMenu;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String> onPrompt;

  const _AssistantHomeHero({
    required this.selectedMode,
    required this.guest,
    required this.onMenu,
    required this.onModeChanged,
    required this.onPrompt,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final desktopLike = constraints.maxWidth > 760;
        final horizontal = desktopLike ? constraints.maxWidth * .16 : (compact ? 18.0 : 28.0);
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (constraints.maxHeight - 46).clamp(520.0, 860.0).toDouble()),
            child: Column(
              children: [
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    const SizedBox(width: 52),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xD70B1930) : const Color(0xFFFFFFFF)),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: const Color(0x3D60A5FA)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x302563EB), blurRadius: 24),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _AssistantModePill(
                                    label: 'العمل',
                                    active: selectedMode == 'work',
                                    onTap: () => onModeChanged('work'),
                                  ),
                                ),
                                Expanded(
                                  child: _AssistantModePill(
                                    label: 'الدردشة',
                                    active: selectedMode != 'work',
                                    onTap: () => onModeChanged('chat'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: onMenu,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0x99101D32) : const Color(0xFFFFFFFF)),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x553B82F6)),
                          boxShadow: const [BoxShadow(color: Color(0x252563EB), blurRadius: 18)],
                        ),
                        child: Icon(Icons.menu_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5EEF9) : Theme.of(context).colorScheme.onSurface), size: 24),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 74 : 92),
                const _AssistantGlowOrb(size: 64),
                const SizedBox(height: 28),
                TrText('مساعد منصة الوليد الهندسية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF17253C)),
                    fontSize: compact ? 22 : 27,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                const TrText('اسأل، خطط، وأنجز بثقة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF90A9CC), fontSize: 15, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: compact ? 82 : 112),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      _AssistantHomeRow(
                        title: 'اتجاهات إعادة الإعمار بعد النزاعات',
                        icon: Icons.auto_awesome_rounded,
                        onTap: () => onPrompt('حلل لي أحدث اتجاهات إعادة الإعمار بعد النزاعات من منظور هندسي وعملي.'),
                      ),
                      _AssistantHomeRow(
                        title: 'Gmail  ·  تواصل',
                        icon: Icons.mail_outline_rounded,
                        onTap: () => onPrompt('ساعدني في صياغة رسالة بريد إلكتروني هندسية احترافية.'),
                      ),
                      _AssistantHomeRow(
                        title: 'Google Drive  ·  تواصل',
                        icon: Icons.cloud_outlined,
                        onTap: () => onPrompt('أريد تحليل ملف هندسي؛ ساعدني في تحديد ما أحتاج رفعه وتحليله.'),
                      ),
                    ],
                  ),
                ),
                if (guest) ...[
                  const SizedBox(height: 28),
                  TrText('وضع الزائر • سجّل الدخول لحفظ المحادثات واستخدام وضع العمل',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuLine extends StatelessWidget {
  const _MenuLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 2,
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _AssistantModePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _AssistantModePill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: active ? const Color(0x551D4ED8) : Colors.transparent,
          border: Border.all(color: active ? const Color(0xFF2FA8FF) : Colors.transparent),
          boxShadow: active ? const [BoxShadow(color: Color(0x553B82F6), blurRadius: 18)] : const [],
        ),
        child: Text(
          trUi(label),
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF9FB1CB),
            fontSize: 15,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AssistantGlowOrb extends StatelessWidget {
  final double size;
  const _AssistantGlowOrb({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.22, -.28),
          colors: [Color(0xFFF6FBFF), Color(0xFF5DD7FF), Color(0xFF5B6FFF), Color(0xFFD97BFF)],
          stops: [0, .34, .68, 1],
        ),
        border: Border.all(color: const Color(0xCCBFE7FF), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0xAA2563EB), blurRadius: 34, spreadRadius: 5),
          BoxShadow(color: Color(0x5538BDF8), blurRadius: 70, spreadRadius: 12),
        ],
      ),
      child: Center(
        child: Container(
          width: size * .34,
          height: size * .34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFF87F0FF), Color(0xFF6B5CFF)]),
          ),
        ),
      ),
    );
  }
}

class _AssistantHomeRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _AssistantHomeRow({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF10213A) : Theme.of(context).colorScheme.surface), shape: BoxShape.circle),
                child: Icon(Icons.chevron_right_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5EEF9) : Theme.of(context).colorScheme.onSurface), size: 23),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  trUi(title),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFF1F5F9) : Theme.of(context).colorScheme.onSurface), fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A1830) : Theme.of(context).colorScheme.surface),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x4438BDF8)),
                  boxShadow: const [BoxShadow(color: Color(0x332563EB), blurRadius: 16)],
                ),
                child: Icon(icon, color: const Color(0xFF7DD3FC), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileAssistantChatHeader extends StatelessWidget {
  final String selectedMode;
  final bool guest;
  final VoidCallback onMenu;
  final ValueChanged<String> onModeChanged;

  const _MobileAssistantChatHeader({
    required this.selectedMode,
    required this.guest,
    required this.onMenu,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF020814) : Theme.of(context).scaffoldBackgroundColor),
        border: Border(bottom: BorderSide(color: Color(0x242563EB))),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          InkWell(
            onTap: onMenu,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF07162B) : Theme.of(context).colorScheme.surface),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xAA2F7DD3)),
              ),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 14,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      _MenuLine(),
                      _MenuLine(),
                      _MenuLine(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 42,
              constraints: const BoxConstraints(maxWidth: 310),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF07162B) : Theme.of(context).colorScheme.surface),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x883B82F6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _AssistantModePill(
                      label: 'العمل',
                      active: selectedMode == 'work',
                      onTap: () {
                        if (guest) return;
                        onModeChanged('work');
                      },
                    ),
                  ),
                  Expanded(
                    child: _AssistantModePill(
                      label: 'الدردشة',
                      active: selectedMode != 'work',
                      onTap: () => onModeChanged('chat'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantHeader extends StatelessWidget {
  final String mode;
  final String status;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onNewAiSession;
  final bool showNewAiSession;
  final String? aiPlan;
  final String? aiCreditsLabel;
  final VoidCallback onPremium;
  final VoidCallback onHistory;
  final bool guest;
  final VoidCallback onVoiceConversation;
  final bool voiceConversation;
  final bool voiceEnabled;
  final int voiceCost;

  const _AssistantHeader({
    required this.mode,
    required this.status,
    required this.onBack,
    required this.onRefresh,
    required this.onNewAiSession,
    required this.showNewAiSession,
    required this.aiPlan,
    required this.aiCreditsLabel,
    required this.onPremium,
    required this.onHistory,
    required this.guest,
    required this.onVoiceConversation,
    required this.voiceConversation,
    required this.voiceEnabled,
    required this.voiceCost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xF2050B14),
        border: Border(bottom: BorderSide(color: Color(0x1494A3B8))),
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.ltr,
            children: [
              _MiniCircleButton(
                tooltip: 'المحادثات والقائمة'.tr(),
                icon: Icons.menu_rounded,
                onPressed: onHistory,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Directionality(
                  textDirection: AppLanguage.instance.textDirection,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        padding: const EdgeInsets.all(1.2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF0EA5E9), Color(0xFF10B981)],
                          ),
                          boxShadow: const [BoxShadow(color: Color(0x442563EB), blurRadius: 16)],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF08111F) : Theme.of(context).colorScheme.surface),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TrText('مساعد منصة الوليد الهندسية',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.circle, size: 6, color: Color(0xFF22C55E)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    trUi(guest ? 'متاح للزوار' : 'متصل وجاهز للمساعدة'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 9, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _MiniCircleButton(
                tooltip: trUi(guest ? 'الباقات والحساب' : 'دردشة جديدة'),
                icon: guest ? Icons.workspace_premium_outlined : Icons.edit_note_rounded,
                onPressed: guest ? onPremium : onNewAiSession,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            textDirection: TextDirection.ltr,
            children: [
              InkWell(
                onTap: onPremium,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A1728) : Theme.of(context).colorScheme.surface),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x1F94A3B8)),
                  ),
                  child: Directionality(
                    textDirection: AppLanguage.instance.textDirection,
                    child: Text(
                      trUi(guest ? '100 Credit هدية' : '${aiPlan ?? 'AI'} • ${aiCreditsLabel ?? '0'} Credit'),
                      style: TextStyle(fontSize: 8.7, fontWeight: FontWeight.w800, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF93C5FD) : Color(0xFF1D4ED8))),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: voiceEnabled ? onVoiceConversation : null,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: voiceConversation ? const Color(0x337F1D1D) : const Color(0x330B4D63),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: voiceConversation ? const Color(0x55EF4444) : const Color(0x3D06B6D4)),
                  ),
                  child: Directionality(
                    textDirection: AppLanguage.instance.textDirection,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(voiceConversation ? Icons.call_end_rounded : Icons.mic_rounded, size: 13, color: voiceConversation ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490))),
                        const SizedBox(width: 4),
                        Text(
                          trUi(!voiceEnabled
                              ? 'الصوت معطّل'
                              : voiceConversation
                                  ? 'إنهاء الصوت'
                                  : (guest ? 'محادثة صوتية' : 'محادثة صوتية • حسب الاستهلاك')),
                          style: TextStyle(fontSize: 8.8, fontWeight: FontWeight.w800, color: voiceConversation ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCircleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _MiniCircleButton({required this.tooltip, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: trUiN(tooltip),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0x0EFFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0DFFFFFF) : AppColors.borderSoft),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _HeaderTextButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _HeaderTextButton({required this.onPressed, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x0BFFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x12FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(width: 4),
            Text(trUi(label), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant))),
          ],
        ),
      ),
    );
  }
}

class _ConversationStatus extends StatelessWidget {
  final String mode;
  final String status;
  final VoidCallback? onTransfer;
  final VoidCallback? onResolve;
  final VoidCallback? onNewAiSession;

  const _ConversationStatus({
    required this.mode,
    required this.status,
    required this.onTransfer,
    required this.onResolve,
    required this.onNewAiSession,
  });

  @override
  Widget build(BuildContext context) {
    final guest = mode == 'guest';
    final supportMode = mode == 'employee' || mode == 'waiting_employee';
    final text = switch (mode) {
      'guest' => 'وضع الزائر: احفظ محادثاتك بعد التسجيل',
      'employee' => 'هذه المحادثة مع موظف الدعم البشري',
      'waiting_employee' => 'هذه المحادثة بانتظار موظف الدعم',
      _ => 'المساعد الذكي متصل ببيانات المنصة وجاهز لمساعدتك',
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x66231D54), Color(0x99111A2C), Color(0x66231D54)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x263B82F6)),
      ),
      child: Row(
        children: [
          Icon(
            guest ? Icons.info_outline_rounded : Icons.auto_awesome_rounded,
            size: 15,
            color: guest ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFF92400E)) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490)),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              trUi(text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, height: 1.4, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
          if (guest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x99083344),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0x3306B6D4)),
              ),
              child: TrText('100 Credit هدية', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF22D3EE) : Color(0xFF0E7490)))),
            )
          else if (supportMode && onNewAiSession != null)
            TextButton(
              onPressed: onNewAiSession,
              style: TextButton.styleFrom(foregroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490)), visualDensity: VisualDensity.compact),
              child: const TrText('جلسة AI', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900)),
            ),
          if (!guest && !supportMode && onResolve != null)
            PopupMenuButton<String>(
              tooltip: 'خيارات الدعم'.tr(),
              iconSize: 17,
              iconColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant),
              onSelected: (value) {
                if (value == 'transfer') onTransfer?.call();
                if (value == 'resolve') onResolve?.call();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'transfer', child: TrText('تحويل لموظف الدعم')),
                PopupMenuItem(value: 'resolve', child: TrText('تم حل المشكلة')),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onPrompt;

  const _QuickPrompts({required this.prompts, required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText('أسئلة مقترحة للبدء السريع:',
            style: TextStyle(fontSize: 9.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: prompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final prompt = prompts[index];
                return ActionChip(
                  label: Text(trUi(prompt), style: TextStyle(fontSize: 9.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant))),
                  onPressed: () => onPrompt(prompt),
                  side: const BorderSide(color: Color(0x12FFFFFF)),
                  backgroundColor: const Color(0x99304159),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _prettyFileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

bool _isImageAttachmentName(String name) => RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false).hasMatch(name);

String _backendAttachmentKind(String mime, String? name) {
  final normalizedMime = mime.toLowerCase();
  final normalizedName = (name ?? '').toLowerCase();
  if (normalizedMime.startsWith('image/') || _isImageAttachmentName(normalizedName)) return 'image';
  if (normalizedMime.contains('pdf') || normalizedName.endsWith('.pdf')) return 'pdf';
  if (normalizedMime.startsWith('video/') || RegExp(r'\.(mp4|mov|webm|m4v)$').hasMatch(normalizedName)) return 'video';
  if (normalizedMime.contains('wordprocessingml') || normalizedMime.contains('msword') || RegExp(r'\.docx?$').hasMatch(normalizedName)) return 'document';
  if (normalizedMime.contains('spreadsheetml') || normalizedMime.contains('excel') || RegExp(r'\.xlsx?$').hasMatch(normalizedName)) return 'sheet';
  if (normalizedMime.contains('zip') || normalizedName.endsWith('.zip')) return 'archive';
  if (normalizedMime.contains('csv') || normalizedName.endsWith('.csv')) return 'csv';
  if (normalizedMime.startsWith('text/')) return 'text';
  return 'file';
}

class _AiAgentApprovalCard extends StatelessWidget {
  final Map<String, dynamic> action;
  final Future<void> Function(Map<String, dynamic> action, String command)? onAction;

  const _AiAgentApprovalCard({required this.action, this.onAction});

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'بانتظار موافقتك';
      case 'executed': return 'تم التنفيذ';
      case 'cancelled': return 'ملغاة';
      case 'expired': return 'منتهية';
      case 'superseded': return 'تم استبدالها بمسودة أحدث';
      default: return status;
    }
  }

  String _number(dynamic value) {
    if (value == null) return '0';
    final n = num.tryParse(value.toString());
    if (n == null) return value.toString();
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final type = action['type']?.toString() ?? '';
    final status = action['status']?.toString() ?? '';
    final title = action['title']?.toString() ?? 'مراجعة إجراء المساعد';
    final preview = action['preview'] is Map
        ? Map<String, dynamic>.from(action['preview'] as Map)
        : <String, dynamic>{};
    final warnings = (preview['warnings'] is List)
        ? List<dynamic>.from(preview['warnings'] as List)
        : const <dynamic>[];
    final pending = status == 'pending';
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final body = <Widget>[];
    if (type == 'create_meeting_tasks') {
      final tasks = preview['tasks'] is List ? List<dynamic>.from(preview['tasks'] as List) : const <dynamic>[];
      body.add(TrText('المرحلة: ${preview['milestone_title'] ?? '-'} • عدد المهام: ${tasks.length}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      for (var i = 0; i < tasks.length; i++) {
        final task = tasks[i] is Map ? Map<String, dynamic>.from(tasks[i] as Map) : <String, dynamic>{};
        final assignee = (task['assigned_name']?.toString().trim().isNotEmpty ?? false)
            ? task['assigned_name'].toString()
            : 'غير مسندة';
        final due = task['due_date']?.toString();
        body.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF18181B) : scheme.surfaceContainerHighest.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${i + 1}. ${task['title'] ?? 'مهمة'}'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              TrText('المسؤول: $assignee${due == null || due.isEmpty ? '' : ' • الموعد: $due'} • الأولوية: ${task['priority'] ?? 'medium'}'),
              if ((task['description']?.toString().trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 4),
                Text(trUi(task['description'].toString())),
              ],
            ],
          ),
        ));
      }
    } else if (type == 'approve_boq') {
      final sections = preview['sections'] is List ? List<dynamic>.from(preview['sections'] as List) : const <dynamic>[];
      body.add(Text(
        '${preview['title'] ?? 'BOQ'} • ${preview['items_count'] ?? 0} بند • الإجمالي: ${_number(preview['grand_total'])} ${preview['currency'] ?? ''}'.tr(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      for (final rawSection in sections) {
        final section = rawSection is Map ? Map<String, dynamic>.from(rawSection) : <String, dynamic>{};
        final items = section['items'] is List ? List<dynamic>.from(section['items'] as List) : const <dynamic>[];
        body.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 3),
          child: Text('${section['code'] ?? ''} ${section['name'] ?? 'قسم'}'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
        ));
        for (final rawItem in items) {
          final item = rawItem is Map ? Map<String, dynamic>.from(rawItem) : <String, dynamic>{};
          body.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF18181B) : scheme.surfaceContainerHighest.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['item_code'] ?? ''} — ${item['description'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${_number(item['quantity'])} ${item['unit'] ?? ''} × ${_number(item['unit_rate'])} = ${_number(item['total_amount'])} ${preview['currency'] ?? ''}'),
                if (item['is_estimate'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: TrText('⚠ قيمة تقديرية / تحتاج مراجعة'),
                  ),
              ],
            ),
          ));
        }
      }
    }

    if (warnings.isNotEmpty) {
      body.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: dark ? .18 : .55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.tertiary.withValues(alpha: .35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TrText('ملاحظات قبل الاعتماد', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('• $w'),
            )),
          ],
        ),
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111827) : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pending ? scheme.primary.withValues(alpha: .45) : scheme.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(pending ? Icons.verified_user_outlined : Icons.task_alt_rounded, size: 19, color: pending ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Expanded(child: Text(trUi(title), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
              Text(trUi(_statusLabel(status)), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pending ? scheme.primary : scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body)),
          ),
          if (pending && onAction != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: action['can_confirm'] == true ? () => onAction!(action, 'confirm') : null,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const TrText('اعتماد وتنفيذ'),
                ),
                OutlinedButton.icon(
                  onPressed: action['can_edit'] == true ? () => onAction!(action, 'edit') : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const TrText('تعديل'),
                ),
                TextButton.icon(
                  onPressed: action['can_cancel'] == true ? () => onAction!(action, 'cancel') : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const TrText('إلغاء'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback? onSpeak;
  final VoidCallback? onRegenerate;
  final Future<void> Function(Map<String, dynamic> action, String command)? onAiAction;

  const _MessageBubble({
    required this.message,
    this.onSpeak,
    this.onRegenerate,
    this.onAiAction,
  });

  @override
  Widget build(BuildContext context) {
    final senderType = message['sender_type']?.toString() ?? '';
    final own = senderType == 'customer';
    final system = senderType == 'system';
    final senderName = message['sender'] is Map
        ? (message['sender'] as Map)['name']?.toString()
        : message['sender_name']?.toString();
    final label = own
        ? 'أنت'
        : senderType == 'bot'
            ? 'المهندس الذكي'
            : system
                ? 'تنبيه'
                : senderName ?? 'الدعم';
    final text = message['message']?.toString() ?? '';
    final time = _timeLabel(message['created_at']?.toString());
    final attachmentPath = message['_attachment_path']?.toString();
    final attachmentUrl = message['attachment_api_url']?.toString() ?? message['attachment_url']?.toString();
    final attachmentName = message['_attachment_name']?.toString() ?? message['attachment_name']?.toString() ?? (attachmentPath == null ? null : attachmentPath.split(Platform.pathSeparator).last);
    final attachmentSize = int.tryParse('${message['_attachment_size'] ?? message['attachment_size'] ?? ''}') ?? 0;
    final backendMime = message['attachment_mime']?.toString() ?? '';
    final attachmentKind = message['_attachment_kind']?.toString() ?? _backendAttachmentKind(backendMime, attachmentName);
    final attachmentUploading = message['_attachment_uploading'] == true;
    final attachmentError = message['_attachment_error'] == true;
    final aiAction = message['ai_action'] is Map
        ? Map<String, dynamic>.from(message['ai_action'] as Map)
        : null;

    return Align(
      alignment: system
          ? Alignment.center
          : own
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: own ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!system && !own)
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(trUi(label), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD6D6D6) : const Color(0xFF334155))),
                      if (time != null) ...[
                        const SizedBox(width: 6),
                        Text(trUi(time), style: TextStyle(fontSize: 8.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant))),
                      ],
                    ],
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: own ? 15 : (system ? 13 : 2),
                  vertical: own ? 11 : (system ? 11 : 4),
                ),
                decoration: BoxDecoration(
                  color: system
                      ? const Color(0x2978350F)
                      : own
                          ? const Color(0xFF123866)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(own ? 20 : 14),
                  border: system
                      ? Border.all(color: const Color(0x38F59E0B))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (system)
                      TrText('تنبيه', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFFDE68A) : Color(0xFF92400E)))),
                    if (!own && !system && (message['ai_thinking']?.toString().trim() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ThinkingPanel(text: message['ai_thinking'].toString()),
                      ),
                    if (text.isNotEmpty) ...[
                      if (system) const SizedBox(height: 4),
                      SelectableText(
                        trUi(text),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: system ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)) : own ? const Color(0xFFF1F5F9) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                          height: 1.7,
                        ),
                      ),
                    ],
                    if ((attachmentPath != null || attachmentUrl != null) && attachmentName != null) ...[
                      if (text.isNotEmpty) const SizedBox(height: 10),
                      _MessageAttachmentCard(
                        path: attachmentPath,
                        url: attachmentUrl,
                        name: attachmentName,
                        size: attachmentSize,
                        kind: attachmentKind,
                        uploading: attachmentUploading,
                        error: attachmentError,
                      ),
                    ],
                    if (aiAction != null) ...[
                      const SizedBox(height: 12),
                      _AiAgentApprovalCard(action: aiAction, onAction: onAiAction),
                    ],
                    if (own && time != null) ...[
                      const SizedBox(height: 5),
                      Text(trUi(time), style: const TextStyle(fontSize: 8.5, color: Color(0xFF9A9A9A))),
                    ],
                    if (!own && !system && text.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Container(height: 1, color: const Color(0x12FFFFFF)),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MessageToolButton(
                            icon: Icons.copy_rounded,
                            label: 'نسخ',
                            onPressed: () async => Clipboard.setData(ClipboardData(text: text)),
                          ),
                          if (onSpeak != null)
                            _MessageToolButton(icon: Icons.volume_up_outlined, label: 'استماع', onPressed: onSpeak!),
                          if (onRegenerate != null)
                            _MessageToolButton(icon: Icons.refresh_rounded, label: 'إعادة', onPressed: onRegenerate!),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _timeLabel(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}


class _MessageAttachmentCard extends StatelessWidget {
  final String? path;
  final String? url;
  final String name;
  final int size;
  final String kind;
  final bool uploading;
  final bool error;

  const _MessageAttachmentCard({
    this.path,
    this.url,
    required this.name,
    required this.size,
    required this.kind,
    required this.uploading,
    required this.error,
  });

  Future<void> _openAttachment(BuildContext context) async {
    if (uploading || error) return;
    try {
      File target;
      final local = path == null ? null : File(path!);
      if (local != null && local.existsSync()) {
        target = local;
      } else if (url != null && url!.trim().isNotEmpty) {
        target = await ApiService.downloadAuthenticatedUrl(url: url!, fileName: name);
      } else {
        throw Exception('attachment_unavailable');
      }
      await OpenFilex.open(target.path);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('تعذر فتح المرفق الآن. حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = kind == 'image' || _isImageAttachmentName(name);
    final localFile = path == null ? null : File(path!);
    final hasLocalImage = isImage && localFile != null && localFile.existsSync();
    final hasRemoteImage = isImage && (url?.isNotEmpty ?? false);
    final accent = error
        ? const Color(0xFFEF4444)
        : uploading
            ? const Color(0xFF3B82F6)
            : const Color(0xFF10B981);

    if (hasLocalImage || hasRemoteImage) {
      return GestureDetector(
        onTap: () => _openAttachment(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF071426) : Theme.of(context).colorScheme.surface),
              border: Border.all(color: const Color(0x2694A3B8)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasLocalImage)
                  Image.file(localFile!, height: 210, fit: BoxFit.cover, gaplessPlayback: true)
                else
                  FutureBuilder<Map<String, String>>(
                    future: ApiService.authenticatedMediaHeaders(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(height: 210, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                      }
                      return Image.network(
                        url!,
                        headers: snapshot.data,
                        height: 210,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : const SizedBox(height: 210, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorBuilder: (_, __, ___) => SizedBox(height: 160, child: Center(child: Icon(Icons.broken_image_outlined, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant), size: 36))),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trUi(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface))),
                            if (size > 0) Text(trUi(_prettyFileSize(size)), style: TextStyle(fontSize: 8.5, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant))),
                          ],
                        ),
                      ),
                      Icon(uploading ? Icons.cloud_upload_outlined : error ? Icons.error_outline_rounded : Icons.open_in_new_rounded, size: 18, color: accent),
                    ],
                  ),
                ),
                if (uploading) const LinearProgressIndicator(minHeight: 3, color: Color(0xFF3B82F6), backgroundColor: Color(0x1F94A3B8)),
              ],
            ),
          ),
        ),
      );
    }

    final icon = switch (kind) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'csv' || 'sheet' => Icons.table_chart_rounded,
      'document' => Icons.description_rounded,
      'archive' => Icons.folder_zip_rounded,
      'text' => Icons.subject_rounded,
      _ => Icons.insert_drive_file_outlined,
    };
    final fileColor = switch (kind) {
      'pdf' => const Color(0xFFEF4444),
      'csv' || 'sheet' => const Color(0xFF10B981),
      'document' => const Color(0xFF2563EB),
      'archive' => const Color(0xFF8B5CF6),
      _ => const Color(0xFF3B82F6),
    };
    final typeLabel = switch (kind) {
      'document' => 'WORD',
      'sheet' => 'EXCEL',
      'archive' => 'ZIP',
      _ => kind.toUpperCase(),
    };

    return InkWell(
      onTap: () => _openAttachment(context),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A172A) : Theme.of(context).colorScheme.surface),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0x2694A3B8)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: fileColor.withOpacity(.17), borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: Icon(icon, color: fileColor, size: 24),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trUi(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface))),
                  const SizedBox(height: 2),
                  Text('$typeLabel${size > 0 ? ' • ${_prettyFileSize(size)}' : ''} • اضغط للفتح'.tr(), style: TextStyle(fontSize: 8.5, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant))),
                  if (uploading) ...[
                    const SizedBox(height: 6),
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      child: LinearProgressIndicator(minHeight: 4, color: Color(0xFF3B82F6), backgroundColor: Color(0x1F94A3B8)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(uploading ? Icons.cloud_upload_outlined : error ? Icons.error_outline_rounded : Icons.open_in_new_rounded, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}

class _MessageToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _MessageToolButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(width: 4),
            Text(trUi(label), style: TextStyle(fontSize: 9, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant))),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String label;
  final bool own;

  const _Avatar({required this.label, required this.own});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: own
              ? const [Color(0xFF2563EB), Color(0xFF0F766E)]
              : const [Color(0xFF2563EB), Color(0xFF0891B2), Color(0xFF10B981)],
        ),
      ),
      padding: const EdgeInsets.all(1.2),
      child: Container(
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1220) : Theme.of(context).colorScheme.surface),
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          trUi(label),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF7DD3FC)),
        ),
      ),
    );
  }
}

/// Shown while the assistant works: live stage + elapsed seconds (like "Thinking…" in chat apps).
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> {
  static const _stages = <String>[
    'يفهم طلبك',
    'يراجع سياق المحادثة',
    'يختار الأداة المناسبة',
    'يفكر ويحلل',
    'يجهز الرد',
  ];
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final seconds = _clock.elapsed.inSeconds;
    // Move forward one stage every ~2.5 s and stay on the last one.
    final stage = _stages[(seconds ~/ 2.5).clamp(0, _stages.length - 1).toInt()];
    final muted = dark ? const Color(0xFFA1A1AA) : const Color(0xFF52627A);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF6366F1)]),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 40, height: 14, child: _TypingDots()),
          const SizedBox(width: 8),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                '${trUi('يفكر')} · ${trUi(stage)}…',
                key: ValueKey(stage),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('${seconds}s', style: TextStyle(color: muted.withValues(alpha: .7), fontSize: 11)),
        ],
      ),
    );
  }
}

/// The model's thought summary, collapsed by default above the answer.
class _ThinkingPanel extends StatefulWidget {
  final String text;
  const _ThinkingPanel({required this.text});

  @override
  State<_ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<_ThinkingPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? const Color(0x333F3F46) : const Color(0xFFDCE5F2);
    final muted = dark ? const Color(0xFFA1A1AA) : const Color(0xFF52627A);
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0x14FFFFFF) : const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    Icon(Icons.psychology_alt_outlined, size: 16, color: muted),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        trUi(_open ? 'إخفاء طريقة التفكير' : 'عرض طريقة التفكير'),
                        style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: muted),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SelectableText(
                widget.text.replaceAll(RegExp(r'\*\*'), ''),
                style: TextStyle(color: muted, fontSize: 12.5, height: 1.65),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (index) {
            final phase = (_controller.value + index * 0.18) % 1;
            final scale = phase < .5 ? 1 + phase : 2 - phase;
            return Transform.scale(
              scale: scale.clamp(.8, 1.25).toDouble(),
              child: DecoratedBox(
                decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan), shape: BoxShape.circle),
                child: SizedBox(width: 8, height: 8),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SelectedAttachmentCard extends StatelessWidget {
  final File file;
  final double progress;
  final bool sending;
  final VoidCallback onRemove;

  const _SelectedAttachmentCard({
    required this.file,
    required this.progress,
    required this.sending,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = file.path.split(Platform.pathSeparator).last;
    final isImage = _isImageAttachmentName(name);
    final size = file.existsSync() ? file.lengthSync() : 0;
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1729) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2B60A5FA)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: isImage && file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover, gaplessPlayback: true)
                  : Container(
                      color: ext == 'PDF' ? const Color(0x332391F7) : const Color(0x332563EB),
                      alignment: Alignment.center,
                      child: Icon(ext == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_outlined, color: ext == 'PDF' ? const Color(0xFFF87171) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))),
                    ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trUi(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface))),
                const SizedBox(height: 2),
                Text('$ext${size > 0 ? ' • ${_prettyFileSize(size)}' : ''}', style: TextStyle(fontSize: 8.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant))),
                if (sending || progress > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: progress > 0 && progress < 1 ? progress : (sending ? null : 1),
                      color: progress >= 1 ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                      backgroundColor: const Color(0x1F94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: sending ? null : onRemove,
            icon: Icon(Icons.close_rounded, size: 18, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}


class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onFocusRequested;
  final bool sending;
  final bool enabled;
  final bool canAttach;
  final File? selectedFile;
  final double uploadProgress;
  final String? disabledHint;
  final VoidCallback onAttach;
  final VoidCallback onClearAttachment;
  final VoidCallback onVoice;
  final bool listening;
  final bool voiceEnabled;
  final String selectedMode;
  final List<Map<String, dynamic>> profiles;
  final bool guest;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onFocusRequested,
    required this.sending,
    required this.enabled,
    required this.canAttach,
    required this.selectedFile,
    required this.uploadProgress,
    this.disabledHint,
    required this.onAttach,
    required this.onClearAttachment,
    required this.onVoice,
    required this.listening,
    required this.voiceEnabled,
    required this.selectedMode,
    required this.profiles,
    required this.guest,
    required this.onModeChanged,
    required this.onSend,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _showEffortPopup = false;

  Map<String, dynamic> _currentProfile() {
    for (final item in widget.profiles) {
      if (item['key']?.toString() == widget.selectedMode) return item;
    }
    return widget.profiles.isNotEmpty ? widget.profiles.first : {'key':'fast','label':'إجابة سريعة'.tr(),'credits':1};
  }

  void _toggleEffortPopup() {
    if (!widget.enabled || widget.sending) return;
    setState(() => _showEffortPopup = !_showEffortPopup);
  }

  Widget _buildEffortPopup(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: 320,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF151B24) : Theme.of(context).colorScheme.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Theme.of(context).colorScheme.surface)),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.profiles.map((profile) {
            final key = profile['key']?.toString() ?? 'fast';
            final enabled = widget.guest ? key == 'fast' : profile['enabled'] != false;
            final selected = key == widget.selectedMode;
            final cost = int.tryParse('${profile['credits'] ?? 1}') ?? 1;
            return InkWell(
              onTap: enabled ? () { widget.onModeChanged(key); setState(() => _showEffortPopup = false); } : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFE8EFF8)) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(selected ? Icons.check_circle_rounded : (enabled ? Icons.auto_awesome_outlined : Icons.lock_outline_rounded), size: 18, color: selected ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trUi(profile['label']?.toString() ?? key), style: TextStyle(color: enabled ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface) : const Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 12)),
                          if ((profile['description']?.toString() ?? '').isNotEmpty) Text(trUi(profile['description'].toString()), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9.5)),
                        ],
                      ),
                    ),
                    Text(trUi(enabled ? 'حسب الاستهلاك' : (profile['requires_plan']?.toString() ?? 'ترقية')), style: TextStyle(color: enabled ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)) : const Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_showEffortPopup) {
          setState(() => _showEffortPopup = false);
        }
      },
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF020814) : Theme.of(context).colorScheme.surface),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.selectedFile != null)
                _SelectedAttachmentCard(
                  file: widget.selectedFile!,
                  progress: widget.uploadProgress,
                  sending: widget.sending,
                  onRemove: widget.onClearAttachment,
                ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: _showEffortPopup
                    ? Padding(
                        key: const ValueKey('effort-popup'),
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _buildEffortPopup(context),
                      )
                    : const SizedBox.shrink(key: ValueKey('effort-empty')),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xF20B1E38) : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x663B82F6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x42000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    if (widget.canAttach)
                      _ChatComposerCircleButton(
                        icon: Icons.add_rounded,
                        onPressed: widget.sending ? null : widget.onAttach,
                        tooltip: 'إرفاق ملف أو صورة'.tr(),
                      ),
                    if (widget.canAttach) const SizedBox(width: 8),
                    Expanded(
                      child: Directionality(
                        textDirection: AppLanguage.instance.textDirection,
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          enabled: true,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(
                            fontSize: 14,
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
                            height: 1.45,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 9,
                            ),
                            hintText: trUiN(widget.selectedFile != null
                                ? 'اكتب ماذا تريد من المساعد أن يحلل في الملف…'
                                : widget.enabled
                                    ? 'اكتب سؤالك هنا...'
                                    : (widget.disabledHint ?? 'المحادثة مغلقة')),
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                            ),
                          ),
                          onTap: () {
                            if (_showEffortPopup) {
                              setState(() => _showEffortPopup = false);
                            }
                            widget.onFocusRequested();
                          },
                          onSubmitted: (_) {
                            if (widget.enabled && !widget.sending) widget.onSend();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _toggleEffortPopup,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF30343C) : Theme.of(context).colorScheme.surface),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              trUi(_currentProfile()['label']?.toString() ?? 'إجابة سريعة'),
                              style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5E7EB) : Theme.of(context).colorScheme.onSurface),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFFB8C0CC),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ChatComposerCircleButton(
                      icon: widget.listening
                          ? Icons.stop_rounded
                          : Icons.mic_none_rounded,
                      onPressed: widget.voiceEnabled && !widget.sending
                          ? widget.onVoice
                          : null,
                      tooltip: 'الصوت'.tr(),
                      active: widget.listening,
                    ),
                    const SizedBox(width: 6),
                    _ChatSendButton(
                      sending: widget.sending,
                      enabled: widget.enabled && !widget.sending,
                      onPressed: () {
                        if (_showEffortPopup) {
                          setState(() => _showEffortPopup = false);
                        }
                        widget.onSend();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantUsageLimitsStrip extends StatelessWidget {
  final Map<String, dynamic> entitlement;

  const _AssistantUsageLimitsStrip({required this.entitlement});

  @override
  Widget build(BuildContext context) {
    if (entitlement['unlimited'] == true) return const SizedBox.shrink();
    final limits = Map<String, dynamic>.from(entitlement['usage_limits'] as Map? ?? const {});
    if (limits.isEmpty) return const SizedBox.shrink();

    Widget item(String key, String label) {
      final data = Map<String, dynamic>.from(limits[key] as Map? ?? const {});
      final remaining = int.tryParse('${data['remaining'] ?? 0}') ?? 0;
      final limit = int.tryParse('${data['limit'] ?? 0}') ?? 0;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1729) : const Color(0xFFFFFFFF)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(trUi(label), style: TextStyle(fontSize: 9.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Color(0xFF475569)))),
              const SizedBox(width: 5),
              Flexible(child: Text('$remaining/$limit', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490))))),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          item('five_hours', '5س'),
          const SizedBox(width: 6),
          item('seven_days', '7أ'),
          const SizedBox(width: 6),
          item('month', 'شهر'),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Color(0xFF3B82F6),
            ),
          ),
          SizedBox(height: 14),
          TrText('جاري تجهيز المحادثة…',
            style: TextStyle(
              color: Color(0xFFB7B7B7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B1B1B) : Theme.of(context).colorScheme.surface),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFFF8A8A),
                  size: 34,
                ),
                const SizedBox(height: 12),
                TrText('تعذر فتح المساعد',
                  style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  trUi(message),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 12.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const TrText('إعادة المحاولة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatComposerCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool active;

  const _ChatComposerCircleButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: trUiN(tooltip),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF4A2222) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 21,
            color: onPressed == null
                ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF676767) : const Color(0xFFE9F0FA))
                : active
                    ? const Color(0xFFFFA5A5)
                    : const Color(0xFFE8E8E8),
          ),
        ),
      ),
    );
  }
}

class _ChatSendButton extends StatelessWidget {
  final bool sending;
  final bool enabled;
  final VoidCallback onPressed;

  const _ChatSendButton({
    required this.sending,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF3B82F6) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF444444) : const Color(0xFFE9F0FA)),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: sending
            ? SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A)),
                ),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                size: 21,
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
              ),
      ),
    );
  }
}
