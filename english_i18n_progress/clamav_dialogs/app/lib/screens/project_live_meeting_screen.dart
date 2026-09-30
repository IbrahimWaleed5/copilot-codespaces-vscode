import 'dart:io';

import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../services/realtime_service.dart';

class ProjectLiveMeetingScreen extends StatefulWidget {
  final int projectId;
  final int meetingId;
  final String meetingTitle;
  final bool canModerate;

  const ProjectLiveMeetingScreen({
    super.key,
    required this.projectId,
    required this.meetingId,
    required this.meetingTitle,
    this.canModerate = false,
  });

  @override
  State<ProjectLiveMeetingScreen> createState() => _ProjectLiveMeetingScreenState();
}

class _ProjectLiveMeetingScreenState extends State<ProjectLiveMeetingScreen> {
  Room? _room;
  ProjectMeetingRealtimeSession? _realtime;
  final ValueNotifier<List<Map<String, dynamic>>> _messages =
      ValueNotifier<List<Map<String, dynamic>>>(const []);
  bool _connecting = true;
  bool _leaving = false;
  bool _micEnabled = true;
  bool _cameraEnabled = false;
  bool _speakerEnabled = true;
  bool _frontCamera = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      if (Platform.isAndroid) {
        final mic = await Permission.microphone.request();
        if (!mic.isGranted) {
          throw ApiException('يلزم السماح باستخدام الميكروفون للانضمام إلى الاجتماع.'.tr());
        }
        try {
          await Permission.bluetoothConnect.request();
        } catch (_) {}
      }

      final credentials = await ApiService.fetchProjectMeetingLiveToken(
        widget.projectId,
        widget.meetingId,
      );
      final url = credentials['server_url']?.toString() ?? '';
      final token = credentials['participant_token']?.toString() ?? '';
      if (url.isEmpty || token.isEmpty) {
        throw ApiException('بيانات الاتصال بالاجتماع غير مكتملة.'.tr());
      }

      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      room.addListener(_onRoomChanged);
      await room.connect(url, token);

      await AudioManager.instance.setSpeakerOutputPreferred(true);
      await room.localParticipant?.setMicrophoneEnabled(true);
      await ApiService.joinProjectMeetingLive(
        widget.projectId,
        widget.meetingId,
        participantSid: room.localParticipant?.sid,
      );

      final initialMessages = await ApiService.fetchProjectMeetingLiveMessages(
        widget.projectId,
        widget.meetingId,
      );
      _replaceMessages(initialMessages);

      ProjectMeetingRealtimeSession? realtime;
      try {
        realtime = await ProjectMeetingRealtimeSession.connect(
          meetingId: widget.meetingId,
          onMessage: _appendMessage,
          onState: _handleLiveState,
        );
      } catch (_) {
        // الاجتماع يبقى شغال عبر LiveKit حتى لو Reverb غير متاح مؤقتًا.
      }

      if (!mounted) {
        await realtime?.close();
        await room.disconnect();
        await room.dispose();
        return;
      }
      setState(() {
        _room = room;
        _realtime = realtime;
        _connecting = false;
      });
      AppFeedback.success('تم الانضمام إلى الاجتماع المباشر بنجاح.'.tr());
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() { _error = e.message; _connecting = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'تعذر الاتصال بالاجتماع المباشر: $e'.tr(); _connecting = false; });
    }
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  void _replaceMessages(List<dynamic> raw) {
    final parsed = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) => (a['id'] as num? ?? 0).compareTo(b['id'] as num? ?? 0));
    _messages.value = parsed;
  }

  void _appendMessage(Map<String, dynamic> message) {
    final id = message['id']?.toString();
    final next = List<Map<String, dynamic>>.from(_messages.value);
    if (id != null && next.any((m) => m['id']?.toString() == id)) return;
    next.add(message);
    next.sort((a, b) => (a['id'] as num? ?? 0).compareTo(b['id'] as num? ?? 0));
    _messages.value = next;
  }

  void _handleLiveState(Map<String, dynamic> event) {
    final action = event['action']?.toString() ?? '';
    final participant = Map<String, dynamic>.from(event['participant'] as Map? ?? const {});
    final localId = _participantUserId(_room?.localParticipant);

    if (action == 'participant_removed' &&
        localId != null &&
        participant['id']?.toString() == localId.toString()) {
      if (mounted && !_leaving) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('تمت إزالتك من الاجتماع بواسطة مدير الاجتماع.')),
        );
        _leave(notifyBackend: false);
      }
      return;
    }

    if (action == 'ended' || event['live_status']?.toString() == 'ended') {
      if (mounted && !_leaving) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('تم إنهاء الاجتماع المباشر.')),
        );
        _leave(notifyBackend: false);
      }
      return;
    }

    if (mounted) setState(() {});
  }

  int? _participantUserId(Participant? participant) {
    if (participant == null) return null;
    final identity = participant.identity.trim();
    final match = RegExp(r'^user-(\d+)$').firstMatch(identity);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Future<void> _toggleMic() async {
    final next = !_micEnabled;
    await _room?.localParticipant?.setMicrophoneEnabled(next);
    if (mounted) setState(() => _micEnabled = next);
  }

  Future<void> _toggleCamera() async {
    final next = !_cameraEnabled;
    if (next && Platform.isAndroid) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TrText('لم يتم منح صلاحية الكاميرا. يمكنك متابعة الاجتماع بالصوت فقط.')),
          );
        }
        return;
      }
    }
    await _room?.localParticipant?.setCameraEnabled(next);
    if (mounted) setState(() => _cameraEnabled = next);
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerEnabled;
    await AudioManager.instance.setSpeakerOutputPreferred(next);
    if (mounted) setState(() => _speakerEnabled = next);
  }

  Future<void> _switchCamera() async {
    final local = _room?.localParticipant;
    if (local == null || !_cameraEnabled) return;
    for (final publication in local.videoTrackPublications) {
      final track = publication.track;
      if (track is LocalVideoTrack) {
        final next = _frontCamera ? CameraPosition.back : CameraPosition.front;
        await track.setCameraPosition(next);
        if (mounted) setState(() => _frontCamera = !_frontCamera);
        return;
      }
    }
  }

  Future<void> _leave({bool endMeeting = false, bool notifyBackend = true}) async {
    if (_leaving) return;
    if (mounted) setState(() => _leaving = true);
    if (notifyBackend) {
      try {
        if (endMeeting) {
          final result = await ApiService.endProjectMeetingLive(
            widget.projectId,
            widget.meetingId,
          );
          AppFeedback.success(
            result['message']?.toString() ?? 'تم إنهاء الاجتماع المباشر بنجاح.'.tr(),
          );
        } else {
          final result = await ApiService.leaveProjectMeetingLive(
            widget.projectId,
            widget.meetingId,
          );
          AppFeedback.success(
            result['message']?.toString() ?? 'تم مغادرة الاجتماع بنجاح.'.tr(),
          );
        }
      } on ApiException catch (e) {
        AppFeedback.error(e.message);
      } catch (_) {
        AppFeedback.warning('تم إغلاق الاجتماع على جهازك، لكن تعذر تحديث حالته على الخادم.');
      }
    }
    await _realtime?.close();
    final room = _room;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      await room.disconnect();
      await room.dispose();
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  VideoTrack? _videoTrack(Participant participant) {
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is VideoTrack && publication.source == TrackSource.camera) return track;
    }
    return null;
  }

  Future<void> _moderateParticipant(RemoteParticipant participant) async {
    if (!widget.canModerate) return;
    final userId = _participantUserId(participant);
    if (userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: TrText('تعذر تحديد حساب هذا المشارك.')));
      return;
    }
    final micPublication = participant.getTrackPublicationBySource(TrackSource.microphone);
    final isMuted = micPublication?.muted == true;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: Icon(isMuted ? Icons.mic_rounded : Icons.mic_off_rounded),
              title: Text(trUi(isMuted ? 'إلغاء كتم الميكروفون' : 'كتم ميكروفون المشارك')),
              enabled: micPublication != null,
              onTap: micPublication == null ? null : () => Navigator.pop(context, 'mute'),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.red),
              title: const TrText('إزالة المشارك من الاجتماع', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'kick'),
            ),
          ]),
        ),
      ),
    );
    if (action == null) return;

    try {
      if (action == 'mute' && micPublication != null) {
        await ApiService.muteProjectMeetingLiveParticipant(
          projectId: widget.projectId,
          meetingId: widget.meetingId,
          userId: userId,
          trackSid: micPublication.sid,
          muted: !isMuted,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trUi(isMuted ? 'تم إلغاء كتم المشارك.' : 'تم كتم المشارك.'))),
          );
        }
      } else if (action == 'kick') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const TrText('إزالة المشارك'),
            content: TrText('هل تريد إزالة ${participant.name.isNotEmpty ? participant.name : participant.identity} من الاجتماع؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const TrText('إزالة')),
            ],
          ),
        );
        if (confirmed == true) {
          await ApiService.kickProjectMeetingLiveParticipant(
            projectId: widget.projectId,
            meetingId: widget.meetingId,
            userId: userId,
          );
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: TrText('تمت إزالة المشارك.')));
        }
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _openChat() async {
    final controller = TextEditingController();
    final scrollController = ScrollController();
    bool sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF151515) : Theme.of(context).scaffoldBackgroundColor),
      builder: (sheetContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .72,
                child: Column(children: [
                  ListTile(
                    leading: Icon(Icons.forum_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                    title: TrText('محادثة الاجتماع المباشر', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontWeight: FontWeight.w900)),
                    subtitle: TrText('الرسائل محفوظة ضمن سجل الاجتماع.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                  Expanded(
                    child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: _messages,
                      builder: (context, items, _) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (scrollController.hasClients) {
                            scrollController.jumpTo(scrollController.position.maxScrollExtent);
                          }
                        });
                        if (items.isEmpty) {
                          return Center(child: TrText('لا توجد رسائل بعد.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
                        }
                        final localId = _participantUserId(_room?.localParticipant);
                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          itemBuilder: (_, index) {
                            final message = items[index];
                            final mine = localId != null && message['user_id']?.toString() == localId.toString();
                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 310),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: mine ? const Color(0xFF0E7490) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF)),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (!mine)
                                    Text(message['user_name']?.toString() ?? 'مشارك'.tr(), style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text(trUi(message['body']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface))),
                                ]),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالة...'.tr(),
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            filled: true,
                            fillColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF242424) : Theme.of(context).colorScheme.surface),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: sending
                            ? null
                            : () async {
                                final text = controller.text.trim();
                                if (text.isEmpty) return;
                                setSheetState(() => sending = true);
                                try {
                                  final message = await ApiService.sendProjectMeetingLiveMessage(
                                    projectId: widget.projectId,
                                    meetingId: widget.meetingId,
                                    body: text,
                                  );
                                  controller.clear();
                                  _appendMessage(message);
                                } on ApiException catch (e) {
                                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
                                } finally {
                                  if (context.mounted) setSheetState(() => sending = false);
                                }
                              },
                        icon: sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    scrollController.dispose();
  }

  @override
  void dispose() {
    final room = _room;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      room.disconnect();
      room.dispose();
    }
    _realtime?.close();
    _messages.dispose();
    if (!_leaving) {
      ApiService.leaveProjectMeetingLive(widget.projectId, widget.meetingId).catchError((_) => <String, dynamic>{});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(trUi(widget.meetingTitle)),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(onPressed: _connecting ? null : _openChat, icon: const Icon(Icons.forum_outlined), tooltip: 'محادثة الاجتماع'.tr()),
              IconButton(onPressed: _leaving ? null : () => _leave(), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_connecting) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(), SizedBox(height: 12), TrText('جاري الدخول إلى الاجتماع...', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface))),
      ]));
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.videocam_off_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 46),
          const SizedBox(height: 12),
          Text(trUi(_error!), textAlign: TextAlign.center, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface))),
          const SizedBox(height: 16),
          FilledButton(onPressed: () { setState(() { _connecting = true; _error = null; }); _connect(); }, child: const TrText('إعادة المحاولة')),
          TextButton(onPressed: () => Navigator.pop(context), child: const TrText('رجوع')),
        ]),
      ));
    }

    final room = _room!;
    final participants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    return SafeArea(
      child: Column(children: [
        Expanded(
          child: participants.isEmpty
              ? Center(child: TrText('بانتظار المشاركين...', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: participants.length <= 2 ? 1 : 2,
                    childAspectRatio: participants.length <= 2 ? 16 / 10 : 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: participants.length,
                  itemBuilder: (_, index) => _participantTile(participants[index], room.localParticipant == participants[index]),
                ),
        ),
        _controls(),
      ]),
    );
  }

  Widget _participantTile(Participant participant, bool isLocal) {
    final track = _videoTrack(participant);
    final displayName = participant.name.trim().isNotEmpty ? participant.name : participant.identity;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(fit: StackFit.expand, children: [
        Container(
          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF171717) : Theme.of(context).colorScheme.surface),
          child: track != null
              ? VideoTrackRenderer(track)
              : Center(child: CircleAvatar(
                  radius: 34,
                  child: Text(trUi(displayName.isNotEmpty ? displayName.characters.first : '؟'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                )),
        ),
        if (widget.canModerate && !isLocal && participant is RemoteParticipant)
          Positioned(
            left: 6,
            top: 6,
            child: IconButton.filledTonal(
              onPressed: () => _moderateParticipant(participant),
              icon: const Icon(Icons.more_horiz_rounded),
              tooltip: 'إدارة المشارك'.tr(),
            ),
          ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (participant.isSpeaking) ...[const Icon(Icons.graphic_eq_rounded, size: 16, color: Colors.greenAccent), const SizedBox(width: 4)],
              if (participant.isMuted) ...[const Icon(Icons.mic_off_rounded, size: 14, color: Colors.redAccent), const SizedBox(width: 4)],
              Text('${isLocal ? 'أنت • ' : ''}$displayName'.tr(), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _controls() {
    Widget control(IconData icon, String label, VoidCallback? onTap, {bool active = true, bool danger = false}) =>
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                backgroundColor: danger ? Colors.red : (active ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2D2D) : const Color(0xFFE9F0FA)) : Colors.red.shade700),
                foregroundColor: Colors.white,
                child: Icon(icon),
              ),
              const SizedBox(height: 4),
              Text(trUi(label), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 11)),
            ]),
          ),
        );

    return Container(
      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF101010) : Theme.of(context).colorScheme.surface),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
        control(_micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded, 'الميكروفون', _leaving ? null : _toggleMic, active: _micEnabled),
        control(_cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded, 'الكاميرا', _leaving ? null : _toggleCamera, active: _cameraEnabled),
        if (_cameraEnabled) control(Icons.cameraswitch_rounded, 'تبديل', _leaving ? null : _switchCamera),
        control(_speakerEnabled ? Icons.volume_up_rounded : Icons.hearing_rounded, 'السماعة', _leaving ? null : _toggleSpeaker, active: _speakerEnabled),
        control(Icons.forum_outlined, 'المحادثة', _leaving ? null : _openChat),
        control(Icons.call_end_rounded, 'مغادرة', _leaving ? null : () => _leave(), danger: true),
        if (widget.canModerate) control(Icons.stop_circle_outlined, 'إنهاء للجميع', _leaving ? null : () => _leave(endMeeting: true), danger: true),
      ]),
    );
  }
}
