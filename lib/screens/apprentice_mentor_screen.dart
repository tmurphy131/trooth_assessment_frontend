import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agreement_preview_screen.dart';

// Tiny holder for hour/minute used by next-meeting calculation
class _HM {
  final int h;
  final int m;
  const _HM(this.h, this.m);
}

class ApprenticeMentorScreen extends StatefulWidget {
  const ApprenticeMentorScreen({super.key});

  @override
  State<ApprenticeMentorScreen> createState() => _ApprenticeMentorScreenState();
}

class _ApprenticeMentorScreenState extends State<ApprenticeMentorScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _agreements = [];
  Map<String, dynamic>? _primaryAgreement; // most recent, non-revoked if available
  Map<String, dynamic>? _mentorProfile; // loaded from users service
  Map<String, dynamic>? _mentorStatus; // from /apprentice/mentor/status
  List<Map<String, dynamic>> _pendingAgreements = []; // from /apprentice/agreements/pending
  List<Map<String, dynamic>> _sharedResources = []; // from /apprentice/resources

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Agreements
      final res = await _api.listMyAgreements(limit: 100);
      final list = res.cast<Map<String, dynamic>>();
      Map<String, dynamic>? primary = list.firstWhere(
        (a) => a['status'] != 'revoked',
        orElse: () => list.isNotEmpty ? list.first : <String, dynamic>{},
      );
      if (primary.isEmpty) primary = null;

      // Mentor profile (legacy fallback via primary agreement's mentor_id)
      Map<String, dynamic>? mentor;
      if (primary != null && primary['mentor_id'] != null) {
        try { mentor = await _api.getUserProfile(primary['mentor_id']); } catch (_) { mentor = null; }
      }

      // New mentor status + pending agreements
      Map<String, dynamic>? status;
      List<Map<String, dynamic>> pending = [];
      try { status = await _api.getMentorStatus(); } catch (_) { status = null; }
      try { final p = await _api.listPendingAgreements(); pending = p.cast<Map<String, dynamic>>(); } catch (_) {}

      // Shared resources for apprentice
      List<Map<String, dynamic>> resources = [];
      try {
        final r = await _api.listMySharedResources();
        resources = r.cast<Map<String, dynamic>>();
      } catch (_) {}

      setState(() {
        _agreements = list;
        _primaryAgreement = primary;
        _mentorProfile = mentor;
        _mentorStatus = status;
        _pendingAgreements = pending;
  _sharedResources = resources;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load: $e'; _loading = false; });
    }
  }


  void _openAgreement(Map<String, dynamic> ag) {
    final markdown = ag['content_rendered'] as String?;
    if (markdown == null || markdown.isEmpty) {
      _snack('No preview available');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AgreementPreviewScreen(
          markdown: markdown,
          status: ag['status'] ?? 'draft',
          apprenticeEmail: ag['apprentice_email'],
          parentEmail: ag['parent_email'],
        ),
      ),
    );
  }

  Future<void> _signAgreement(Map<String, dynamic> ag) async {
    final controller = TextEditingController();
    bool submitting = false;
    await showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Sign Agreement', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Type your full name to sign this agreement.', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    labelStyle: TextStyle(color: Colors.amber),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: submitting ? null : () async {
                  final name = controller.text.trim();
                  if (name.length < 2) { _snack('Please enter your full name'); return; }
                  setState(() => submitting = true);
                  try {
                    await _api.apprenticeSignAgreement(agreementId: ag['id'], typedName: name);
                    if (!mounted) return;
                    Navigator.of(ctx).pop();
                    _snack('Signed successfully');
                    await _fetch();
                  } catch (e) {
                    setState(() => submitting = false);
                    _snack('Failed to sign: $e');
                  }
                },
                child: submitting
                    ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.black))
                    : const Text('Sign'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _requestParentResend(Map<String, dynamic> ag) async {
    try {
      await _api.requestParentResendRequest(ag['id']);
      _snack('Request sent to your mentor to resend the parent link');
    } catch (e) {
      _snack('Failed to send request: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.amber, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openExternalLink(String url) async {
    try {
      if (url.isEmpty) { _snack('Link is empty'); return; }
      final uri = Uri.tryParse(url);
      if (uri == null) { _snack('Invalid link'); return; }
      final ok = await canLaunchUrl(uri);
      if (!ok) { _snack('Cannot open link'); return; }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack('Failed to open: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Mentor', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh, color: Colors.amber))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
              : (_agreements.isEmpty)
                  ? Center(child: Text('No mentorship agreement yet. Your mentor will share one when ready.', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'), textAlign: TextAlign.center))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_mentorProfile != null || _primaryAgreement != null) _buildMentorOverviewCard(),
                        if (_pendingAgreements.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildPendingAgreementsSection(),
                        ],
                        const SizedBox(height: 12),
                        if (_primaryAgreement != null) _buildMeetingsCard(_primaryAgreement!),
                        const SizedBox(height: 12),
                        _buildSharedResourcesCard(),
                        const SizedBox(height: 12),
                        const Text('Mentorship Agreements', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                        const SizedBox(height: 8),
                        ..._agreements.map((ag) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _AgreementItem(
                            ag: ag,
                            onOpen: () => _openAgreement(ag),
                            onSign: () async {
                              await _signAgreement(ag);
                              if (!mounted) return;
                              Navigator.of(context).maybePop();
                              _snack('Agreement signed successfully');
                            },
                            onRequestResend: () => _requestParentResend(ag),
                          ),
                        )),
                      ],
                    ),
    );
  }

  Widget _buildSharedResourcesCard() {
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.link, color: Colors.amber),
                SizedBox(width: 8),
                Text('Shared Notes & Resources', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              ],
            ),
            const SizedBox(height: 8),
            if (_sharedResources.isEmpty)
              Text('No links shared yet.', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'))
            else ...[
              ..._sharedResources.map((r) {
                final title = (r['title'] ?? '').toString();
                final desc = (r['description'] ?? '').toString();
                final url = (r['link_url'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.open_in_new, color: Colors.amber),
                    title: Text(title.isEmpty ? 'Untitled' : title, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                    subtitle: desc.isNotEmpty ? Text(desc, style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')) : null,
                    trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                    onTap: () => _openExternalLink(url),
                  ),
                );
              })
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMentorOverviewCard() {
    final name = _mentorProfile?['name'] ?? _primaryAgreement?['mentor_name'] ?? 'Mentor';
    final emailRaw = _mentorProfile?['email'] ?? _primaryAgreement?['mentor_email'] ?? '';
    final role = _mentorProfile?['role'] ?? 'Mentor';
    final org = _mentorProfile?['organization'] ?? _mentorProfile?['church'] ?? '';
    final avatarUrl = _mentorProfile?['avatar_url'];
    final isActive = _mentorStatus != null && _mentorStatus!['has_active'] == true;
    final isEnded = !isActive; // paused state not yet implemented
    // Mask email if privacy: simple heuristic (show first char + domain)
    String displayEmail = emailRaw;
    if (emailRaw.isNotEmpty && emailRaw.contains('@')) {
      final parts = emailRaw.split('@');
      if (parts.first.length > 2) {
        displayEmail = parts.first.substring(0,1) + '***@' + parts.last;
      }
    }
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEnded) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(.12),
                  border: Border.all(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('This mentorship has ended. You can still review past agreements and history.', style: TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
              )
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(.15),
                    borderRadius: BorderRadius.circular(28),
                    image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                  ),
                  child: avatarUrl == null ? const Icon(Icons.person, color: Colors.amber, size: 30) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(role + (org.isNotEmpty ? ' • $org' : ''), style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                      if (emailRaw.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: emailRaw));
                            _snack('Mentor email copied');
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.email, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(displayEmail, style: TextStyle(color: Colors.grey[300], fontFamily: 'Poppins')),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isActive ? Colors.green : Colors.red).withOpacity(.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isActive ? Colors.green : Colors.red),
                  ),
                  child: Text(isActive ? 'Active' : 'Ended', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontFamily: 'Poppins')),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Mentor Profile button
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final p = await _api.getActiveMentorProfileForApprentice();
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text('Mentor Profile', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((p['avatar_url'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: CircleAvatar(radius: 28, backgroundImage: NetworkImage(p['avatar_url'])),
                              ),
                            Text('Name: ${p['name'] ?? 'N/A'}', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                            Text('Email: ${p['email'] ?? 'N/A'}', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                            if ((p['role_title'] ?? '').toString().isNotEmpty)
                              Text('Role: ${p['role_title']}', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                            if ((p['organization'] ?? '').toString().isNotEmpty)
                              Text('Organization: ${p['organization']}', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                            if ((p['phone'] ?? '').toString().isNotEmpty)
                              Text('Phone: ${p['phone']}', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                            if ((p['bio'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(p['bio'], style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close', style: TextStyle(color: Colors.grey)))
                        ],
                      ),
                    );
                  } catch (e) {
                    _snack('Failed to load mentor profile: $e');
                  }
                },
                icon: const Icon(Icons.person, size: 18, color: Colors.amber),
                label: const Text('Mentor Profile', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingAgreementsSection() {
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.pending_actions, color: Colors.amber),
                SizedBox(width: 8),
                Text('Pending Agreements', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              ],
            ),
            const SizedBox(height: 8),
            ..._pendingAgreements.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(child: Text('Agreement ${a['id'].toString().substring(0,6)}', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'))),
                  Text(a['status'], style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                  if (a['status'] == 'awaiting_apprentice') ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () { _snack('Navigate to sign flow (TODO)'); },
                      child: const Text('Review & Sign', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                    )
                  ]
                ],
              ),
            ))
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingsCard(Map<String, dynamic> ag) {
    final fields = (ag['fields_json'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final location = fields['meeting_location'];
    final duration = fields['meeting_duration_minutes'];
    final day = fields['meeting_day'];
    final time = fields['meeting_time'];
    final frequency = fields['meeting_frequency'];
    final startDate = fields['start_date'];
    final hasAny = [location, duration, day, time, frequency, startDate].any((e) => e != null && e.toString().isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();
    final nextMeeting = _computeNextMeetingDate(
      day?.toString(),
      time?.toString(),
      frequency?.toString(),
      startDate?.toString(),
    );
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.event, color: Colors.amber),
                SizedBox(width: 8),
                Text('Meetings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              ],
            ),
            const SizedBox(height: 8),
            if (day != null) Text('Day: $day', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            if (time != null) Text('Time: $time', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            if (location != null) Text('Location: $location', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            if (frequency != null) Text('Frequency: $frequency', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            if (duration != null) Text('Duration: ${duration}m', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            if (startDate != null) Text('Start: $startDate', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            if (nextMeeting != null) ...[
              const SizedBox(height: 6),
              Text('Next: ${_formatFriendly(nextMeeting)}', style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showRescheduleDialog(ag['id'].toString()),
                icon: const Icon(Icons.schedule, color: Colors.amber, size: 18),
                label: const Text('Request Reschedule', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showRescheduleDialog(String agreementId) {
    final reasonCtrl = TextEditingController();
    final proposalCtrls = [TextEditingController(), TextEditingController(), TextEditingController()];
    bool submitting = false;
    showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Request Reschedule', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Briefly explain why you need to reschedule (optional):', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    labelStyle: TextStyle(color: Colors.amber),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Propose up to 3 alternative times (free-form, e.g., Fri 4pm PST):', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                const SizedBox(height: 8),
                ...proposalCtrls.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    controller: c,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    decoration: const InputDecoration(
                      hintText: 'e.g., Tue 5pm PST',
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                    ),
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              onPressed: submitting ? null : () async {
                setState(() => submitting = true);
                try {
                  final proposals = proposalCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
                  await _api.requestMeetingReschedule(agreementId, reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(), proposals: proposals.isEmpty ? null : proposals);
                  if (!mounted) return;
                  setState(() => submitting = false);
                  Navigator.of(ctx).pop();
                  _snack('Reschedule request sent to your mentor');
                } catch (e) {
                  setState(() => submitting = false);
                  _snack('Failed to send request: $e');
                }
              },
              child: submitting
                  ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.black))
                  : const Text('Send Request'),
            )
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Next meeting calculation
  // Inputs (all strings, case-insensitive):
  //  - day: e.g., "Monday", "Mon"
  //  - time: e.g., "5pm", "5:30 PM", "17:00"
  //  - frequency: e.g., "Weekly", "Biweekly", "Monthly"
  //  - startDate: e.g., "2025-09-01" or "09/01/2025"
  // Returns next occurrence at or after now and not before startDate.
  DateTime? _computeNextMeetingDate(String? day, String? time, String? frequency, String? startDate) {
    if (day == null || time == null) return null;
    final wd = _parseWeekday(day);
    final hm = _parseTime(time);
    if (wd == null || hm == null) return null;
    final now = DateTime.now();
    final start = _parseDate(startDate) ?? now;
    final base = now.isAfter(start) ? now : start;
    final raw = (frequency ?? 'weekly').toLowerCase();
    final f = raw
        .replaceAll(RegExp(r'[\._-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    DateTime nextWeekly(DateTime from) {
      final fromAtTime = DateTime(from.year, from.month, from.day, hm.h, hm.m);
      final deltaDays = (wd - from.weekday + 7) % 7;
      var cand = fromAtTime.add(Duration(days: deltaDays));
      if (deltaDays == 0 && cand.isBefore(from)) cand = cand.add(const Duration(days: 7));
      return cand;
    }

    // helpers for k-weekly cadence anchored at first valid on/after start
    DateTime nextKWeekly(int k) {
      var first = nextWeekly(start);
      if (first.isBefore(start)) first = first.add(const Duration(days: 7));
      while (first.isBefore(base)) {
        first = first.add(Duration(days: 7 * k));
      }
      return first;
    }

    // Monthly (interval months) using nth weekday-of-month anchored by first valid on/after start
    DateTime nextEveryNMonths(int monthsInterval) {
      final anchor = nextWeekly(start);
      final nth = ((anchor.day - 1) ~/ 7) + 1; // 1..5
      int y = base.year;
      int m = base.month;
      for (var i = 0; i < 36; i++) {
        final cand = _nthWeekdayOfMonth(y, m, wd, nth, hm.h, hm.m) ??
            _lastWeekdayOfMonth(y, m, wd, hm.h, hm.m);
        if (!cand.isBefore(base) && !cand.isBefore(start)) return cand;
        final next = _addMonths(DateTime(y, m, 1), monthsInterval);
        y = next.year; m = next.month;
      }
      return _addMonths(base, monthsInterval); // fallback
    }

    // Semi-monthly: two occurrences per month based on nth and nth+2 (fallback to last)
    DateTime nextSemiMonthly() {
      final anchor = nextWeekly(start);
      final nth = ((anchor.day - 1) ~/ 7) + 1; // 1..5
      final nth2 = nth + 2; // 1->3, 2->4, 3->5, 4->6(→fallback), 5->7(→fallback)
      int y = base.year;
      int m = base.month;
      for (var i = 0; i < 24; i++) {
        final c1 = _nthWeekdayOfMonth(y, m, wd, nth, hm.h, hm.m) ?? _lastWeekdayOfMonth(y, m, wd, hm.h, hm.m);
        final c2 = _nthWeekdayOfMonth(y, m, wd, nth2, hm.h, hm.m) ?? _lastWeekdayOfMonth(y, m, wd, hm.h, hm.m);
        DateTime? best;
        for (final c in [c1, c2]) {
          if (!c.isBefore(base) && !c.isBefore(start)) {
            best = (best == null || c.isBefore(best)) ? c : best;
          }
        }
        if (best != null) return best;
        final next = _addMonths(DateTime(y, m, 1), 1);
        y = next.year; m = next.month;
      }
      return nextWeekly(base); // fallback
    }

    // Parse variants
    // Weekly patterns
    final everyNWeeks = RegExp(r'every\s+(\d+)\s*weeks?');
    final everyNMonths = RegExp(r'every\s+(\d+)\s*months?');

    final mWeeks = everyNWeeks.firstMatch(f);
    if (mWeeks != null) {
      final n = int.tryParse(mWeeks.group(1) ?? '1') ?? 1;
      return nextKWeekly(n.clamp(1, 52));
    }

    if (f.contains('fortnight')) return nextKWeekly(2);
    if (f.contains('every other week')) return nextKWeekly(2);
    if (f.contains('biweek')) return nextKWeekly(2);
    if (f.contains('once a week') || f.contains('once per week') || f.contains('weekly') || f.contains('per week') || f.contains('week')) {
      return nextKWeekly(1);
    }

    // Semi-monthly / twice a month
    if (f.contains('semi-month') || f.contains('semimonth') || (f.contains('twice') && f.contains('month')) || (f.contains('2x') && f.contains('month'))) {
      return nextSemiMonthly();
    }

    // Every N months
    final mMonths = everyNMonths.firstMatch(f);
    if (mMonths != null) {
      final n = int.tryParse(mMonths.group(1) ?? '1') ?? 1;
      return nextEveryNMonths(n.clamp(1, 12));
    }

    if (f.contains('bimonth')) return nextEveryNMonths(2); // treat as every 2 months
    if (f.contains('every other month')) return nextEveryNMonths(2);
    if (f.contains('quarter') || f.contains('once a quarter') || f.contains('per quarter') || f.contains('every quarter')) {
      return nextEveryNMonths(3);
    }
    if (f.contains('once a month') || f.contains('once per month') || f.contains('monthly') || f.contains('per month') || f.contains('month')) {
      return nextEveryNMonths(1);
    }

    // Fallback: weekly cadence
    return nextKWeekly(1);
  }

  // Parse weekday name → DateTime.weekday (Mon=1..Sun=7)
  int? _parseWeekday(String input) {
    final s = input.trim().toLowerCase();
    const map = {
      'mon': 1, 'monday': 1,
      'tue': 2, 'tues': 2, 'tuesday': 2,
      'wed': 3, 'weds': 3, 'wednesday': 3,
      'thu': 4, 'thur': 4, 'thurs': 4, 'thursday': 4,
      'fri': 5, 'friday': 5,
      'sat': 6, 'saturday': 6,
      'sun': 7, 'sunday': 7,
    };
    if (map.containsKey(s)) return map[s];
    for (final e in map.entries) {
      if (s.startsWith(e.key)) return e.value;
    }
    return null;
  }

  _HM? _parseTime(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll('.', '').replaceAll(' ', ''); // "5:30 pm" → "5:30pm"
    final am = s.endsWith('am');
    final pm = s.endsWith('pm');
    if (am || pm) s = s.substring(0, s.length - 2);
    int h = 0, m = 0;
    final parts = s.split(':');
    if (parts.length == 1) {
      h = int.tryParse(parts[0]) ?? -1; m = 0;
    } else if (parts.length >= 2) {
      h = int.tryParse(parts[0]) ?? -1;
      final mm = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
      m = int.tryParse(mm) ?? 0;
    }
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    if (am) { if (h == 12) h = 0; }
    if (pm) { if (h < 12) h += 12; }
    return _HM(h, m);
  }

  DateTime? _parseDate(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final s = input.trim();
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$').firstMatch(s);
    if (m != null) {
      final mm = int.parse(m.group(1)!);
      final dd = int.parse(m.group(2)!);
      final yyyy = int.parse(m.group(3)!);
      if (mm >= 1 && mm <= 12 && dd >= 1 && dd <= 31) {
        return DateTime(yyyy, mm, dd);
      }
    }
    return null;
  }

  DateTime _addMonths(DateTime d, int months) {
    final y = d.year + ((d.month - 1 + months) ~/ 12);
    final m = ((d.month - 1 + months) % 12) + 1;
    final day = d.day;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day > lastDay ? lastDay : day);
  }

  DateTime? _nthWeekdayOfMonth(int year, int month, int weekday, int nth, int hour, int minute) {
    if (nth < 1) return null;
    final first = DateTime(year, month, 1, hour, minute);
    final delta = (weekday - first.weekday + 7) % 7;
    final day = 1 + delta + (nth - 1) * 7;
    final lastDay = DateTime(year, month + 1, 0).day;
    if (day > lastDay) return null; // that nth doesn't exist this month
    return DateTime(year, month, day, hour, minute);
  }

  DateTime _lastWeekdayOfMonth(int year, int month, int weekday, int hour, int minute) {
    final last = DateTime(year, month + 1, 0, hour, minute);
    final delta = (last.weekday - weekday + 7) % 7;
    return last.subtract(Duration(days: delta));
  }

  String _formatFriendly(DateTime dt) {
    const dows = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mos = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dow = dows[(dt.weekday - 1).clamp(0, 6)];
    final mon = mos[(dt.month - 1).clamp(0, 11)];
    final h24 = dt.hour;
    final isPM = h24 >= 12;
    final h12raw = h24 % 12;
    final h12 = h12raw == 0 ? 12 : h12raw;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = isPM ? 'PM' : 'AM';
    return '$dow, $mon ${dt.day}, ${dt.year} · $h12:$mm $ampm';
  }
}

class _AgreementItem extends StatelessWidget {
  final Map<String, dynamic> ag;
  final VoidCallback onOpen;
  final VoidCallback onSign;
  final VoidCallback onRequestResend;
  const _AgreementItem({required this.ag, required this.onOpen, required this.onSign, required this.onRequestResend});

  Color _statusColor(String s) {
    switch (s) {
      case 'awaiting_apprentice': return Colors.orange;
      case 'awaiting_parent': return Colors.purple;
      case 'fully_signed': return Colors.green;
      case 'revoked': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'awaiting_apprentice': return 'Awaiting you';
      case 'awaiting_parent': return 'Awaiting parent';
      case 'fully_signed': return 'Completed';
      case 'revoked': return 'Revoked';
      default: return s;
    }
  }

  String? _shortDate(String? iso) {
    if (iso == null) return null;
    try { final d = DateTime.parse(iso); return '${d.month}/${d.day}/${d.year}'; } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final status = ag['status'] as String? ?? 'unknown';
    final mentorName = ag['mentor_name'] ?? 'Mentor';
    final createdAt = ag['created_at'] as String?;
    final canSign = status == 'awaiting_apprentice';
    final awaitingParent = status == 'awaiting_parent';
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('With $mentorName', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _statusColor(status).withOpacity(.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontFamily: 'Poppins')),
                )
              ],
            ),
            if (awaitingParent)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(.12),
                  border: Border.all(color: Colors.purple),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.family_restroom, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Awaiting parent/guardian signature', style: TextStyle(color: Colors.white, fontFamily: 'Poppins'))),
                    TextButton.icon(
                      onPressed: onRequestResend,
                      icon: const Icon(Icons.send, color: Colors.purpleAccent, size: 18),
                      label: const Text('Request Resend', style: TextStyle(color: Colors.purpleAccent, fontFamily: 'Poppins')),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(createdAt != null ? 'Created ${_shortDate(createdAt)}' : '', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, color: Colors.amber, size: 18),
                  label: const Text('Open', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
                ),
                const SizedBox(width: 8),
                if (canSign)
                  ElevatedButton.icon(
                    onPressed: onSign,
                    icon: const Icon(Icons.edit, color: Colors.black, size: 18),
                    label: const Text('Review & Sign', style: TextStyle(color: Colors.black, fontFamily: 'Poppins')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
