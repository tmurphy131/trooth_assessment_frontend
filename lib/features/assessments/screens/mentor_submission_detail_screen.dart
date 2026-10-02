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
// import '../widgets/bar_row.dart';
// import '../widgets/level_badge.dart';
import '../widgets/insight_card.dart';
import 'mentor_report_simplified_screen.dart';
import '../../../screens/subscription_screen.dart';
import '../../../utils/errors.dart';

part 'mentor_submission_detail_screen_widgets.dart';
part 'mentor_submission_premium_report.dart';

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
            SnackBar(content: Text('Failed to add note: ${friendlyError(e)}'), backgroundColor: Colors.red),
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
            SnackBar(content: Text('Failed to update note: ${friendlyError(e)}'), backgroundColor: Colors.red),
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
            SnackBar(content: Text('Failed to delete note: ${friendlyError(e)}'), backgroundColor: Colors.red),
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
      setState(() { _error = 'Failed to load: ${friendlyError(e)}'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).maybePop()),
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

  Future<void> _emailReport() async {
    try {
      final to = _mentorEmail;
      if (to == null || to.isEmpty) {
        if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No mentor email found.')));
        return;
      }
      final res = await ApiService().emailMentorReportByAssessment(assessmentId: widget.assessmentId, toEmail: to, includePdf: true);
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email sent for assessment ${res['assessment_id']}')));
    } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email failed: ${friendlyError(e)}'))); }
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
                    color: Colors.blue.withValues(alpha: 0.2),
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
                    color: Colors.purple.withValues(alpha: 0.2),
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
                    color: Colors.amber.withValues(alpha: 0.2),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${friendlyError(e)}')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${friendlyError(e)}')));
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

  // Expandable section state
  bool _showBiblicalKnowledge = false;
  bool _showInsights = false;
  bool _showPlan = false;

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
            children: bk.topicBreakdown.map((t) => ListTile(
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
                if (bk.percent != null) ...[
                  Row(children: [
                    Text('${bk.percent!.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
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
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
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

}

class _Badge extends StatelessWidget { final String text; const _Badge({required this.text}); @override Widget build(BuildContext context) { return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(text, style: const TextStyle(color: Colors.green))); }}
