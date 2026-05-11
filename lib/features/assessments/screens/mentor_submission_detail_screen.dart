import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/api_service.dart';
import '../../../models/mentor_note.dart';
import '../../../widgets/mentor_note_card.dart';
import '../../../widgets/add_edit_note_dialog.dart';
import '../../../theme.dart';
import '../data/assessments_repository.dart';
import '../models/submission_models.dart';
import '../models/mentor_report_v2.dart';
import '../widgets/kpi_card.dart';
// import '../widgets/bar_row.dart';
// import '../widgets/level_badge.dart';
import '../widgets/insight_card.dart';
import 'mentor_report_simplified_screen.dart';
import '../../../screens/subscription_screen.dart';

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
  
  // Mentor notes state
  List<MentorNote> _notes = [];
  bool _notesLoading = false;
  
  // Premium state
  bool _isPremium = false;
  bool _checkingPremium = true;
  Map<String, dynamic>? _fullReport;
  bool _loadingFullReport = false;
  bool _fullReportCached = false;

  @override
  void initState() {
    super.initState();
    _repo = AssessmentsRepository(ApiService());
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      // Trigger rebuild to show/hide FAB based on current tab
      if (mounted) setState(() {});
    });
    _load();
    _loadMentorEmail();
    _loadNotes();
    _checkPremiumAndLoadFullReport();
  }

  /// Check if user is premium and load full report if so
  Future<void> _checkPremiumAndLoadFullReport() async {
    setState(() => _checkingPremium = true);
    try {
      final isPremium = await ApiService().isPremiumUser();
      if (!mounted) return;
      setState(() {
        _isPremium = isPremium;
        _checkingPremium = false;
      });
      
      // If premium, auto-load the full report
      if (isPremium) {
        await _loadFullReport();
      }
    } catch (e) {
      dev.log('[MentorSubmissionDetail] Error checking premium: $e');
      if (!mounted) return;
      setState(() {
        _isPremium = false;
        _checkingPremium = false;
      });
    }
  }

  /// Load the full premium report for this assessment
  Future<void> _loadFullReport() async {
    setState(() => _loadingFullReport = true);
    try {
      final response = await ApiService().fetchFullReport(draftId: widget.assessmentId);
      if (!mounted) return;
      
      dev.log('[MentorSubmissionDetail] Full report response keys: ${response.keys.toList()}');
      
      final report = response['report'] as Map<String, dynamic>?;
      final cached = response['cached'] as bool? ?? false;
      
      if (report != null) {
        dev.log('[MentorSubmissionDetail] Report keys: ${report.keys.toList()}');
      } else {
        dev.log('[MentorSubmissionDetail] Report is null! Response: $response');
      }
      
      setState(() {
        _fullReport = report;
        _fullReportCached = cached;
        _loadingFullReport = false;
      });
      dev.log('[MentorSubmissionDetail] Full report loaded, cached: $cached');
    } catch (e) {
      dev.log('[MentorSubmissionDetail] Error loading full report: $e');
      if (!mounted) return;
      setState(() => _loadingFullReport = false);
    }
  }

  Future<void> _loadNotes() async {
    setState(() => _notesLoading = true);
    try {
      final notes = await ApiService().getMentorNotesForAssessment(widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _notesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _notesLoading = false);
    }
  }

  Future<void> _addNote() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddEditNoteDialog(),
    );

    if (result != null && mounted) {
      setState(() => _notesLoading = true);
      try {
        await ApiService().createMentorNote(
          assessmentId: widget.assessmentId,
          content: result['content'] as String,
          isPrivate: result['is_private'] as bool,
        );
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note added'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        setState(() => _notesLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add note: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editNote(MentorNote note) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddEditNoteDialog(
        initialNoteText: note.content,
        initialShared: note.isShared,
        isEditing: true,
      ),
    );

    if (result != null && mounted) {
      setState(() => _notesLoading = true);
      try {
        await ApiService().updateMentorNote(
          noteId: note.id,
          content: result['content'] as String,
          isPrivate: result['is_private'] as bool,
        );
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note updated'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        setState(() => _notesLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update note: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteNote(MentorNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _notesLoading = true);
      try {
        await ApiService().deleteMentorNote(note.id);
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note deleted'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        setState(() => _notesLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete note: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Submission · ${widget.apprenticeName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Only show "Simplified View" button for non-premium users
          // Premium users already see full report in the tab
          if (!_isPremium)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined, color: Colors.white),
              tooltip: 'Simplified View',
              onPressed: _openSimplifiedReport,
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.amber,
          tabs: [
            const Tab(text: 'Answers'),
            const Tab(text: 'Report'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Notes'),
                  if (_notes.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: troothGold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_notes.length}',
                        style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 2 ? FloatingActionButton(
        onPressed: _addNote,
        backgroundColor: troothGold,
        child: const Icon(Icons.add, color: Colors.black),
      ) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(controller: _tab, children: [
                  _answersTab(),
                  _reportTab(),
                  _notesTab(),
                ]),
      bottomNavigationBar: _footerActions(context),
    );
  }

  Widget _footerActions(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _emailReport, 
                icon: const Icon(Icons.mail_outline, color: Colors.white70), 
                label: const Text('Email report', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _showExportOptions, 
                icon: const Icon(Icons.ios_share, color: Colors.black), 
                label: const Text('Export PDF', style: TextStyle(color: Colors.black)),
                style: FilledButton.styleFrom(backgroundColor: Colors.amber),
              ),
            ),
          ]),
        ),
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

  /// Show export options bottom sheet
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Export Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.ios_share, color: Colors.blue.shade300),
                ),
                title: const Text('Share PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                subtitle: Text('Save to Files, Notes, AirDrop, or other apps', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _sharePdf();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.visibility, color: Colors.purple.shade300),
                ),
                title: const Text('Preview PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                subtitle: Text('View the report before sharing', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _previewPdf();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.email_outlined, color: Colors.amber.shade300),
                ),
                title: const Text('Email Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                subtitle: Text('Send PDF to your email address', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _emailReport();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  /// Download and share PDF via system share sheet
  Future<void> _sharePdf() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing PDF...'), duration: Duration(seconds: 1)),
      );
      
      final r = await ApiService().downloadMentorReportPdf(assessmentId: widget.assessmentId);
      if (r.statusCode == 200) {
        // Save to documents directory for sharing (iOS requires this for share sheet)
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'TroothReport_${widget.apprenticeName.replaceAll(' ', '_')}_${widget.assessmentId.substring(0, 8)}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(r.bodyBytes);
        
        if (!await file.exists()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to prepare PDF')));
          return;
        }
        
        // Open share sheet with proper origin for iOS
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        final sharePositionOrigin = box != null 
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'T[root]H Report - ${widget.apprenticeName}',
          text: 'Mentor Report for ${widget.apprenticeName}',
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download PDF: ${r.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Preview PDF in a full-screen viewer with share option
  Future<void> _previewPdf() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading preview...'), duration: Duration(seconds: 1)),
      );
      
      final r = await ApiService().downloadMentorReportPdf(assessmentId: widget.assessmentId);
      if (r.statusCode == 200) {
        // Save to documents directory (iOS requires this for sharing from preview)
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'TroothReport_${widget.apprenticeName.replaceAll(' ', '_')}_${widget.assessmentId.substring(0, 8)}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(r.bodyBytes);
        
        if (!await file.exists()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load PDF')));
          return;
        }
        
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _PdfPreviewScreen(
              filePath: file.path,
              fileName: fileName,
              apprenticeName: widget.apprenticeName,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load PDF: ${r.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
          draftId: widget.assessmentId,
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
    // If still loading, show loading state
    if (_checkingPremium) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: troothGold),
            const SizedBox(height: 16),
            Text(
              'Loading report...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Always show the simplified reactive report as default
    // with a button to view premium report
    return _buildSimplifiedReportTab();
  }

  /// Build the premium full report view inline
  Widget _buildPremiumReportTab() {
    final report = _fullReport!;
    
    // Debug logging for report structure
    dev.log('[MentorSubmissionDetail] Building premium report with keys: ${report.keys.toList()}');
    
    // Extract sections from the premium report
    final strengthsDeepDive = report['strengths_deep_dive'] as List<dynamic>?;
    final gapsDeepDive = report['gaps_deep_dive'] as List<dynamic>?;
    final execSummary = report['executive_summary'] as Map<String, dynamic>?;
    final conversationGuide = report['conversation_guide'] as Map<String, dynamic>?;
    final biblicalKnowledge = report['biblical_knowledge_analysis'] as Map<String, dynamic>?;
    final spiritualFormation = report['spiritual_formation_insights'] as List<dynamic>?;
    final meta = report['_meta'] as Map<String, dynamic>?;
    
    dev.log('[MentorSubmissionDetail] execSummary: ${execSummary?.keys.toList()}');
    dev.log('[MentorSubmissionDetail] strengthsDeepDive count: ${strengthsDeepDive?.length}, first: ${strengthsDeepDive?.isNotEmpty == true ? (strengthsDeepDive!.first as Map?)?.keys.toList() : null}');
    dev.log('[MentorSubmissionDetail] gapsDeepDive count: ${gapsDeepDive?.length}');
    dev.log('[MentorSubmissionDetail] conversationGuide: ${conversationGuide?.keys.toList()}');
    dev.log('[MentorSubmissionDetail] biblicalKnowledge: ${biblicalKnowledge?.keys.toList()}');
    dev.log('[MentorSubmissionDetail] spiritualFormation count: ${spiritualFormation?.length}');

    return RefreshIndicator(
      onRefresh: () async {
        await _loadFullReport();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Premium badge header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade100, Colors.amber.shade50],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Report',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      Row(
                        children: [
                          if (_fullReportCached)
                            Row(
                              children: [
                                Icon(Icons.cached, size: 12, color: Colors.amber.shade700),
                                const SizedBox(width: 4),
                                Text('Instant load', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                              ],
                            ),
                          if (meta != null) ...[
                            if (_fullReportCached) Text(' • ', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                            Text(
                              'Generated by ${meta['model'] ?? 'AI'}',
                              style: TextStyle(fontSize: 11, color: Colors.amber.shade700),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Executive Summary
          if (execSummary != null) ...[
            _buildSectionHeader('Executive Summary', Icons.summarize),
            const SizedBox(height: 12),
            _buildExecutiveSummary(execSummary),
            const SizedBox(height: 20),
          ],

          // Strengths Deep Dive
          if (strengthsDeepDive != null && strengthsDeepDive.isNotEmpty) ...[
            _buildSectionHeader('Strengths Deep Dive', Icons.thumb_up),
            const SizedBox(height: 12),
            ...strengthsDeepDive.map((s) => _buildStrengthDeepDiveCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Gaps Deep Dive (with growth pathways)
          if (gapsDeepDive != null && gapsDeepDive.isNotEmpty) ...[
            _buildSectionHeader('Growth Areas Deep Dive', Icons.trending_up),
            const SizedBox(height: 12),
            ...gapsDeepDive.map((g) => _buildGapDeepDiveCard(g as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Conversation Guide
          if (conversationGuide != null) ...[
            _buildSectionHeader('Mentor Conversation Guide', Icons.chat),
            const SizedBox(height: 12),
            _buildConversationGuideSection(conversationGuide),
            const SizedBox(height: 20),
          ],

          // Biblical Knowledge Deep Dive
          if (biblicalKnowledge != null) ...[
            _buildSectionHeader('Biblical Knowledge Analysis', Icons.menu_book),
            const SizedBox(height: 12),
            _buildBiblicalKnowledgeSection(biblicalKnowledge),
            const SizedBox(height: 20),
          ],

          // Spiritual Formation Insights
          if (spiritualFormation != null && spiritualFormation.isNotEmpty) ...[
            _buildSectionHeader('Spiritual Formation Insights', Icons.self_improvement),
            const SizedBox(height: 12),
            ...spiritualFormation.map((s) => _buildSpiritualFormationCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Fallback: show raw JSON if structure is unexpected
          if (strengthsDeepDive == null && gapsDeepDive == null && conversationGuide == null) ...[
            _buildSectionHeader('Report Data', Icons.data_object),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _prettyPrintJson(report),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build the simplified report view - navigates to the full interactive simplified screen
  Widget _buildSimplifiedReportTab() {
    final r = _report; 
    if (r == null) return const SizedBox.shrink();
    
    return RefreshIndicator(
      onRefresh: () async { await _load(); },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Premium Full Report Button - prominent at top
          _buildPremiumReportButton(),
          const SizedBox(height: 16),
          
          // Health Score Card (styled nicely)
          _buildHealthScoreCard(r),
          const SizedBox(height: 16),

          // Urgent Flags (if any)
          if (r.flags.red.isNotEmpty) ...[
            _buildUrgentFlag(r.flags.red.first),
            const SizedBox(height: 16),
          ],

          // Priority Action Card
          _buildPriorityActionCard(r),
          const SizedBox(height: 16),

          // Top Strengths & Gaps in nice cards
          _buildStrengthsGapsSection(r),
          const SizedBox(height: 24),

          // Expandable Sections
          _buildExpandableKnowledgeSection(r),
          const SizedBox(height: 12),
          
          _buildExpandableInsightsSection(r),
          const SizedBox(height: 12),
          
          _buildExpandablePlanSection(r),
          const SizedBox(height: 24),

          // Conversation Starter Card
          if (r.conversationStarters.isNotEmpty) ...[
            _buildConversationStarterCard(r),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // Expandable section state
  bool _showBiblicalKnowledge = false;
  bool _showInsights = false;
  bool _showPlan = false;

  Widget _buildPremiumReportButton() {
    final isLoading = _loadingFullReport;
    final isPremium = _isPremium;
    final hasFullReport = _fullReport != null;
    
    return GestureDetector(
      onTap: isLoading ? null : _onPremiumReportTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPremium 
              ? [Colors.amber.shade700, Colors.amber.shade500]
              : [Colors.grey[800]!, Colors.grey[700]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPremium ? Colors.amber.shade300 : Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading 
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    Icons.auto_awesome,
                    color: isPremium ? Colors.white : Colors.amber,
                    size: 24,
                  ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isPremium ? 'View Full Premium Report' : 'Unlock Premium Report',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (!isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPremium 
                      ? (hasFullReport ? 'Deep analysis, growth pathways & conversation guides' : 'Tap to generate AI-powered insights')
                      : 'Get deeper insights, growth pathways & personalized guides',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _onPremiumReportTap() {
    if (_isPremium) {
      // Premium user - show premium report (navigate to full screen or show inline)
      if (_fullReport != null) {
        _showPremiumReportScreen();
      } else {
        // Load and then show
        _loadFullReport().then((_) {
          if (_fullReport != null && mounted) {
            _showPremiumReportScreen();
          }
        });
      }
    } else {
      // Free user - show premium gate
      _showPremiumGate();
    }
  }

  void _showPremiumReportScreen() {
    // Navigate to a full-screen premium report view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PremiumReportFullScreen(
          report: _fullReport!,
          apprenticeName: widget.apprenticeName,
          cached: _fullReportCached,
        ),
      ),
    );
  }

  void _showPremiumGate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(Icons.auto_awesome, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Premium Report',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock deeper insights into your apprentice\'s spiritual journey',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            _premiumFeatureRow(Icons.psychology, 'Deep-dive strength & gap analysis'),
            _premiumFeatureRow(Icons.route, 'Personalized 12-week growth pathways'),
            _premiumFeatureRow(Icons.chat_bubble_outline, 'Multi-session conversation guides'),
            _premiumFeatureRow(Icons.menu_book, 'Biblical knowledge breakdown'),
            _premiumFeatureRow(Icons.lightbulb_outline, 'Spiritual formation insights'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  // Navigate to subscription page
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  );
                  // Refresh premium status if subscription changed
                  if (result == true) {
                    _checkPremiumAndLoadFullReport();
                  }
                },
                icon: const Icon(Icons.star, color: Colors.black),
                label: const Text('Upgrade to Premium', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later', style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _premiumFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard(MentorReportV2 r) {
    final overallPercent = r.snapshot.overallMcPercent;
    final band = r.snapshot.knowledgeBand;
    final bandColor = _getBandColor(band);
    final bandIcon = _getBandIcon(band);

    return Card(
      elevation: 2,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bandColor.withOpacity(0.2), Colors.grey[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Score', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${overallPercent.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: bandColor),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Icon(bandIcon, color: bandColor, size: 32),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: bandColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(band, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBandColor(String band) {
    switch (band.toLowerCase()) {
      case 'excellent': return Colors.green;
      case 'maturing': return Colors.amber;
      case 'growing': return Colors.orange;
      case 'beginning': return Colors.red.shade400;
      default: return Colors.grey;
    }
  }

  IconData _getBandIcon(String band) {
    switch (band.toLowerCase()) {
      case 'excellent': return Icons.emoji_events;
      case 'maturing': return Icons.trending_up;
      case 'growing': return Icons.spa;
      case 'beginning': return Icons.eco;
      default: return Icons.circle;
    }
  }

  Widget _buildUrgentFlag(String flag) {
    return Card(
      color: Colors.red.shade900.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade300, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Urgent Attention', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade300)),
                  const SizedBox(height: 4),
                  Text(flag, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityActionCard(MentorReportV2 r) {
    final action = r.snapshot.topGaps.isNotEmpty ? r.snapshot.topGaps.first : 'Continue current growth path';
    
    return Card(
      color: Colors.amber.shade900.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.flag, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Priority Focus', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  const SizedBox(height: 4),
                  Text(action, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthsGapsSection(MentorReportV2 r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Card(
            color: Colors.green.shade900.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.thumb_up, color: Colors.green.shade300, size: 20),
                      const SizedBox(width: 8),
                      Text('Strengths', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade300)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...r.snapshot.topStrengths.take(3).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•', style: TextStyle(color: Colors.green.shade300)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            color: Colors.orange.shade900.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.orange.shade300, size: 20),
                      const SizedBox(width: 8),
                      Text('Growth Areas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade300)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...r.snapshot.topGaps.take(3).map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•', style: TextStyle(color: Colors.orange.shade300)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(g, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableKnowledgeSection(MentorReportV2 r) {
    final bk = r.biblicalKnowledge;
    final hasTopicBreakdown = bk != null && bk.topicBreakdown.isNotEmpty;
    final hasV21Data = bk != null && (bk.percent != null || (bk.weakTopics != null && bk.weakTopics!.isNotEmpty));
    
    return _buildExpandableSection(
      title: 'Biblical Knowledge',
      icon: Icons.menu_book,
      isExpanded: _showBiblicalKnowledge,
      onTap: () => setState(() => _showBiblicalKnowledge = !_showBiblicalKnowledge),
      child: hasTopicBreakdown
        ? Column(
            children: bk!.topicBreakdown.map((t) => ListTile(
              dense: true,
              title: Text(t.topic, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${t.correct}/${t.total} (${((t.total==0?0: (t.correct/t.total*100)).toStringAsFixed(0))}%)', style: TextStyle(color: Colors.grey[400])),
              trailing: t.note != null ? Text(t.note!, style: TextStyle(color: Colors.amber.shade300, fontSize: 12)) : null,
            )).toList(),
          )
        : hasV21Data
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bk!.percent != null) ...[
                  Row(children: [
                    Text('${bk.percent!.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(_getKnowledgeBand(bk.percent!), style: TextStyle(color: Colors.amber.shade300, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],
                if (bk.weakTopics != null && bk.weakTopics!.isNotEmpty) ...[
                  const Text('Areas to Study:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 8),
                  ...bk.weakTopics!.map((topic) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.circle, size: 8, color: Colors.orange.shade300),
                      const SizedBox(width: 8),
                      Text(topic, style: const TextStyle(color: Colors.white70)),
                    ]),
                  )),
                ],
                if (bk.studyRecommendation != null && bk.studyRecommendation!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue.shade300),
                      const SizedBox(width: 8),
                      Expanded(child: Text(bk.studyRecommendation!, style: TextStyle(color: Colors.blue.shade200, fontSize: 13))),
                    ]),
                  ),
                ],
              ],
            )
          : const Text('No breakdown available', style: TextStyle(color: Colors.grey)),
    );
  }

  String _getKnowledgeBand(num percent) {
    if (percent >= 90) return 'Excellent';
    if (percent >= 80) return 'Good';
    if (percent >= 70) return 'Average';
    if (percent >= 60) return 'Needs Improvement';
    return 'Significant Study';
  }

  Widget _buildExpandableInsightsSection(MentorReportV2 r) {
    return _buildExpandableSection(
      title: 'Spiritual Insights',
      icon: Icons.lightbulb_outline,
      isExpanded: _showInsights,
      onTap: () => setState(() => _showInsights = !_showInsights),
      child: Column(
        children: r.openEndedInsights.map((i) => InsightCard(insight: i)).toList(),
      ),
    );
  }

  Widget _buildExpandablePlanSection(MentorReportV2 r) {
    return _buildExpandableSection(
      title: 'Four-Week Plan',
      icon: Icons.calendar_month,
      isExpanded: _showPlan,
      onTap: () => setState(() => _showPlan = !_showPlan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Rhythm', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          ...r.fourWeekPlan.rhythm.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $e', style: const TextStyle(color: Colors.white70)),
          )),
          const SizedBox(height: 12),
          const Text('Checkpoints', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          ...r.fourWeekPlan.checkpoints.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $e', style: const TextStyle(color: Colors.white70)),
          )),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16))),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildConversationStarterCard(MentorReportV2 r) {
    final starter = r.conversationStarters.isNotEmpty ? r.conversationStarters.first : null;
    if (starter == null) return const SizedBox.shrink();
    
    return Card(
      color: Colors.blue.shade900.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.blue.shade300, size: 20),
                const SizedBox(width: 8),
                Text('Conversation Starter', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade300)),
              ],
            ),
            const SizedBox(height: 12),
            Text('"$starter"', style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 15)),
            if (r.conversationStarters.length > 1) ...[
              const SizedBox(height: 8),
              Text('+ ${r.conversationStarters.length - 1} more', style: TextStyle(color: Colors.blue.shade300, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  // Premium report helper widgets
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.amber.shade300),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildExecutiveSummary(Map<String, dynamic> summary) {
    // Support both AI-generated fields and legacy fields
    final healthScore = summary['health_score'];
    final healthBand = summary['health_band'] as String?;
    final oneLiner = summary['one_liner'] as String? ?? summary['overall_assessment'] as String?;
    final trajectory = summary['trajectory'] as String?;
    final trajectoryNote = summary['trajectory_note'] as String?;
    // Legacy fallbacks
    final keyStrengths = summary['key_strengths'] as List<dynamic>? ?? [];
    final priorityGrowthAreas = summary['priority_growth_areas'] as List<dynamic>? ?? [];
    final recommendedFocus = summary['recommended_focus'] as String?;

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Health score and band (from premium report)
            if (healthScore != null || healthBand != null) ...[  
              Row(
                children: [
                  if (healthScore != null) ...[  
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Health Score: $healthScore',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade300),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (healthBand != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        healthBand,
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue.shade300),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // One-liner summary
            if (oneLiner != null) ...[
              Text(oneLiner, style: const TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 12),
            ],
            // Trajectory info (from premium report)
            if (trajectory != null || trajectoryNote != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: trajectory == 'upward' ? Colors.green.withOpacity(0.15) :
                         trajectory == 'downward' ? Colors.red.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      trajectory == 'upward' ? Icons.trending_up :
                      trajectory == 'downward' ? Icons.trending_down : Icons.trending_flat,
                      color: trajectory == 'upward' ? Colors.green.shade300 :
                             trajectory == 'downward' ? Colors.red.shade300 : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trajectoryNote ?? 'Trajectory: ${trajectory ?? "stable"}',
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (keyStrengths.isNotEmpty) ...[
              const Text('Key Strengths:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 4),
              ...keyStrengths.map((s) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: Colors.green.shade300)),
                    Expanded(child: Text(s.toString(), style: const TextStyle(fontSize: 13, color: Colors.white70))),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],
            if (priorityGrowthAreas.isNotEmpty) ...[
              const Text('Priority Growth Areas:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 4),
              ...priorityGrowthAreas.map((g) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: Colors.orange.shade300)),
                    Expanded(child: Text(g.toString(), style: const TextStyle(fontSize: 13, color: Colors.white70))),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],
            if (recommendedFocus != null) ...[
              const Text('Recommended Focus:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Text(recommendedFocus, style: TextStyle(fontSize: 13, color: Colors.amber.shade200)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthDeepDiveCard(Map<String, dynamic> strength) {
    // Support AI-generated fields: area, summary, evidence, spiritual_maturity_indicator, how_to_leverage, celebration_talking_point
    final name = strength['area'] ?? strength['name'] ?? strength['strength'] ?? 'Strength';
    final description = strength['summary'] ?? strength['description'] as String?;
    final evidence = strength['evidence'] as List<dynamic>? ?? [];
    final howToLeverage = strength['how_to_leverage'] as String?;
    final spiritualIndicator = strength['spiritual_maturity_indicator'] as String?;
    final celebrationTalkingPoint = strength['celebration_talking_point'] as String?;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade400, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
              ...evidence.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• $e', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              )),
            ],
            if (howToLeverage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: Colors.green.shade300),
                    const SizedBox(width: 6),
                    Expanded(child: Text(howToLeverage, style: TextStyle(fontSize: 12, color: Colors.green.shade200))),
                  ],
                ),
              ),
            ],
            if (spiritualIndicator != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_stories, size: 16, color: Colors.purple.shade300),
                    const SizedBox(width: 6),
                    Expanded(child: Text(spiritualIndicator, style: TextStyle(fontSize: 12, color: Colors.purple.shade200, fontStyle: FontStyle.italic))),
                  ],
                ),
              ),
            ],
            if (celebrationTalkingPoint != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.celebration, size: 16, color: Colors.amber.shade300),
                    const SizedBox(width: 6),
                    Expanded(child: Text(celebrationTalkingPoint, style: TextStyle(fontSize: 12, color: Colors.amber.shade200))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGapDeepDiveCard(Map<String, dynamic> gap) {
    // Support AI-generated fields: area, summary, severity, root_cause_analysis, evidence, biblical_perspective, why_it_matters, growth_pathway
    final name = gap['area'] ?? gap['name'] ?? gap['gap'] ?? 'Growth Area';
    final description = gap['summary'] ?? gap['description'] as String?;
    final severity = gap['severity'] as String?;
    final rootCauseAnalysis = gap['root_cause_analysis'] as String?;
    final biblicalPerspective = gap['biblical_perspective'] as String?;
    final whyItMatters = gap['why_it_matters'] as String?;
    final evidence = gap['evidence'] as List<dynamic>? ?? [];
    final currentState = gap['current_state'] as String?;
    final growthPathway = gap['growth_pathway'] as Map<String, dynamic>? ?? gap['pathway'] as Map<String, dynamic>?;
    final resources = gap['resources'] as List<dynamic>? ?? [];

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.orange.shade300, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))),
                if (severity != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: severity == 'high' ? Colors.red.withOpacity(0.2) : 
                             severity == 'moderate' ? Colors.orange.withOpacity(0.2) : Colors.yellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      severity,
                      style: TextStyle(
                        fontSize: 10,
                        color: severity == 'high' ? Colors.red.shade300 :
                               severity == 'moderate' ? Colors.orange.shade300 : Colors.yellow.shade300,
                      ),
                    ),
                  ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
              ...evidence.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• $e', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              )),
            ],
            if (rootCauseAnalysis != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Root Cause Analysis:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(rootCauseAnalysis, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
            if (biblicalPerspective != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.menu_book, size: 16, color: Colors.purple.shade300),
                    const SizedBox(width: 6),
                    Expanded(child: Text(biblicalPerspective, style: TextStyle(fontSize: 12, color: Colors.purple.shade200))),
                  ],
                ),
              ),
            ],
            if (whyItMatters != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Why It Matters:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(whyItMatters, style: TextStyle(fontSize: 12, color: Colors.amber.shade200)),
                  ],
                ),
              ),
            ],
            if (currentState != null) ...[
              const SizedBox(height: 8),
              Text('Current State: $currentState', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70)),
            ],
            if (growthPathway != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Growth Pathway:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
                    const SizedBox(height: 4),
                    // Support both AI format (phase_1_weeks_1_4) and legacy format (immediate, short_term, long_term)
                    if (growthPathway['phase_1_weeks_1_4'] != null)
                      _buildPhaseSection('Weeks 1-4', growthPathway['phase_1_weeks_1_4'] as Map<String, dynamic>),
                    if (growthPathway['phase_2_weeks_5_8'] != null)
                      _buildPhaseSection('Weeks 5-8', growthPathway['phase_2_weeks_5_8'] as Map<String, dynamic>),
                    if (growthPathway['phase_3_weeks_9_12'] != null)
                      _buildPhaseSection('Weeks 9-12', growthPathway['phase_3_weeks_9_12'] as Map<String, dynamic>),
                    // Legacy format fallback
                    if (growthPathway['immediate'] != null)
                      Text('• Immediate: ${growthPathway['immediate']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (growthPathway['short_term'] != null)
                      Text('• Short-term: ${growthPathway['short_term']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (growthPathway['long_term'] != null)
                      Text('• Long-term: ${growthPathway['long_term']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
            if (resources.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Suggested Resources:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
              ...resources.take(3).map((r) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• $r', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              )),
            ],
          ],
        ),
      ),
    );
  }

  /// Build a phase section for growth pathway (e.g. "Weeks 1-4")
  Widget _buildPhaseSection(String phaseName, Map<String, dynamic> phase) {
    final goal = phase['goal'] as String?;
    final activities = phase['activities'] as List<dynamic>? ?? [];
    final successMetric = phase['success_metric'] as String?;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📅 $phaseName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
          if (goal != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text('Goal: $goal', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white70)),
            ),
          if (activities.isNotEmpty)
            ...activities.map((a) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text('• $a', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            )),
          if (successMetric != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text('✓ Success: $successMetric', style: TextStyle(fontSize: 11, color: Colors.green.shade300)),
            ),
        ],
      ),
    );
  }

  /// Build a session card for AI-generated conversation guide
  Widget _buildAiSessionCard(int sessionNum, Map<String, dynamic> session) {
    final theme = session['theme'] as String?;
    final duration = session['duration_minutes'];
    final openingQuestion = session['opening_question'] as String?;
    final keyPoints = session['key_points_to_cover'] as List<dynamic>? ?? [];
    final questions = session['questions_to_ask'] as List<dynamic>? ?? [];
    final closeWith = session['close_with'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border.all(color: Colors.blue.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blue.withOpacity(0.3),
                child: Text('$sessionNum', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade300)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  theme ?? 'Session $sessionNum',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
              ),
              if (duration != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$duration min', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ),
            ],
          ),
          if (openingQuestion != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.record_voice_over, size: 16, color: Colors.green.shade300),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '"$openingQuestion"',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.green.shade200),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (keyPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Key Points:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
            const SizedBox(height: 4),
            ...keyPoints.map((kp) {
              final point = kp is Map ? kp['point'] ?? kp['talking_point'] : kp;
              final talkingPoint = kp is Map ? kp['talking_point'] : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• $point', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (talkingPoint != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 2),
                        child: Text(
                          '💬 "$talkingPoint"',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade400),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
          if (questions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Questions to Ask:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
            const SizedBox(height: 4),
            ...questions.map((q) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text('❓ $q', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            )),
          ],
          if (closeWith != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.favorite, size: 14, color: Colors.purple.shade300),
                  const SizedBox(width: 6),
                  Expanded(child: Text(closeWith, style: TextStyle(fontSize: 11, color: Colors.purple.shade200))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationGuideSection(Map<String, dynamic> guide) {
    // Legacy format
    final sessions = guide['sessions'] as List<dynamic>? ?? [];
    final openingQuestions = guide['opening_questions'] as List<dynamic>? ?? [];
    final topics = guide['suggested_topics'] as List<dynamic>? ?? [];
    
    // AI format: session_1_opening, session_2_growth_areas, session_3_check_in
    final session1 = guide['session_1_opening'] as Map<String, dynamic>?;
    final session2 = guide['session_2_growth_areas'] as Map<String, dynamic>?;
    final session3 = guide['session_3_check_in'] as Map<String, dynamic>?;
    final hasAiSessions = session1 != null || session2 != null || session3 != null;

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI-format sessions
            if (hasAiSessions) ...[
              if (session1 != null) _buildAiSessionCard(1, session1),
              if (session2 != null) _buildAiSessionCard(2, session2),
              if (session3 != null) _buildAiSessionCard(3, session3),
            ],
            // Legacy format
            if (openingQuestions.isNotEmpty) ...[
              const Text('Opening Questions:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              ...openingQuestions.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $q', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              )),
              const SizedBox(height: 12),
            ],
            if (sessions.isNotEmpty) ...[
              const Text('Session Structure:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              ...sessions.asMap().entries.map((entry) {
                final session = entry.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.blue.withOpacity(0.3),
                        child: Text('${entry.key + 1}', style: TextStyle(fontSize: 11, color: Colors.blue.shade300)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(session['focus'] ?? 'Session ${entry.key + 1}',
                                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                            if (session['goal'] != null)
                              Text(session['goal'], style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (topics.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Topics to Explore:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: topics.map((t) => Chip(
                  label: Text(t.toString(), style: const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: Colors.blue.withOpacity(0.2),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBiblicalKnowledgeSection(Map<String, dynamic> knowledge) {
    // Legacy format
    final topicBreakdown = knowledge['topic_breakdown'] as List<dynamic>? ?? [];
    final weakAreas = knowledge['weak_areas'] as List<dynamic>? ?? [];
    final studyPlan = knowledge['study_plan'] as Map<String, dynamic>?;
    
    // AI format
    final overallPercent = knowledge['overall_percent'];
    final masteryLevel = knowledge['mastery_level'] as String?;
    final byTopicBreakdown = knowledge['by_topic_breakdown'] as List<dynamic>? ?? [];
    final theologicalHealthCheck = knowledge['theological_health_check'] as Map<String, dynamic>?;
    final readingPlan = knowledge['recommended_bible_reading_plan'] as Map<String, dynamic>?;
    
    // Use AI format if available, else legacy
    final topics = byTopicBreakdown.isNotEmpty ? byTopicBreakdown : topicBreakdown;

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI format: overall score
            if (overallPercent != null || masteryLevel != null) ...[
              Row(
                children: [
                  if (overallPercent != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$overallPercent%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade300),
                      ),
                    ),
                  if (masteryLevel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(masteryLevel, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (topics.isNotEmpty) ...[
              const Text('Topic Performance:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              ...topics.take(5).map((topic) {
                if (topic is Map) {
                  final name = topic['topic'] ?? topic['name'] ?? 'Topic';
                  // Support AI format (score_percent) and legacy (score, percent)
                  final score = topic['score_percent'] ?? topic['score'] ?? topic['percent'] ?? 0;
                  final level = topic['level'] as String?;
                  final keyGaps = topic['key_gaps'] as List<dynamic>? ?? [];
                  final affirmation = topic['affirmation'] as String?;
                  final studyPrescription = topic['study_prescription'] as String?;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(name.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white))),
                            Row(
                              children: [
                                Text('$score%', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                if (level != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: level == 'Strong' ? Colors.green.withOpacity(0.2) :
                                             level == 'Weak' ? Colors.red.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      level,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: level == 'Strong' ? Colors.green.shade300 :
                                               level == 'Weak' ? Colors.red.shade300 : Colors.orange.shade300,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (score as num) / 100,
                          backgroundColor: Colors.grey.shade800,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            score >= 70 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red),
                          ),
                        ),
                        if (affirmation != null) ...[
                          const SizedBox(height: 6),
                          Text('✓ $affirmation', style: TextStyle(fontSize: 11, color: Colors.green.shade300)),
                        ],
                        if (keyGaps.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Gaps: ${keyGaps.join(", ")}', style: TextStyle(fontSize: 11, color: Colors.red.shade300)),
                        ],
                        if (studyPrescription != null) ...[
                          const SizedBox(height: 6),
                          Text('📚 $studyPrescription', style: TextStyle(fontSize: 11, color: Colors.blue.shade300)),
                        ],
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
            // Theological health check (AI format)
            if (theologicalHealthCheck != null) ...[
              const SizedBox(height: 12),
              const Text('Theological Health Check:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              if ((theologicalHealthCheck['core_doctrines_solid'] as List?)?.isNotEmpty ?? false) ...[
                Text('✓ Solid: ${(theologicalHealthCheck['core_doctrines_solid'] as List).join(", ")}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade300)),
                const SizedBox(height: 4),
              ],
              if ((theologicalHealthCheck['areas_needing_clarification'] as List?)?.isNotEmpty ?? false) ...[
                Text('⚠ Needs clarification: ${(theologicalHealthCheck['areas_needing_clarification'] as List).join(", ")}',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade300)),
              ],
            ],
            // Bible reading plan (AI format)
            if (readingPlan != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book, size: 18, color: Colors.purple.shade300),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Recommended: ${readingPlan['name'] ?? "Bible Reading Plan"}',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade200)),
                        ),
                      ],
                    ),
                    if (readingPlan['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(readingPlan['description'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                    if (readingPlan['why_this_plan'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Why: ${readingPlan['why_this_plan']}', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade400)),
                    ],
                  ],
                ),
              ),
            ],
            if (weakAreas.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Areas to Strengthen:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              ...weakAreas.take(3).map((area) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade300),
                    const SizedBox(width: 8),
                    Expanded(child: Text(area.toString(), style: const TextStyle(fontSize: 13, color: Colors.white70))),
                  ],
                ),
              )),
            ],
            if (studyPlan != null) ...[
              const SizedBox(height: 12),
              const Text('Recommended Study Plan:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: studyPlan.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${e.key}: ${e.value}', style: TextStyle(fontSize: 12, color: Colors.indigo.shade200)),
                  )).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpiritualFormationCard(Map<String, dynamic> insight) {
    // Support AI format and legacy format
    final area = insight['category'] ?? insight['area'] ?? 'Spiritual Life';
    final currentLevel = insight['current_level'] as String?;
    final detailedObservation = insight['detailed_observation'] ?? insight['observation'] as String?;
    final maturityPresent = insight['maturity_markers_present'] as List<dynamic>? ?? [];
    final maturityMissing = insight['maturity_markers_missing'] as List<dynamic>? ?? [];
    final customPlan = insight['custom_development_plan'] as Map<String, dynamic>?;
    final mentorQuestions = insight['mentor_discussion_questions'] as List<dynamic>? ?? [];
    final suggestions = insight['suggestions'] as List<dynamic>? ?? [];

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa, color: Colors.purple.shade300, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(area.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))),
                if (currentLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(currentLevel, style: TextStyle(fontSize: 11, color: Colors.purple.shade300)),
                  ),
              ],
            ),
            if (detailedObservation != null) ...[
              const SizedBox(height: 8),
              Text(detailedObservation, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
            // Maturity markers
            if (maturityPresent.isNotEmpty || maturityMissing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (maturityPresent.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✓ Present', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green.shade300)),
                          ...maturityPresent.map((m) => Text('  • $m', style: const TextStyle(fontSize: 11, color: Colors.white70))),
                        ],
                      ),
                    ),
                  if (maturityMissing.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('○ Missing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange.shade300)),
                          ...maturityMissing.map((m) => Text('  • $m', style: const TextStyle(fontSize: 11, color: Colors.white70))),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            // Custom development plan
            if (customPlan != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Development Plan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
                    if (customPlan['immediate_30_days'] != null)
                      Text('📅 30 days: ${customPlan['immediate_30_days']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    if (customPlan['quarter_goal'] != null)
                      Text('📅 Quarter: ${customPlan['quarter_goal']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    if (customPlan['year_vision'] != null)
                      Text('📅 Year: ${customPlan['year_vision']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ],
            // Mentor discussion questions
            if (mentorQuestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Questions to Ask:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
              ...mentorQuestions.map((q) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text('❓ $q', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              )),
            ],
            // Legacy suggestions
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Suggestions:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
              ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• $s', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              )),
            ],
          ],
        ),
      ),
    );
  }

  String _prettyPrintJson(Map<String, dynamic> json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  Widget _notesTab() {
    if (_notesLoading) {
      return Center(child: CircularProgressIndicator(color: troothGold));
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_add_outlined, color: Colors.grey[600], size: 64),
            const SizedBox(height: 16),
            Text('No notes yet', style: TextStyle(color: Colors.grey[500], fontSize: 18)),
            const SizedBox(height: 8),
            Text('Tap the + button to add your first note', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      color: troothGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MentorNoteCard(
              note: note,
              onEdit: () => _editNote(note),
              onDelete: () => _deleteNote(note),
              currentUserId: FirebaseAuth.instance.currentUser?.uid,
            ),
          );
        },
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

/// PDF Preview screen with share functionality
class _PdfPreviewScreen extends StatelessWidget {
  final String filePath;
  final String fileName;
  final String apprenticeName;

  const _PdfPreviewScreen({
    required this.filePath,
    required this.fileName,
    required this.apprenticeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Report Preview', style: TextStyle(color: Colors.amber.shade300)),
        iconTheme: IconThemeData(color: Colors.amber.shade300),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => _shareFile(context),
            tooltip: 'Share',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.picture_as_pdf, size: 80, color: Colors.red.shade400),
              ),
              const SizedBox(height: 24),
              Text(
                'T[root]H Mentor Report',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                apprenticeName,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                fileName,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'PDF ready for export',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap "Share" to save to Files, Notes, iCloud Drive, send via AirDrop, or open in another app.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareFile(context),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share PDF', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openInExternalApp(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in Another App'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.grey.shade600),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null 
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        subject: 'T[root]H Report - $apprenticeName',
        text: 'Mentor Report for $apprenticeName',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share error: $e')));
    }
  }

  Future<void> _openInExternalApp(BuildContext context) async {
    // Use share sheet which allows "Open in..." on iOS
    try {
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null 
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        subject: 'T[root]H Report - $apprenticeName',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

/// Full-screen premium report viewer
class _PremiumReportFullScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  final String apprenticeName;
  final bool cached;

  const _PremiumReportFullScreen({
    required this.report,
    required this.apprenticeName,
    this.cached = false,
  });

  @override
  Widget build(BuildContext context) {
    final strengthsDeepDive = report['strengths_deep_dive'] as List<dynamic>?;
    final gapsDeepDive = report['gaps_deep_dive'] as List<dynamic>?;
    final execSummary = report['executive_summary'] as Map<String, dynamic>?;
    final conversationGuide = report['conversation_guide'] as Map<String, dynamic>?;
    final biblicalKnowledge = report['biblical_knowledge_analysis'] as Map<String, dynamic>?;
    final spiritualFormation = report['spiritual_formation_insights'] as List<dynamic>?;
    final meta = report['_meta'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Premium Report · $apprenticeName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Premium badge header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.amber.shade100, Colors.amber.shade50]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Premium Report', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                      Row(
                        children: [
                          if (cached) ...[
                            Icon(Icons.cached, size: 12, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Text('Instant load', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                          ],
                          if (meta != null) ...[
                            if (cached) Text(' • ', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                            Text('Generated by ${meta['model'] ?? 'AI'}', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Executive Summary
          if (execSummary != null) ...[
            _sectionHeader('Executive Summary', Icons.summarize),
            const SizedBox(height: 12),
            _buildExecutiveSummaryCard(execSummary),
            const SizedBox(height: 20),
          ],

          // Strengths Deep Dive
          if (strengthsDeepDive != null && strengthsDeepDive.isNotEmpty) ...[
            _sectionHeader('Strengths Deep Dive', Icons.thumb_up),
            const SizedBox(height: 12),
            ...strengthsDeepDive.map((s) => _buildStrengthCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Growth Opportunities
          if (gapsDeepDive != null && gapsDeepDive.isNotEmpty) ...[
            _sectionHeader('Growth Opportunities', Icons.trending_up),
            const SizedBox(height: 12),
            ...gapsDeepDive.map((g) => _buildGapCard(g as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Conversation Guide
          if (conversationGuide != null) ...[
            _sectionHeader('Conversation Guide', Icons.chat),
            const SizedBox(height: 12),
            _buildConversationGuideCard(conversationGuide),
            const SizedBox(height: 20),
          ],

          // Biblical Knowledge
          if (biblicalKnowledge != null) ...[
            _sectionHeader('Biblical Knowledge', Icons.menu_book),
            const SizedBox(height: 12),
            _buildBiblicalKnowledgeCard(biblicalKnowledge),
            const SizedBox(height: 20),
          ],

          // Spiritual Formation
          if (spiritualFormation != null && spiritualFormation.isNotEmpty) ...[
            _sectionHeader('Spiritual Formation', Icons.self_improvement),
            const SizedBox(height: 12),
            ...spiritualFormation.map((s) => _buildFormationCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.amber),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildExecutiveSummaryCard(Map<String, dynamic> summary) {
    final healthScore = summary['health_score'];
    final healthBand = summary['health_band'] as String?;
    final oneLiner = summary['one_liner'] as String?;
    final trajectory = summary['trajectory'] as String?;
    final trajectoryNote = summary['trajectory_note'] as String?;

    Color trajectoryColor = Colors.grey;
    IconData trajectoryIcon = Icons.trending_flat;
    if (trajectory == 'upward') {
      trajectoryColor = Colors.green;
      trajectoryIcon = Icons.trending_up;
    } else if (trajectory == 'downward') {
      trajectoryColor = Colors.red;
      trajectoryIcon = Icons.trending_down;
    }

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (healthScore != null) ...[
              Row(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.withOpacity(0.2),
                      border: Border.all(color: Colors.amber, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Text('$healthScore', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (healthBand != null) Text(healthBand, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (trajectory != null)
                          Row(children: [
                            Icon(trajectoryIcon, size: 16, color: trajectoryColor),
                            const SizedBox(width: 4),
                            Text(trajectory.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: trajectoryColor)),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (oneLiner != null) ...[
              Text(oneLiner, style: const TextStyle(fontSize: 15, color: Colors.white, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
            ],
            if (trajectoryNote != null && trajectoryNote.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: trajectoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: trajectoryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights, size: 18, color: trajectoryColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(trajectoryNote, style: const TextStyle(fontSize: 13, color: Colors.white70))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthCard(Map<String, dynamic> strength) {
    final area = strength['area'] as String? ?? 'Strength';
    final summary = strength['summary'] as String?;
    final evidence = (strength['evidence'] as List<dynamic>?)?.cast<String>() ?? [];
    final howToLeverage = strength['how_to_leverage'] as String?;
    final spiritualIndicator = strength['spiritual_maturity_indicator'] as String?;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(area, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
            ]),
            if (summary != null) ...[const SizedBox(height: 8), Text(summary, style: const TextStyle(color: Colors.white70))],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              ...evidence.map((e) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $e', style: const TextStyle(color: Colors.white70, fontSize: 13)))),
            ],
            if (howToLeverage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(howToLeverage, style: TextStyle(color: Colors.amber.shade200, fontSize: 13))),
                ]),
              ),
            ],
            if (spiritualIndicator != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.menu_book, color: Colors.purple.shade300, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(spiritualIndicator, style: TextStyle(color: Colors.purple.shade200, fontSize: 13, fontStyle: FontStyle.italic))),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGapCard(Map<String, dynamic> gap) {
    final area = gap['area'] as String? ?? 'Growth Area';
    final summary = gap['summary'] as String?;
    final severity = gap['severity'] as String?;
    final rootCause = gap['root_cause_analysis'] as String?;
    final biblicalPerspective = gap['biblical_perspective'] as String?;
    final growthPathway = gap['growth_pathway'] as Map<String, dynamic>?;

    Color severityColor = Colors.orange;
    if (severity == 'critical') severityColor = Colors.red;
    else if (severity == 'minor') severityColor = Colors.yellow;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.trending_up, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(area, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
              if (severity != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: severityColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text(severity.toUpperCase(), style: TextStyle(color: severityColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ]),
            if (summary != null) ...[const SizedBox(height: 8), Text(summary, style: const TextStyle(color: Colors.white70))],
            if (rootCause != null) ...[
              const SizedBox(height: 12),
              const Text('Root Cause:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              const SizedBox(height: 4),
              Text(rootCause, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
            if (biblicalPerspective != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.menu_book, color: Colors.purple.shade300, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(biblicalPerspective, style: TextStyle(color: Colors.purple.shade200, fontSize: 13, fontStyle: FontStyle.italic))),
                ]),
              ),
            ],
            if (growthPathway != null) ...[
              const SizedBox(height: 12),
              const Text('Growth Pathway:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              ...growthPathway.entries.map((phase) {
                final phaseData = phase.value as Map<String, dynamic>?;
                if (phaseData == null) return const SizedBox.shrink();
                final goal = phaseData['goal'] as String?;
                final activities = (phaseData['activities'] as List<dynamic>?)?.cast<String>() ?? [];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(phase.key.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade300, fontSize: 11)),
                      if (goal != null) ...[const SizedBox(height: 4), Text(goal, style: const TextStyle(color: Colors.white, fontSize: 13))],
                      if (activities.isNotEmpty) ...activities.map((a) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $a', style: const TextStyle(color: Colors.white70, fontSize: 12)))),
                    ]),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationGuideCard(Map<String, dynamic> guide) {
    // Premium format: session_1_opening, session_2_growth_areas, session_3_check_in
    final sessionKeys = [
      ('session_1_opening', 'Session 1: Opening'),
      ('session_2_growth_areas', 'Session 2: Growth Areas'),
      ('session_3_check_in', 'Session 3: Check-In'),
    ];
    
    final sessionWidgets = <Widget>[];
    for (final (key, title) in sessionKeys) {
      final session = guide[key] as Map<String, dynamic>?;
      if (session == null) continue;
      
      final theme = session['theme'] as String?;
      final duration = session['duration_minutes'];
      final openingQuestion = session['opening_question'] as String?;
      final keyPoints = session['key_points_to_cover'] as List<dynamic>?;
      final questions = session['questions_to_ask'] as List<dynamic>?;
      final closeWith = session['close_with'] as String?;
      
      sessionWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade300, fontSize: 15))),
                if (duration != null) Text('$duration min', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ]),
              if (theme != null) ...[
                const SizedBox(height: 4),
                Text(theme, style: TextStyle(color: Colors.blue.shade200, fontStyle: FontStyle.italic, fontSize: 13)),
              ],
              if (openingQuestion != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.chat_bubble_outline, size: 16, color: Colors.blue.shade200),
                    const SizedBox(width: 8),
                    Expanded(child: Text('"$openingQuestion"', style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 13))),
                  ]),
                ),
              ],
              if (keyPoints != null && keyPoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Key Points:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12)),
                const SizedBox(height: 6),
                ...keyPoints.take(3).map((kp) {
                  final point = kp is Map ? kp['point'] as String? ?? '' : kp.toString();
                  final talkingPoint = kp is Map ? kp['talking_point'] as String? : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('• ', style: TextStyle(color: Colors.blue.shade300)),
                        Expanded(child: Text(point, style: const TextStyle(color: Colors.white, fontSize: 13))),
                      ]),
                      if (talkingPoint != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 2),
                          child: Text('"$talkingPoint"', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                    ]),
                  );
                }),
              ],
              if (questions != null && questions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Questions to Ask:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12)),
                const SizedBox(height: 6),
                ...questions.take(3).map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('? ', style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(q.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  ]),
                )),
              ],
              if (closeWith != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.favorite, size: 16, color: Colors.green.shade300),
                    const SizedBox(width: 8),
                    Expanded(child: Text(closeWith, style: TextStyle(color: Colors.green.shade200, fontSize: 12))),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      );
    }
    
    // Fallback for legacy format or if no sessions found
    if (sessionWidgets.isEmpty) {
      final sessions = guide['sessions'] as List<dynamic>? ?? [];
      final topics = guide['key_topics'] as List<dynamic>? ?? [];
      
      return Card(
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sessions.isNotEmpty)
                ...sessions.asMap().entries.map((entry) {
                  final session = entry.value as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Session ${entry.key + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade300)),
                        if (session['goal'] != null) ...[const SizedBox(height: 4), Text(session['goal'].toString(), style: const TextStyle(color: Colors.white70))],
                        if (session['questions'] != null) ...[
                          const SizedBox(height: 8),
                          ...(session['questions'] as List).map((q) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $q', style: const TextStyle(color: Colors.white, fontSize: 13)))),
                        ],
                      ]),
                    ),
                  );
                }),
              if (topics.isNotEmpty) ...[
                const Text('Topics to Explore:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: topics.map((t) => Chip(label: Text(t.toString(), style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.blue.withOpacity(0.2))).toList()),
              ],
              if (sessions.isEmpty && topics.isEmpty)
                const Text('No conversation guide available', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sessionWidgets,
        ),
      ),
    );
  }

  Widget _buildBiblicalKnowledgeCard(Map<String, dynamic> knowledge) {
    final overallPercent = knowledge['overall_percent'];
    final masteryLevel = knowledge['mastery_level'] as String?;
    final byTopicBreakdown = knowledge['by_topic_breakdown'] as List<dynamic>? ?? [];

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overallPercent != null || masteryLevel != null)
              Row(children: [
                if (overallPercent != null) Text('$overallPercent%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
                if (overallPercent != null && masteryLevel != null) const SizedBox(width: 12),
                if (masteryLevel != null) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(masteryLevel, style: const TextStyle(color: Colors.amber))),
              ]),
            if (byTopicBreakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...byTopicBreakdown.map((topic) {
                final t = topic as Map<String, dynamic>;
                final topicName = t['topic'] as String? ?? 'Topic';
                final scorePercent = t['score_percent'];
                final level = t['level'] as String?;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text(topicName, style: const TextStyle(color: Colors.white))),
                    if (scorePercent != null) Expanded(child: Text('$scorePercent%', style: TextStyle(color: Colors.grey[400]))),
                    if (level != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _levelColor(level).withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(level, style: TextStyle(color: _levelColor(level), fontSize: 11))),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'strong': return Colors.green;
      case 'moderate': return Colors.amber;
      case 'weak': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildFormationCard(Map<String, dynamic> formation) {
    // Premium format: category, current_level, detailed_observation, maturity_markers_present/missing, custom_development_plan, mentor_discussion_questions
    final area = formation['category'] as String? ?? formation['area'] as String? ?? 'Insight';
    final level = formation['current_level'] as String? ?? formation['level'] as String?;
    final observation = formation['detailed_observation'] as String? ?? formation['observation'] as String? ?? formation['summary'] as String?;
    final markersPresent = formation['maturity_markers_present'] as List<dynamic>?;
    final markersMissing = formation['maturity_markers_missing'] as List<dynamic>?;
    final customPlan = formation['custom_development_plan'] as Map<String, dynamic>?;
    final mentorQuestions = formation['mentor_discussion_questions'] as List<dynamic>?;
    // Legacy fallback
    final recommendation = formation['recommendation'] as String?;
    final mentorMoves = formation['mentor_moves'] as List<dynamic>?;

    Color levelColor = Colors.grey;
    if (level != null) {
      switch (level.toLowerCase()) {
        case 'flourishing':
        case 'mature':
          levelColor = Colors.green;
          break;
        case 'maturing':
        case 'good':
          levelColor = Colors.lightGreen;
          break;
        case 'stable':
          levelColor = Colors.blue;
          break;
        case 'developing':
        case 'growing':
          levelColor = Colors.orange;
          break;
        case 'beginning':
          levelColor = Colors.red;
          break;
      }
    }

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with area and level
            Row(children: [
              Expanded(child: Text(area, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
              if (level != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: levelColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(level, style: TextStyle(color: levelColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
            
            // Observation
            if (observation != null && observation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(observation, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
            ],
            
            // Maturity markers
            if ((markersPresent != null && markersPresent.isNotEmpty) || (markersMissing != null && markersMissing.isNotEmpty)) ...[
              const SizedBox(height: 12),
              if (markersPresent != null && markersPresent.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: markersPresent.take(4).map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade300),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m.toString(), style: TextStyle(color: Colors.green.shade300, fontSize: 12))),
                      ]),
                    ),
                  )).toList(),
                ),
              if (markersMissing != null && markersMissing.isNotEmpty) ...[
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: markersMissing.take(4).map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.radio_button_unchecked, size: 14, color: Colors.orange.shade300),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m.toString(), style: TextStyle(color: Colors.orange.shade300, fontSize: 12))),
                      ]),
                    ),
                  )).toList(),
                ),
              ],
            ],
            
            // Custom development plan
            if (customPlan != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.route, size: 16, color: Colors.purple.shade300),
                    const SizedBox(width: 6),
                    Text('Development Plan', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade200, fontSize: 13)),
                  ]),
                  if (customPlan['immediate_30_days'] != null) ...[
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('30 days: ', style: TextStyle(color: Colors.purple.shade300, fontWeight: FontWeight.w500, fontSize: 12)),
                      Expanded(child: Text(customPlan['immediate_30_days'].toString(), style: TextStyle(color: Colors.purple.shade100, fontSize: 12))),
                    ]),
                  ],
                  if (customPlan['quarter_goal'] != null) ...[
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Quarter: ', style: TextStyle(color: Colors.purple.shade300, fontWeight: FontWeight.w500, fontSize: 12)),
                      Expanded(child: Text(customPlan['quarter_goal'].toString(), style: TextStyle(color: Colors.purple.shade100, fontSize: 12))),
                    ]),
                  ],
                  if (customPlan['year_vision'] != null) ...[
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Year: ', style: TextStyle(color: Colors.purple.shade300, fontWeight: FontWeight.w500, fontSize: 12)),
                      Expanded(child: Text(customPlan['year_vision'].toString(), style: TextStyle(color: Colors.purple.shade100, fontSize: 12))),
                    ]),
                  ],
                ]),
              ),
            ],
            
            // Mentor discussion questions
            if (mentorQuestions != null && mentorQuestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Questions to Ask:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              const SizedBox(height: 8),
              ...mentorQuestions.take(3).map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('? ', style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(q.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13))),
                ]),
              )),
            ],
            
            // Legacy fallback: recommendation or mentor_moves
            if (recommendation != null && recommendation.isNotEmpty && customPlan == null && mentorQuestions == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(recommendation, style: TextStyle(color: Colors.amber.shade200, fontSize: 13))),
                ]),
              ),
            ],
            if (mentorMoves != null && mentorMoves.isNotEmpty && mentorQuestions == null) ...[
              const SizedBox(height: 12),
              const Text('Next Steps:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              const SizedBox(height: 6),
              ...mentorMoves.take(3).map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('→ ', style: TextStyle(color: Colors.amber.shade300)),
                  Expanded(child: Text(m.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13))),
                ]),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
