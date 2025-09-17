import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'assessment_history_screen.dart';

class MentorAssessmentResultsScreen extends StatefulWidget {
  final String apprenticeId;
  final String apprenticeName;
  const MentorAssessmentResultsScreen({super.key, required this.apprenticeId, required this.apprenticeName});

  @override
  State<MentorAssessmentResultsScreen> createState() => _MentorAssessmentResultsScreenState();
}

class _MentorAssessmentResultsScreenState extends State<MentorAssessmentResultsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _masterLatest;
  List<Map<String, dynamic>> _genericSummaries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final templates = await _api.getPublishedTemplates();
      final masterFuture = _api.mentorGetMasterTroothLatest(widget.apprenticeId);
      final genericTemplates = templates.where((t) => (t as Map)['is_master_assessment'] != true).cast<Map<String,dynamic>>().toList();
      final genericLatestFutures = genericTemplates.map((t) => _api.mentorGetGenericLatest(t['id'] as String, widget.apprenticeId).then((m) => { 'template': t, 'latest': m })).toList();
  final results = await Future.wait([masterFuture, ...genericLatestFutures]);
  final master = results.first;
      final genPairs = results.skip(1).cast<Map<String,dynamic>>().toList();

      final summaries = <Map<String, dynamic>>[];
      for (final item in genPairs) {
        final t = item['template'] as Map<String, dynamic>;
        final latest = (item['latest'] as Map<String, dynamic>);
        if (latest.isEmpty) continue;
        summaries.add({'template_id': t['id'], 'template_name': t['name'] ?? 'Assessment', 'latest': latest});
      }

      if (mounted) setState(() {
        _masterLatest = master.isEmpty ? null : master;
        _genericSummaries = summaries;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load results: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${widget.apprenticeName} · Results', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.amber), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')))
              : _content(),
    );
  }

  Widget _content() {
    final children = <Widget>[];
    children.add(const Text('Master T[root]H', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')));
    if (_masterLatest == null) {
      children.add(Text('No Master submission yet.', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')));
    } else {
      children.add(_card(
        title: 'Master T[root]H',
        latest: _masterLatest!,
        onHistory: () => _openHistoryMaster(),
        onEmail: null, // mentor email for master not supported
      ));
    }

    children.add(const SizedBox(height: 16));
    children.add(const Text('Other Assessments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')));
    if (_genericSummaries.isEmpty) {
      children.add(Text('No other submissions yet.', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')));
    } else {
      for (final s in _genericSummaries) {
        children.add(_card(
          title: s['template_name']?.toString() ?? 'Assessment',
          latest: (s['latest'] as Map<String, dynamic>),
          onHistory: () => _openHistoryGeneric(s['template_id'] as String, s['template_name']?.toString() ?? 'Assessment'),
          onEmail: () async { await _api.mentorEmailGenericReport(s['template_id'] as String, widget.apprenticeId, assessmentId: (s['latest'] as Map)['id']?.toString()); _toast('Report emailed'); },
        ));
      }
    }

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
  }

  Widget _card({required String title, required Map<String, dynamic> latest, required VoidCallback onHistory, required Future<void> Function()? onEmail}) {
    final createdAt = latest['created_at']?.toString();
    final scores = latest['scores'] as Map<String, dynamic>?;
    final overall = scores?['overall'] ?? scores?['overall_score'] ?? scores?['overall_percent'];
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              if (createdAt != null) Text(_safeDate(createdAt), style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'Poppins')),
            ])),
            Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton.icon(onPressed: onHistory, icon: const Icon(Icons.history, color: Colors.amber, size: 18), label: const Text('History', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins'))),
              if (onEmail != null) ...[
                const SizedBox(width: 6),
                TextButton.icon(onPressed: () async { await onEmail(); }, icon: const Icon(Icons.mail_outline, color: Colors.amber, size: 18), label: const Text('Email', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins'))),
              ],
            ]),
          ]),
          if (overall != null) ...[const SizedBox(height: 8), Text('Overall: $overall', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'))],
        ]),
      ),
    );
  }

  void _openHistoryMaster() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssessmentHistoryScreen(mode: HistoryMode.mentorMaster, apprenticeId: widget.apprenticeId, title: 'Master T[root]H History')));
  }
  void _openHistoryGeneric(String templateId, String title) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssessmentHistoryScreen(mode: HistoryMode.mentorGeneric, templateId: templateId, apprenticeId: widget.apprenticeId, title: '$title History')));
  }

  String _safeDate(String iso) { try { final d = DateTime.parse(iso).toLocal(); return '${d.day}/${d.month}/${d.year}'; } catch (_) { return iso; } }
  void _toast(String msg, {bool error = false}) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green)); }
}
