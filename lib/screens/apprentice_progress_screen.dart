import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'assessment_history_screen.dart';

class ApprenticeProgressScreen extends StatefulWidget {
  const ApprenticeProgressScreen({super.key});

  @override
  State<ApprenticeProgressScreen> createState() => _ApprenticeProgressScreenState();
}

class _ApprenticeProgressScreenState extends State<ApprenticeProgressScreen> {
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
      final results = await Future.wait([
        _api.getMasterTroothLatest(),
        _api.getPublishedTemplates(), // to enumerate generic templates
      ]);

      final master = results[0] as Map<String, dynamic>;
      final templates = (results[1] as List<dynamic>).cast<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).cast<Map<String,dynamic>>().toList();

      // For each non-master published template, fetch latest (ignore 404 -> empty {})
      final genericTemplates = templates.where((t) => t['is_master_assessment'] != true).toList();
      final futures = genericTemplates.map((t) => _api.getGenericLatest(t['id'] as String).then((m) => { 'template': t, 'latest': m })).toList();
      final latestList = futures.isEmpty ? <Map<String,dynamic>>[] : (await Future.wait(futures)).cast<Map<String,dynamic>>();

      final summaries = <Map<String, dynamic>>[];
      for (final item in latestList) {
        final t = item['template'] as Map<String, dynamic>;
        final latest = (item['latest'] as Map<String, dynamic>);
        if (latest.isEmpty) continue; // no submissions yet
        summaries.add({
          'template_id': t['id'],
          'template_name': t['name'] ?? 'Assessment',
          'latest': latest,
        });
      }

      if (mounted) {
        setState(() {
          _masterLatest = master.isEmpty ? null : master;
          _genericSummaries = summaries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load progress: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Your Progress', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? _errorView()
              : _contentView(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Retry'),
          )
        ],
      ),
    );
  }

  Widget _contentView() {
    final children = <Widget>[];
    // Master T[root]H
    children.add(_sectionTitle('Master T[root]H'));
    if (_masterLatest == null) {
      children.add(_emptyHint('No Master Assessment yet. Start one from "New Assessment".'));
    } else {
      children.add(_resultCard(
        name: 'Master T[root]H',
        payload: _masterLatest!,
        emailAction: () => _emailMaster(latest: _masterLatest!),
        onHistory: _openHistoryMaster,
      ));
    }

    // Generic templates
    children.add(const SizedBox(height: 22));
    children.add(_sectionTitle('Other Assessments'));
    if (_genericSummaries.isEmpty) {
      children.add(_emptyHint('No other assessments yet.'));
    } else {
      for (final s in _genericSummaries) {
        children.add(_resultCard(
          name: s['template_name']?.toString() ?? 'Assessment',
          payload: (s['latest'] as Map<String, dynamic>),
          emailAction: () => _emailGeneric(templateId: s['template_id'] as String, latest: (s['latest'] as Map<String, dynamic>)),
          onHistory: () => _openHistoryGeneric(s['template_id'] as String, s['template_name']?.toString() ?? 'Assessment'),
        ));
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')),
    );
  }

  Widget _resultCard({required String name, required Map<String, dynamic> payload, required Future<void> Function() emailAction, VoidCallback? onHistory}) {
    // Try to extract some common fields (score/category breakdown differs per template)
    final createdAt = payload['created_at']?.toString();
    final scores = payload['scores'] as Map<String, dynamic>?;
    final overall = scores?['overall'] ?? scores?['overall_score'] ?? scores?['overall_percent'];

    return Card(
      elevation: 2,
      color: Colors.grey[850],
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.assessment, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                      if (createdAt != null)
                        Text(_safeDate(createdAt), style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'Poppins')),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onHistory != null)
                      TextButton.icon(
                        onPressed: onHistory,
                        icon: const Icon(Icons.history, color: Colors.amber, size: 18),
                        label: const Text('History', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                      ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () async { await emailAction(); },
                      icon: const Icon(Icons.mail_outline, color: Colors.amber, size: 18),
                      label: const Text('Email', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                    ),
                  ],
                )
              ],
            ),
            if (overall != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Overall:', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                  const SizedBox(width: 8),
                  Text(overall.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                ],
              ),
            ],
            if (scores != null) ...[
              const SizedBox(height: 10),
              _categoryChips(scores),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryChips(Map<String, dynamic> scores) {
    final categoryScores = (scores['category_scores'] ?? scores['categories'] ?? const {}) as Map<String, dynamic>;
    if (categoryScores.isEmpty) return const SizedBox.shrink();
    final entries = categoryScores.entries.take(6).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                const SizedBox(width: 6),
                Text(e.value.toString(), style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }

  String _safeDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _emailMaster({required Map<String, dynamic> latest}) async {
    try {
      await _api.emailMyMasterTroothReport(assessmentId: latest['id']?.toString());
      _toast('Report sent to ${FirebaseAuth.instance.currentUser?.email ?? 'your email'}');
    } catch (e) {
      _toast('Failed to send report: $e', error: true);
    }
  }

  Future<void> _emailGeneric({required String templateId, required Map<String, dynamic> latest}) async {
    try {
      await _api.emailMyGenericReport(templateId, assessmentId: latest['id']?.toString());
      _toast('Report sent to ${FirebaseAuth.instance.currentUser?.email ?? 'your email'}');
    } catch (e) {
      _toast('Failed to send report: $e', error: true);
    }
  }

  void _openHistoryMaster() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AssessmentHistoryScreen(
          mode: HistoryMode.selfMaster,
          title: 'Master T[root]H History',
        ),
      ),
    );
  }

  void _openHistoryGeneric(String templateId, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentHistoryScreen(
          mode: HistoryMode.selfGeneric,
          templateId: templateId,
          title: '$title History',
        ),
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green),
    );
  }
}
