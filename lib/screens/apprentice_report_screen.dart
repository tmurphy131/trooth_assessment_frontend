import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../models/mentor_note.dart';
import '../theme.dart';
import 'subscription_screen.dart';
import '../utils/errors.dart';

part 'apprentice_report_screen_widgets.dart';
part 'apprentice_report_premium_widgets.dart';

/// Screen for apprentices to view their own assessment report.
/// Uses simplified report for free users, full AI report for premium users.
class ApprenticeReportScreen extends StatefulWidget {
  final String assessmentId;
  final String? title;
  
  const ApprenticeReportScreen({
    super.key,
    required this.assessmentId,
    this.title,
  });

  @override
  State<ApprenticeReportScreen> createState() => _ApprenticeReportScreenState();
}

class _ApprenticeReportScreenState extends State<ApprenticeReportScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;
  List<MentorNote> _sharedNotes = [];

  // Premium state — determined by whether the full report API succeeds (200) or rejects (403)
  bool _isPremium = false;
  bool _checkingPremium = true;
  bool _showPremiumUpsell = false;
  Map<String, dynamic>? _fullReport;
  bool _fullReportCached = false;

  // Processing/generating state
  bool _isProcessing = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkStatusThenLoad();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatusThenLoad() async {
    try {
      final status = await _api.getAssessmentStatus(widget.assessmentId);
      final isProcessing = status['status'] == 'processing' || !( status['has_scores'] as bool? ?? false);
      if (!mounted) return;
      if (isProcessing) {
        setState(() { _isProcessing = true; _loading = false; _checkingPremium = false; });
        _startPolling();
        return;
      }
    } catch (_) {
      // If status check fails, proceed with normal load
    }
    _loadReport();
    _checkPremiumAndLoadFullReport();
  }

  // ~5 minutes at 10s intervals. Scoring that takes longer has likely failed.
  static const _maxPollAttempts = 30;

  void _startPolling() {
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      attempts++;
      if (attempts > _maxPollAttempts) {
        _pollTimer?.cancel();
        if (!mounted) return;
        // Fall through to a normal load so the screen shows its own error
        // state (and retry) instead of spinning forever.
        setState(() { _isProcessing = false; _loading = true; _checkingPremium = true; });
        _loadReport();
        _checkPremiumAndLoadFullReport();
        return;
      }
      try {
        final status = await _api.getAssessmentStatus(widget.assessmentId);
        final done = status['status'] == 'done' || (status['has_scores'] as bool? ?? false);
        if (done && mounted) {
          _pollTimer?.cancel();
          setState(() { _isProcessing = false; _loading = true; _checkingPremium = true; });
          _loadReport();
          _checkPremiumAndLoadFullReport();
        }
      } catch (_) {}
    });
  }

  Future<void> _checkPremiumAndLoadFullReport() async {
    try {
      final response = await _api.fetchOwnFullReport(assessmentId: widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _isPremium = true;
        _showPremiumUpsell = false;
        _checkingPremium = false;
        _fullReport = response['report'] as Map<String, dynamic>?;
        _fullReportCached = response['cached'] as bool? ?? false;
      });
      dev.log('[ApprenticeReport] Full report loaded');
    } catch (e) {
      dev.log('[ApprenticeReport] Full report unavailable: $e');
      if (!mounted) return;
      final is403 = e.toString().contains('403') || e.toString().toLowerCase().contains('premium');
      setState(() {
        _isPremium = false;
        _checkingPremium = false;
        _showPremiumUpsell = is403;
      });
    }
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final report = await _api.getMySimplifiedReport(widget.assessmentId);
      // Also load shared notes from mentor
      List<MentorNote> notes = [];
      try {
        notes = await _api.getSharedNotesForAssessment(widget.assessmentId);
      } catch (_) {
        // Shared notes are optional, don't fail if not available
      }
      if (mounted) {
        setState(() {
          _report = report;
          _sharedNotes = notes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Failed to load report: ${friendlyError(e)}'; _loading = false; });
      }
    }
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
      
      // Use the apprentice full-report PDF endpoint
      final r = await _api.downloadMyReportPdf(assessmentId: widget.assessmentId);
      if (r.statusCode == 200) {
        // Save to documents directory for sharing (iOS requires this for share sheet)
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'TroothReport_${widget.assessmentId.substring(0, 8)}.pdf';
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
          subject: 'My T[root]H Assessment Report',
          text: 'My spiritual assessment report',
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

  /// Email report to user's email
  Future<void> _emailReport() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sending email...'), duration: Duration(seconds: 1)),
      );
      
      final success = await _api.emailMyMasterTroothReport(assessmentId: widget.assessmentId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent to your email!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send email')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email error: ${friendlyError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? _report?['template_name'] ?? 'Assessment Report';
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(tooltip: 'Back', 
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.amber),
            onPressed: _showExportOptions,
            tooltip: 'Export Report',
          ),
          IconButton(tooltip: 'Refresh', 
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: () {
              _loadReport();
              _checkPremiumAndLoadFullReport();
            },
          ),
        ],
      ),
      body: _isProcessing
          ? _generatingView()
          : _loading || _checkingPremium
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : _error != null
                  ? _errorView()
                  : _isPremium && _fullReport != null
                      ? _premiumContentView()
                      : _contentView(),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.amber;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _formatNoteDate(DateTime timestamp) {
    final d = timestamp.toLocal();
    final hour = d.hour;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${d.month}/${d.day}/${d.year} at $hour12:$minute $period';
  }

  Color _getBandColor(String band) {
    switch (band.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'maturing':
        return Colors.blue;
      case 'growing':
        return Colors.amber;
      case 'developing':
        return Colors.orange;
      case 'beginning':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getBandIcon(String band) {
    switch (band.toLowerCase()) {
      case 'excellent':
        return Icons.emoji_events;
      case 'maturing':
        return Icons.trending_up;
      case 'growing':
        return Icons.eco;
      case 'developing':
        return Icons.spa;
      case 'beginning':
        return Icons.grass;
      default:
        return Icons.help_outline;
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'strong':
        return Colors.green;
      case 'moderate':
        return Colors.amber;
      case 'developing':
        return Colors.orange;
      case 'beginning':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
