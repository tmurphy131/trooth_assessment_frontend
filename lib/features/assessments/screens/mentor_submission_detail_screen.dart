import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/api_service.dart';
import '../data/assessments_repository.dart';
import '../models/submission_models.dart';
import '../models/mentor_report_v2.dart';
import '../widgets/kpi_card.dart';
// import '../widgets/bar_row.dart';
// import '../widgets/level_badge.dart';
import '../widgets/insight_card.dart';
import 'mentor_report_simplified_screen.dart';

class MentorSubmissionDetailScreen extends StatefulWidget {
  final String assessmentId;
  final String apprenticeName;
  final String apprenticeId;
  const MentorSubmissionDetailScreen({super.key, required this.assessmentId, required this.apprenticeId, required this.apprenticeName});

  @override
  State<MentorSubmissionDetailScreen> createState() => _MentorSubmissionDetailScreenState();
}

class _MentorSubmissionDetailScreenState extends State<MentorSubmissionDetailScreen> with SingleTickerProviderStateMixin {
  late final AssessmentsRepository _repo;
  SubmissionDetail? _detail;
  MentorReportV2? _report;
  String? _error;
  late final TabController _tab;
  bool _loading = true;
  String? _mentorEmail;

  @override
  void initState() {
    super.initState();
    _repo = AssessmentsRepository(ApiService());
    _tab = TabController(length: 2, vsync: this);
    _load();
    _loadMentorEmail();
  }

  Future<void> _loadMentorEmail() async {
    try {
      // Prefer backend mentor profile (authoritative); fallback to Firebase auth email
      final profile = await ApiService().getMyMentorProfile();
      final email = (profile['email'] ?? '').toString();
      if (email.isNotEmpty) {
        if (!mounted) return; setState(() { _mentorEmail = email; });
        return;
      }
    } catch (_) {
      // ignore and try fallback
    }
    try {
      // Fallback
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (email != null && email.isNotEmpty) {
        if (!mounted) return; setState(() { _mentorEmail = email; });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await _repo.getSubmissionDetail(widget.assessmentId);
      final r = await _repo.getMentorReportV2(widget.assessmentId);
      if (!mounted) return;
      setState(() { _detail = d; _report = r; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Submission · ${widget.apprenticeName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Simplified View',
            onPressed: _openSimplifiedReport,
          ),
        ],
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'Answers'), Tab(text: 'Report')]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(controller: _tab, children: [
                  _answersTab(),
                  _reportTab(),
                ]),
      bottomNavigationBar: _footerActions(context),
    );
  }

  Widget _footerActions(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _emailReport, icon: const Icon(Icons.mail_outline), label: const Text('Email report'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton.icon(onPressed: _downloadPdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Download PDF'))),
        ]),
      ),
    );
  }

  Future<void> _emailReport() async {
    try {
      final to = _mentorEmail;
      if (to == null || to.isEmpty) {
        if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No mentor email found.')));
        return;
      }
      final res = await ApiService().emailMentorReportByAssessment(assessmentId: widget.assessmentId, toEmail: to, includePdf: true);
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email sent for assessment ${res['assessment_id']}')));
    } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email failed: $e'))); }
  }

  Future<void> _downloadPdf() async {
    try {
      final r = await ApiService().downloadMentorReportPdf(assessmentId: widget.assessmentId);
      if (r.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/mentor_report_${widget.assessmentId}.pdf');
        await file.writeAsBytes(r.bodyBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Mentor Report for ${widget.apprenticeName}');
        if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF saved and share sheet opened.')));
      } else {
        if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: ${r.statusCode}')));
      }
    } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download error: $e'))); }
  }

  void _openSimplifiedReport() {
    if (_report == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report not loaded yet')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MentorReportSimplifiedScreen(
          report: _report!,
          apprenticeName: widget.apprenticeName,
        ),
      ),
    );
  }

  Widget _answersTab() {
    final d = _detail; if (d == null) return const SizedBox.shrink();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: d.questions.length,
      itemBuilder: (context, i) {
        final q = d.questions[i];
        if (q.type == 'mc' || q.type == 'multiple_choice') {
          return _mcTile(q);
        } else {
          return _openTile(q);
        }
      },
    );
  }

  Widget _mcTile(QuestionItem q) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...q.options.map((o) {
            final chosen = (q.chosenOptionId != null && q.chosenOptionId == o.id) || (q.apprenticeAnswer != null && q.apprenticeAnswer!.trim().toLowerCase() == o.text.trim().toLowerCase());
            final correct = o.isCorrect;
            final leading = Icon(chosen ? Icons.radio_button_checked : Icons.radio_button_off, color: chosen ? Colors.blue : null);
            final trailing = correct ? const _Badge(text: 'Correct') : (chosen && !correct ? const _Badge(text: 'Chosen') : null);
            final style = TextStyle(color: chosen && !correct ? Colors.red : null, fontWeight: chosen ? FontWeight.w600 : FontWeight.w400);
            return ListTile(leading: leading, title: Text(o.text, style: style), trailing: trailing);
          }).toList(),
          if (q.options.any((o) => o.isCorrect) && (q.chosenOptionId == null || !q.options.any((o) => o.id == q.chosenOptionId)))
            const Padding(padding: EdgeInsets.only(top: 4), child: Text('Correct answer shown above.', style: TextStyle(color: Colors.grey))),
        ]),
      ),
    );
  }

  Widget _openTile(QuestionItem q) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SelectableText(q.apprenticeAnswer ?? '(no answer)'),
          if (q.rubric != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              if (q.rubric!.understanding != null) Chip(label: Text('Understanding: ${q.rubric!.understanding}')),
              if (q.rubric!.practice != null) Chip(label: Text('Practice: ${q.rubric!.practice}')),
              if (q.rubric!.gospelCenteredness != null) Chip(label: Text('Gospel: ${q.rubric!.gospelCenteredness}')),
              if (q.rubric!.humility != null) Chip(label: Text('Humility: ${q.rubric!.humility}')),
              if (q.rubric!.teachability != null) Chip(label: Text('Teachability: ${q.rubric!.teachability}')),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _reportTab() {
    final r = _report; if (r == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: () async { await _load(); },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: KpiCard(title: 'Biblical Knowledge', value: '${r.snapshot.overallMcPercent}%', subtitle: r.snapshot.knowledgeBand)),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(title: 'Spiritual Life', value: _deriveOpenLevel(r), subtitle: 'Open-ended')),
          ]),
          const SizedBox(height: 12),
          if (r.biblicalKnowledge != null && r.biblicalKnowledge!.topicBreakdown.isNotEmpty) ...[
            const Text('Knowledge Breakdown', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...r.biblicalKnowledge!.topicBreakdown.map((t) => ListTile(title: Text(t.topic), subtitle: Text('${t.correct}/${t.total} (${((t.total==0?0: (t.correct/t.total*100)).toStringAsFixed(1))}%)'), trailing: t.note==null?null:Text(t.note!)))
          ],
          const SizedBox(height: 12),
          const Text('Insights', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...r.openEndedInsights.map((i) => InsightCard(insight: i)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Top Strengths', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...r.snapshot.topStrengths.map((s) => Text('• $s')),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Top Gaps', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...r.snapshot.topGaps.map((s) => Text('• $s')),
            ])),
          ]),
          const SizedBox(height: 12),
          const Text('Four‑Week Plan', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: r.fourWeekPlan.rhythm.map((e) => Text('• $e')).toList())),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: r.fourWeekPlan.checkpoints.map((e) => Text('• $e')).toList())),
          ]),
          const SizedBox(height: 12),
          const Text('Conversation Starters', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...r.conversationStarters.map((e) => Text('• $e')),
          const SizedBox(height: 12),
          const Text('Recommended Resources', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...r.recommendedResources.map((res) => Text('• ${res.title} — ${res.why} (${res.type})')),
        ],
      ),
    );
  }

  String _deriveOpenLevel(MentorReportV2 r) {
    // If we had an explicit overall_open_level we would show it; otherwise majority
    final levels = r.openEndedInsights.map((e) => e.level).toList();
    if (levels.isEmpty) return '-';
    levels.sort();
    String best = levels.first; int bestCount = 1; int run = 1;
    for (int i=1;i<levels.length;i++) { if (levels[i]==levels[i-1]) { run++; if (run>bestCount) { best=levels[i]; bestCount=run; } } else { run=1; } }
    return best;
  }
}

class _Badge extends StatelessWidget { final String text; const _Badge({required this.text}); @override Widget build(BuildContext context) { return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(text, style: const TextStyle(color: Colors.green))); }}
