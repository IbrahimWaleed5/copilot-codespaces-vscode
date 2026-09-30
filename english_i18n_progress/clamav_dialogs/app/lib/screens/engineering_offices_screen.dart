import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../widgets/verified_name.dart';
import 'conversation_detail_screen.dart';
import 'create_consultation_screen.dart';
import 'marketplace_projects_screen.dart';
import 'register_screen.dart';

class EngineeringOfficesScreen extends StatefulWidget {
  const EngineeringOfficesScreen({super.key});

  @override
  State<EngineeringOfficesScreen> createState() => _EngineeringOfficesScreenState();
}

class _EngineeringOfficesScreenState extends State<EngineeringOfficesScreen> {
  final _search = TextEditingController();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int? _specialtyId;
  bool _verifiedOnly = false;
  String _sort = 'name';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchOffices(
        query: _search.text,
        specialtyId: _specialtyId,
        verified: _verifiedOnly,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offices = List<dynamic>.from(_data?['data'] as List? ?? const []);
    final stats = Map<String, dynamic>.from(_data?['statistics'] as Map? ?? const {});
    final specialties = List<dynamic>.from(_data?['specialties'] as List? ?? const []);

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: const TrText('المكاتب الهندسية')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المكتب أو المدينة...'.tr(),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _specialtyId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'التخصص'.tr(),
                        prefixIcon: Icon(Icons.architecture_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: TrText('كل التخصصات'),
                        ),
                        ...specialties.map((raw) {
                          final item = Map<String, dynamic>.from(raw as Map);
                          return DropdownMenuItem<int?>(
                            value: int.tryParse(item['id'].toString()),
                            child: Text(trUi(item['name']?.toString() ?? 'تخصص')),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _specialtyId = value);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sort,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'الترتيب'.tr(),
                        prefixIcon: Icon(Icons.sort_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'name', child: TrText('الاسم')),
                        DropdownMenuItem(value: 'rating', child: TrText('الأعلى تقييمًا')),
                        DropdownMenuItem(value: 'projects', child: TrText('الأكثر مشاريع')),
                        DropdownMenuItem(value: 'newest', child: TrText('الأحدث')),
                      ],
                      onChanged: (value) {
                        setState(() => _sort = value ?? 'name');
                        _load();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _verifiedOnly,
                onChanged: (value) {
                  setState(() => _verifiedOnly = value);
                  _load();
                },
                title: const TrText('المكاتب الموثقة فقط',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                secondary: Icon(Icons.verified_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(label: 'الكل', value: stats['all']),
                  _StatChip(label: 'فعال', value: stats['active'], color: AppColors.success),
                  _StatChip(label: 'موثق', value: stats['verified'], color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300)),
                  _StatChip(label: 'موقوف', value: stats['suspended'], color: const Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _MessageCard(text: _error!, icon: Icons.cloud_off_outlined)
              else if (offices.isEmpty)
                _MessageCard(text: 'لا توجد مكاتب مطابقة حاليًا.'.tr(), icon: Icons.domain_disabled_outlined)
              else
                ...offices.map((raw) {
                  final office = Map<String, dynamic>.from(raw as Map);
                  return _OfficeCard(
                    office: office,
                    onTap: () async {
                      final slug = office['slug']?.toString();
                      if (slug == null || slug.isEmpty) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => OfficeDetailScreen(slug: slug)),
                      );
                      if (mounted) _load();
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class OfficeDetailScreen extends StatefulWidget {
  final String slug;

  const OfficeDetailScreen({super.key, required this.slug});

  @override
  State<OfficeDetailScreen> createState() => _OfficeDetailScreenState();
}

class _OfficeDetailScreenState extends State<OfficeDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchOffice(widget.slug);
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final specialties = List<dynamic>.from(_data?['specialties'] as List? ?? const []);
    if (specialties.isEmpty) {
      _toast('لا توجد تخصصات متاحة.');
      return;
    }

    int specialtyId = int.parse((specialties.first as Map)['id'].toString());
    final position = TextEditingController();
    final years = TextEditingController();
    final message = TextEditingController();
    File? cv;
    File? certificate;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pick(bool isCv) async {
              final picked = await FilePicker.pickFile(
                type: FileType.custom,
                allowedExtensions: isCv
                    ? ['pdf', 'doc', 'docx']
                    : ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
              );
              if (picked?.path == null) return;
              setDialogState(() {
                if (isCv) {
                  cv = File(picked!.path!);
                } else {
                  certificate = File(picked!.path!);
                }
              });
            }

            return Directionality(
              textDirection: AppLanguage.instance.textDirection,
              child: AlertDialog(
                title: const TrText('طلب الانضمام إلى المكتب'),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: specialtyId,
                          decoration: InputDecoration(labelText: 'التخصص'.tr()),
                          items: specialties.map((raw) {
                            final item = Map<String, dynamic>.from(raw as Map);
                            return DropdownMenuItem(
                              value: int.parse(item['id'].toString()),
                              child: Text(trUi(item['name']?.toString() ?? '')),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setDialogState(() => specialtyId = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(controller: position, decoration: InputDecoration(labelText: 'المسمى المطلوب'.tr())),
                        const SizedBox(height: 10),
                        TextField(
                          controller: years,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'سنوات الخبرة'.tr()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: message,
                          maxLines: 3,
                          decoration: InputDecoration(labelText: 'رسالة إلى المكتب'.tr()),
                        ),
                        const SizedBox(height: 12),
                        _PickFileButton(
                          label: cv == null ? 'اختيار السيرة الذاتية' : 'تم اختيار السيرة الذاتية',
                          icon: Icons.description_outlined,
                          onTap: () => pick(true),
                        ),
                        const SizedBox(height: 8),
                        _PickFileButton(
                          label: certificate == null ? 'اختيار الشهادة' : 'تم اختيار الشهادة',
                          icon: Icons.workspace_premium_outlined,
                          onTap: () => pick(false),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (cv == null || certificate == null) {
                              _toast('اختر السيرة الذاتية والشهادة.');
                              return;
                            }
                            setDialogState(() => saving = true);
                            try {
                              final text = await ApiService.submitOfficeMembershipApplication(
                                officeSlug: widget.slug,
                                specialtyId: specialtyId,
                                requestedPosition: position.text.trim().isEmpty ? null : position.text.trim(),
                                yearsOfExperience: int.tryParse(years.text.trim()),
                                message: message.text.trim().isEmpty ? null : message.text.trim(),
                                cv: cv!,
                                certificate: certificate!,
                              );
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              _toast(text);
                              await _load();
                            } on ApiException catch (e) {
                              _toast(e.message);
                            } finally {
                              if (dialogContext.mounted) setDialogState(() => saving = false);
                            }
                          },
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const TrText('إرسال الطلب'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reviewOffice(List<dynamic> projects) async {
    int projectId = int.parse((projects.first as Map)['id'].toString());
    int rating = 5;
    final comment = TextEditingController();
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('تقييم المكتب'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: projectId,
                    decoration: InputDecoration(labelText: 'المشروع المكتمل'.tr()),
                    items: projects.map((raw) {
                      final project = Map<String, dynamic>.from(raw as Map);
                      return DropdownMenuItem<int>(
                        value: int.parse(project['id'].toString()),
                        child: Text(
                          '${project['project_number'] ?? ''} — ${project['title'] ?? 'مشروع'}'.tr(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => projectId = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: rating,
                    decoration: InputDecoration(labelText: 'التقييم'.tr()),
                    items: List.generate(
                      5,
                      (index) {
                        final value = 5 - index;
                        return DropdownMenuItem(
                          value: value,
                          child: TrText('$value نجوم'),
                        );
                      },
                    ),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => rating = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: comment,
                    maxLines: 4,
                    maxLength: 3000,
                    decoration: InputDecoration(
                      labelText: 'تعليقك'.tr(),
                      hintText: 'اكتب تجربتك مع المكتب...'.tr(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const TrText('إلغاء'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final message = await ApiService.submitOfficeReview(
                            officeSlug: widget.slug,
                            projectId: projectId,
                            rating: rating,
                            comment: comment.text,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          _toast(message);
                          await _load();
                        } on ApiException catch (e) {
                          _toast(e.message);
                          if (dialogContext.mounted) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const TrText('نشر التقييم'),
              ),
            ],
          ),
        ),
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 600), comment.dispose);
  }

  Future<void> _messageUser(int userId) async {
    try {
      final conversationId = await ApiService.startDirectConversation(userId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationDetailScreen(conversationId: conversationId),
        ),
      );
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    AppFeedback.auto(message);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(trUi(_error!))));
    }

    final office = Map<String, dynamic>.from(_data?['office'] as Map? ?? const {});
    final members = List<dynamic>.from(office['active_members'] as List? ?? const []);
    final works = List<dynamic>.from(office['portfolio_works'] as List? ?? const []);
    final reviews = List<dynamic>.from(office['reviews'] as List? ?? const []);
    final reviewableProjects = List<dynamic>.from(_data?['reviewable_projects'] as List? ?? const []);
    final reviewerNames = List<dynamic>.from(office['reviewer_names'] as List? ?? const []);
    final ratingDistribution = Map<String, dynamic>.from(
      office['rating_distribution'] as Map? ?? const {},
    );
    final ratingAverage = (office['rating_average'] as num?)?.toDouble() ?? 0;
    final reviewsCount = (office['reviews_count'] as num?)?.toInt() ?? reviews.length;
    final canApply = _data?['can_apply'] == true;
    final latest = _data?['latest_application'] as Map?;
    final userRole = context.watch<AuthProvider>().user?.role ?? '';
    final officeId = int.tryParse(office['id']?.toString() ?? '');
    final owner = office['owner'] is Map
        ? Map<String, dynamic>.from(office['owner'] as Map)
        : const <String, dynamic>{};
    final ownerId = int.tryParse(owner['id']?.toString() ?? '');
    final isOperational = office['is_operational'] == true;
    final verified = office['verified'] == true;
    final officeSpecialties = List<dynamic>.from(office['specialties'] as List? ?? const []);

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: Text(trUi(office['name']?.toString() ?? 'المكتب الهندسي'))),
        floatingActionButton: canApply
            ? FloatingActionButton.extended(
                onPressed: _join,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const TrText('طلب انضمام'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OfficePublicHero(
                office: office,
                verified: verified,
                ratingAverage: ratingAverage,
                reviewsCount: reviewsCount,
              ),
              if (userRole.isEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const TrText('سجل لطلب استشارة'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
                        icon: const Icon(Icons.add_business_outlined),
                        label: const TrText('سجل لطلب مشروع'),
                      ),
                    ),
                  ],
                ),
              ],
              if (userRole == 'admin' && ownerId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _messageUser(ownerId),
                    icon: const Icon(Icons.forum_outlined),
                    label: const TrText('مراسلة مالك المكتب'),
                  ),
                ),
              ],
              if (userRole == 'customer' && isOperational && officeId != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreateConsultationScreen(
                              officeId: officeId,
                              officeName: office['name']?.toString(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const TrText('طلب استشارة'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MarketplaceProjectsScreen(
                              preferredOfficeId: officeId,
                              preferredOfficeName: office['name']?.toString(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add_business_outlined),
                        label: const TrText('طلب مشروع'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              if ((office['description']?.toString() ?? '').isNotEmpty)
                _SectionCard(title: 'نبذة عن المكتب', child: Text(trUi(office['description'].toString()), style: const TextStyle(height: 1.7))),
              if (officeSpecialties.isNotEmpty)
                _SectionCard(
                  title: 'تخصصات المكتب',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: officeSpecialties.map((raw) {
                      final specialty = Map<String, dynamic>.from(raw as Map);
                      return Chip(
                        avatar: const Icon(Icons.engineering_outlined, size: 16),
                        label: Text(trUi(specialty['name']?.toString() ?? 'تخصص')),
                      );
                    }).toList(),
                  ),
                ),
              _SectionCard(
                title: 'بيانات المكتب',
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.email_outlined, text: office['email']?.toString() ?? '—'),
                    _InfoRow(icon: Icons.phone_outlined, text: office['phone']?.toString() ?? '—'),
                    _InfoRow(icon: Icons.location_on_outlined, text: office['address']?.toString() ?? '—'),
                    _InfoRow(icon: Icons.groups_outlined, text: '${office['active_members_count'] ?? 0} عضو فعال'),
                    _InfoRow(icon: Icons.description_outlined, text: '${office['consultations_count'] ?? 0} استشارة'),
                    _InfoRow(icon: Icons.task_alt_outlined, text: '${office['completed_projects_count'] ?? 0} مشروع مكتمل'),
                  ],
                ),
              ),
              _OfficeRatingCard(
                average: ratingAverage,
                count: reviewsCount,
                reviewerNames: reviewerNames,
                distribution: ratingDistribution,
                onReview: reviewableProjects.isEmpty
                    ? null
                    : () => _reviewOffice(reviewableProjects),
              ),
              _SectionCard(
                title: 'مكتبة أعمال المكتب',
                child: works.isEmpty
                    ? TrText('لا توجد أعمال منشورة للمكتب حتى الآن.',
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                      )
                    : SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: works.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final work = Map<String, dynamic>.from(works[index] as Map);
                            return _OfficeWorkCard(
                              work: work,
                              officeAverage: ratingAverage,
                              officeReviewsCount: reviewsCount,
                            );
                          },
                        ),
                      ),
              ),
              _SectionCard(
                title: 'آراء العملاء الموثقة',
                child: reviews.isEmpty
                    ? TrText('لا توجد تقييمات منشورة حتى الآن.',
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                      )
                    : Column(
                        children: reviews.take(10).map((raw) {
                          return _OfficeReviewTile(
                            review: Map<String, dynamic>.from(raw as Map),
                          );
                        }).toList(),
                      ),
              ),
              if (latest != null)
                _SectionCard(
                  title: 'آخر طلب انضمام',
                  child: _InfoRow(
                    icon: Icons.assignment_outlined,
                    text: 'الحالة: ${_applicationStatus(latest['status']?.toString())}',
                  ),
                ),
              _SectionCard(
                title: 'فريق المكتب',
                child: members.isEmpty
                    ? TrText('لا يوجد أعضاء ظاهرون حاليًا.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))
                    : Column(
                        children: members.map((raw) {
                          final member = Map<String, dynamic>.from(raw as Map);
                          final user = member['user'] as Map?;
                          final specialty = member['specialty'] as Map?;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.engineering_outlined)),
                            title: Text(trUi(user?['name']?.toString() ?? 'عضو')),
                            subtitle: Text(
                              trUi([member['position'], specialty?['name']]
                                  .where((e) => e != null && e.toString().isNotEmpty)
                                  .join(' • ')),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficePublicHero extends StatelessWidget {
  final Map<String, dynamic> office;
  final bool verified;
  final double ratingAverage;
  final int reviewsCount;

  const _OfficePublicHero({
    required this.office,
    required this.verified,
    required this.ratingAverage,
    required this.reviewsCount,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = office['cover_url']?.toString();
    final logoUrl = office['logo_url']?.toString();
    final name = office['name']?.toString() ?? 'مكتب هندسي';
    final location = [office['city'], office['country']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(' • ');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x2238BDF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl != null && coverUrl.isNotEmpty)
                  Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _OfficeCoverFallback(),
                  )
                else
                  const _OfficeCoverFallback(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xDD071023)],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  left: 16,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFF10213E),
                        backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                            ? NetworkImage(logoUrl)
                            : null,
                        child: logoUrl == null || logoUrl.isEmpty
                            ? const Icon(Icons.apartment_rounded, size: 30, color: Color(0xFF67E8F9))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VerifiedName(
                              name: name,
                              verified: verified,
                              iconSize: 21,
                              tooltip: 'مكتب موثق احترافيًا على منصة الوليد الهندسية'.tr(),
                              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            if (location.isNotEmpty)
                              Text(
                                trUi(location),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFFD7E4FF), fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(
                      label: _officeStatus(office['status']?.toString()),
                      color: _officeStatusColor(context, office['status']?.toString()),
                    ),
                    _StatusPill(
                      label: office['is_operational'] == true ? 'تشغيلي' : 'غير تشغيلي',
                      color: office['is_operational'] == true
                          ? AppColors.success
                          : const Color(0xFFF59E0B),
                    ),
                    _StatusPill(
                      label: office['subscription_status']?.toString() == 'active'
                          ? 'اشتراك المنصة فعال'
                          : 'الاشتراك: ${_subscriptionLabel(office['subscription_status']?.toString())}',
                      color: office['subscription_status']?.toString() == 'active'
                          ? AppColors.success
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _OfficeHeroMetric(
                        icon: Icons.star_rounded,
                        value: ratingAverage.toStringAsFixed(1),
                        label: '$reviewsCount تقييم موثق',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OfficeHeroMetric(
                        icon: Icons.photo_library_outlined,
                        value: '${office['portfolio_works_count'] ?? 0}',
                        label: 'أعمال منشورة',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OfficeHeroMetric(
                        icon: Icons.task_alt_rounded,
                        value: '${office['completed_projects_count'] ?? 0}',
                        label: 'مشاريع مكتملة',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficeCoverFallback extends StatelessWidget {
  const _OfficeCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1D4ED8), Color(0xFF0891B2), Color(0xFF071023)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.domain_rounded, size: 72, color: Color(0x5567E8F9)),
      ),
    );
  }
}

class _OfficeHeroMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _OfficeHeroMetric({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF10182B) : const Color(0xFFF1F5FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF67E8F9)),
          const SizedBox(height: 4),
          Text(trUi(value), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF10213E))),
          const SizedBox(height: 2),
          Text(
            trUi(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

class _OfficeCard extends StatelessWidget {
  final Map<String, dynamic> office;
  final VoidCallback onTap;

  const _OfficeCard({required this.office, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final verified = office['verified'] == true;
    final specialties = List<dynamic>.from(office['specialties'] as List? ?? const []);
    final logoUrl = office['logo_url']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 52,
                  height: 52,
                  color: AppColors.blue500_10,
                  child: logoUrl != null && logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.apartment_rounded,
                            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan),
                          ),
                        )
                      : Icon(Icons.apartment_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VerifiedName(
                      name: office['name']?.toString() ?? 'مكتب هندسي',
                      verified: verified,
                      iconSize: 18,
                      tooltip: 'مكتب موثق احترافيًا على منصة الوليد الهندسية'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trUi([office['city'], office['country']].where((e) => e != null && e.toString().isNotEmpty).join(' • ')),
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11),
                    ),
                    const SizedBox(height: 7),
                    if (specialties.isNotEmpty) ...[
                      Text(
                        trUi(specialties
                            .take(3)
                            .map((e) => e is Map ? e['name']?.toString() ?? '' : '')
                            .where((e) => e.isNotEmpty)
                            .join(' • ')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300), fontSize: 10),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      '${office['active_members_count'] ?? 0} عضو • ${office['consultations_count'] ?? 0} استشارة'.tr(),
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          trUi((office['reviews_count'] as num?)?.toInt() == 0
                              ? 'لا تقييمات'
                              : '${((office['rating_average'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} • ${office['reviews_count'] ?? 0} مقيم'),
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}


class _OfficeRatingCard extends StatelessWidget {
  final double average;
  final int count;
  final List<dynamic> reviewerNames;
  final Map<String, dynamic> distribution;
  final VoidCallback? onReview;

  const _OfficeRatingCard({
    required this.average,
    required this.count,
    required this.reviewerNames,
    required this.distribution,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'تقييم المكتب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
              const SizedBox(width: 8),
              Text(
                trUi(count == 0 ? '—' : average.toStringAsFixed(1)),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              TrText('$count تقييم موثق',
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
          if (reviewerNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            TrText('المقيمون',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: reviewerNames.map((name) {
                return Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.verified_rounded, size: 15, color: AppColors.success),
                  label: Text(trUi(name.toString())),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          ...List.generate(5, (index) {
            final star = 5 - index;
            final starCount = (distribution['$star'] as num?)?.toInt() ?? 0;
            final fraction = count == 0 ? 0.0 : starCount / count;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text('$star ★', style: const TextStyle(fontSize: 11, color: Colors.amber)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0).toDouble(),
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$starCount',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 10, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (onReview != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: const TrText('قيّم المكتب من مشروع مكتمل'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfficeWorkCard extends StatelessWidget {
  final Map<String, dynamic> work;
  final double officeAverage;
  final int officeReviewsCount;

  const _OfficeWorkCard({
    required this.work,
    required this.officeAverage,
    required this.officeReviewsCount,
  });

  @override
  Widget build(BuildContext context) {
    final cover = work['cover_url']?.toString();
    final media = List<dynamic>.from(work['media'] as List? ?? const []);
    final location = work['location']?.toString() ?? '';
    final completedAt = work['completed_at']?.toString() ?? '';

    return SizedBox(
      width: 245,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xE6242A37),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2200F2FE),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover?.isNotEmpty == true)
                    Image.network(
                      cover!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF080E1A) : Theme.of(context).scaffoldBackgroundColor),
                        child: Center(
                          child: Icon(
                            Icons.architecture_rounded,
                            size: 42,
                            color: Color(0xFF3A494B),
                          ),
                        ),
                      ),
                    )
                  else
                    ColoredBox(
                      color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF080E1A) : Theme.of(context).scaffoldBackgroundColor),
                      child: Center(
                        child: Icon(
                          Icons.architecture_rounded,
                          size: 42,
                          color: Color(0xFF3A494B),
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xE6080E1A)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: _PortfolioBadge(
                      icon: Icons.circle,
                      label: 'عمل منشور',
                      color: const Color(0xFF00F2FE),
                    ),
                  ),
                  Positioned(
                    top: 9,
                    left: 9,
                    child: _PortfolioBadge(
                      icon: Icons.star_rounded,
                      label: officeReviewsCount == 0
                          ? 'جديد'
                          : officeAverage.toStringAsFixed(1),
                      color: const Color(0xFFFFB95F),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 9,
                    child: _PortfolioBadge(
                      icon: Icons.folder_zip_outlined,
                      label: '${media.length} مرفق',
                      color: const Color(0xFFBFFBFF),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trUi(work['title']?.toString() ?? 'عمل'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  if (location.isNotEmpty || completedAt.isNotEmpty)
                    Text(
                      trUi([
                        if (location.isNotEmpty) location,
                        if (completedAt.isNotEmpty) 'إنجاز: $completedAt',
                      ].join(' · ')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF67E8F9),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PortfolioBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6080E1A),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            trUi(label),
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficeReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;

  const _OfficeReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final customer = review['customer'] as Map?;
    final project = review['project'] as Map?;
    final rating = (review['rating'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person_outline_rounded, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trUi(customer?['name']?.toString() ?? 'عميل'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TrText('✓ تقييم موثق${project?['project_number'] != null ? ' • ${project!['project_number']}' : ''}',
                        style: const TextStyle(fontSize: 9, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$rating/5 ★',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.amber),
                ),
              ],
            ),
            if (review['comment']?.toString().trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(trUi(review['comment'].toString())),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color? color;

  const _StatChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF38BDF8)
            : AppColors.accentCyan);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: effectiveColor.withValues(alpha: .20)),
      ),
      child: Text('$label: ${value ?? 0}', style: TextStyle(color: effectiveColor, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trUi(title), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
          const SizedBox(width: 9),
          Expanded(child: Text(trUi(text))),
        ],
      ),
    );
  }
}

class _PickFileButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PickFileButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(trUi(label))),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String text;
  final IconData icon;

  const _MessageCard({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 42, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text(trUi(text), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(trUi(label), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

String _officeStatus(String? status) => switch (status) {
      'active' => 'فعال',
      'suspended' => 'موقوف',
      'closed' => 'مغلق',
      _ => status ?? '—',
    };

Color _officeStatusColor(BuildContext context, String? status) => switch (status) {
      'active' => AppColors.success,
      'suspended' => const Color(0xFFF59E0B),
      'closed' => AppColors.danger,
      _ => (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary),
    };

String _applicationStatus(String? status) => switch (status) {
      'pending' => 'قيد المراجعة',
      'approved' => 'مقبول',
      'rejected' => 'مرفوض',
      _ => status ?? '—',
    };

String _subscriptionLabel(String? status) => switch (status) {
      'active' => 'فعال',
      'pending' => 'قيد المراجعة',
      'expired' => 'منتهي',
      'rejected' => 'مرفوض',
      _ => status ?? 'غير فعال',
    };
