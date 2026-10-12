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
import '../features/assessments/data/report_status_poller.dart';
import '../features/assessments/models/report_status.dart';
import '../features/assessments/widgets/report_status_views.dart';

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

  // Premium state — determined by the full report API (ready / generating / unavailable / 403)
  bool _isPremium = false;
  bool _checkingPremium = false;
  bool _showPremiumUpsell = false;
  Map<String, dynamic>? _fullReport;
  bool _fullReportCached = false;
  PremiumReportKind? _premiumState; // generating or unavailable while the Premium report isn't ready
  bool _premiumCapped = false;
  bool _premiumHint = false; // subscription status, only used to show the loading card early
  ReportStatusPoller<PremiumReportResult>? _premiumPoller;
  Timer? _premiumWaitTimer;

  // Report status (specs/003-report-status-states): null until the first check returns
  ReportStatus? _status;
  ReportStatusPoller<ReportStatus>? _poller;
  bool _checking = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _checkStatus();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _premiumPoller?.cancel();
    _premiumWaitTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _isDone => _status?.phase == ReportPhase.done;

  void _onResume() {
    if (!_isDone) _checkNow();
  }

  /// First status check. A failure never falls back to the stored placeholder report: the
  /// screen shows the preparing view and keeps checking.
  Future<void> _checkStatus() async {
    try {
      final status = await _api.getReportStatus(widget.assessmentId);
      if (!mounted) return;
      _applyStatus(status);
    } catch (e) {
      if (!mounted) return;
      _applyStatus(const ReportStatus(ReportPhase.preparing));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't check your report: ${friendlyError(e)}")),
      );
    }
  }

  /// "Check again" and app resume: one immediate check.
  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final status = await _api.getReportStatus(widget.assessmentId);
      if (!mounted) return;
      _applyStatus(status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't check your report: ${friendlyError(e)}")),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _applyStatus(ReportStatus status) {
    final wasDone = _isDone;
    switch (status.phase) {
      case ReportPhase.done:
        _poller?.cancel();
        setState(() => _status = status);
        if (!wasDone) {
          _loadReport();
          _checkPremiumAndLoadFullReport();
        }
      case ReportPhase.preparing:
        setState(() { _status = status; _loading = false; });
        _startPolling();
      case ReportPhase.delayed:
        _poller?.cancel();
        setState(() { _status = status; _loading = false; });
    }
  }

  void _startPolling() {
    if (_poller?.isRunning ?? false) return;
    _poller = ReportStatusPoller<ReportStatus>(
      check: () => _api.getReportStatus(widget.assessmentId),
      onResult: (status) {
        if (mounted) _applyStatus(status);
      },
      onError: (e) => dev.log('[ApprenticeReport] status check failed: $e'),
      onCapped: () {
        if (mounted) setState(() {});
      },
    )..start();
  }

  void _refresh() {
    if (_isDone) {
      _loadReport();
      _checkPremiumAndLoadFullReport();
    } else {
      _checkNow();
    }
  }

  Future<void> _checkPremiumAndLoadFullReport() async {
    _premiumPoller?.cancel();
    setState(() { _checkingPremium = true; _premiumCapped = false; });
    _api.isPremiumUser().then((value) => _premiumHint = value).catchError((_) => false);
    // The server can hold a "generating" request for up to 90 s; don't keep the free report
    // behind a spinner that long.
    _premiumWaitTimer?.cancel();
    _premiumWaitTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_checkingPremium) return;
      setState(() {
        _checkingPremium = false;
        if (_premiumHint) _premiumState = PremiumReportKind.generating;
      });
    });
    try {
      final result = await _api.fetchOwnPremiumReport(assessmentId: widget.assessmentId);
      if (!mounted) return;
      _applyPremium(result);
      if (result.kind == PremiumReportKind.generating) _startPremiumPolling();
    } catch (e) {
      dev.log('[ApprenticeReport] Full report unavailable: $e');
      if (!mounted) return;
      setState(() {
        _isPremium = false;
        _checkingPremium = false;
        _showPremiumUpsell = false;
        _premiumState = null;
      });
    }
  }

  void _applyPremium(PremiumReportResult result) {
    if (result.kind != PremiumReportKind.generating) _premiumPoller?.cancel();
    setState(() {
      _checkingPremium = false;
      switch (result.kind) {
        case PremiumReportKind.ready:
          _isPremium = true;
          _showPremiumUpsell = false;
          _fullReport = result.report;
          _fullReportCached = result.cached;
          _premiumState = null;
        case PremiumReportKind.generating:
        case PremiumReportKind.unavailable:
          _isPremium = true;
          _showPremiumUpsell = false;
          _premiumState = result.kind;
        case PremiumReportKind.premiumRequired:
          _isPremium = false;
          _showPremiumUpsell = true;
          _premiumState = null;
      }
    });
  }

  void _startPremiumPolling() {
    if (_premiumPoller?.isRunning ?? false) return;
    _premiumPoller = ReportStatusPoller<PremiumReportResult>.fixed(
      every: const Duration(seconds: 10),
      cap: const Duration(minutes: 5),
      check: () => _api.fetchOwnPremiumReport(assessmentId: widget.assessmentId),
      onResult: (result) {
        if (mounted) _applyPremium(result);
      },
      onError: (e) => dev.log('[ApprenticeReport] Premium check failed: $e'),
      onCapped: () {
        if (mounted) setState(() => _premiumCapped = true);
      },
    )..start();
  }

  void _retryPremium() {
    setState(() { _premiumState = PremiumReportKind.generating; _premiumCapped = false; });
    _checkPremiumAndLoadFullReport();
  }

  /// Premium placeholder card for the free report view, or null when there's nothing to show.
  Widget? _premiumStatusCard() {
    if (_premiumState == PremiumReportKind.unavailable) {
      return PremiumStatusCard.unavailable(onTryAgain: _retryPremium);
    }
    if (_premiumState == PremiumReportKind.generating) {
      return _premiumCapped
          ? PremiumStatusCard.stillPreparing(onTryAgain: _retryPremium)
          : const PremiumStatusCard.generating();
    }
    return null;
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
            onPressed: _refresh,
          ),
        ],
      ),
      body: switch (_status?.phase) {
        null => const Center(child: CircularProgressIndicator(color: Colors.amber)),
        ReportPhase.preparing => ReportPreparingView(
            slow: _poller?.isSlow ?? false,
            onCheckAgain: _checkNow,
            checking: _checking,
          ),
        ReportPhase.delayed => ReportDelayedView(
            reason: _status!.reason,
            onCheckAgain: _checkNow,
            checking: _checking,
          ),
        ReportPhase.done => _loading || _checkingPremium
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : _error != null
                ? _errorView()
                : _isPremium && _fullReport != null
                    ? _premiumContentView()
                    : _contentView(),
      },
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
