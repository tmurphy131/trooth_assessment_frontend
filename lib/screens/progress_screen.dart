import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'assessment_history_screen.dart';
import 'spiritual_gifts_assessment_screen.dart';
import 'spiritual_gifts_history_screen.dart';
import 'apprentice_report_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _master;
  Map<String, dynamic>? _gifts;
  List<Map<String, dynamic>> _reports = [];
  String? _cursor;
  bool _loadingMore = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Future.wait([
        _api.getProgressMasterLatest(),
        _api.getProgressGiftsLatest(),
        _api.getProgressReports(limit: 20),
      ]);
      final reports = res[2];
      setState(() {
        _master = (res[0]).isEmpty ? null : res[0];
        _gifts = (res[1]).isEmpty ? null : res[1];
        _reports = ((reports['items'] as List<dynamic>).cast<Map>()).map((m) => m.map((k,v) => MapEntry(k.toString(), v))).cast<Map<String,dynamic>>().toList();
        _cursor = reports['next_cursor'] as String?;
        _done = _cursor == null;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load progress: $e'; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_done || _loadingMore) return;
    setState(() { _loadingMore = true; });
    try {
      final res = await _api.getProgressReports(limit: 20, cursor: _cursor);
      final items = ((res['items'] as List<dynamic>).cast<Map>()).map((m) => m.map((k,v) => MapEntry(k.toString(), v))).cast<Map<String,dynamic>>().toList();
      setState(() {
        _reports.addAll(items);
        _cursor = res['next_cursor'] as String?;
        _done = _cursor == null;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() { _loadingMore = false; });
      _toast('Failed to load more: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Progress', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.amber))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? _errorView()
              : _contentView(),
    );
  }

  Widget _errorView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  Widget _contentView() {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Featured row
          Row(children: [
            Expanded(child: _masterCard()),
            const SizedBox(width: 12),
            Expanded(child: _giftsCard()),
          ]),
          const SizedBox(height: 24),
          const Text('All Assessment Reports', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          for (final r in _reports) _reportRow(r),
          if (_loadingMore) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(color: Colors.amber))),
          if (_done && _reports.isEmpty) _emptyState(),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox, color: Colors.grey[600], size: 48),
            const SizedBox(height: 8),
            Text('No reports yet', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }

  Widget _masterCard() {
    if (_master == null) return _emptyCard(
      title: 'Master T[root]H Assessment',
      cta: 'Take Assessment',
      onPressed: () {
        // Go back to dashboard so user can tap "New Assessment" chooser.
        Navigator.pop(context);
        _toast('Tap "New Assessment" to begin.', error: false);
      },
    );
    final badge = (_master!['overall_score_display'] ?? _master!['overall_score'] ?? 0).toString();
    final top3 = (_master!['top3'] as List<dynamic>? ?? const []).cast<Map>();
    final chips = top3.map((m) => {'category': m['category']?.toString() ?? '', 'score': m['score']}).toList();
    final completedAt = _master!['completed_at']?.toString();
    return _featuredCard(
      title: 'Master T[root]H Assessment',
      badge: badge,
      chips: chips,
      subtitle: completedAt != null ? _friendlyDate(completedAt) : null,
    );
  }

  Widget _giftsCard() {
    if (_gifts == null) return _emptyCard(
      title: 'Spiritual Gifts Assessment',
      cta: 'Take Assessment',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SpiritualGiftsAssessmentScreen()),
        );
      },
    );
    final top = (_gifts!['top_gifts_truncated'] as List<dynamic>? ?? const []).cast<Map>();
    final chips = top.map((m) => {'category': m['gift']?.toString() ?? m['gift_name']?.toString() ?? '', 'score': m['score']}).toList();
    final completedAt = _gifts!['completed_at']?.toString();
    return _featuredCard(
      title: 'Spiritual Gifts Assessment',
      chips: chips,
      subtitle: completedAt != null ? _friendlyDate(completedAt) : null,
    );
  }

  Widget _featuredCard({required String title, String? badge, required List<Map<String, dynamic>> chips, String? subtitle}) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            if (badge != null)
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(24)),
                alignment: Alignment.center,
                child: Text(badge, style: const TextStyle(color: Colors.amber, fontSize: 18, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in chips)
                  _chip(text: c['category']?.toString() ?? '', value: c['score']?.toString()),
              ]),
            ),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'Poppins')),
          ],
        ]),
      ),
    );
  }

  Widget _emptyCard({required String title, required String cta, VoidCallback? onPressed}) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('No results yet', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onPressed ?? () => Navigator.pop(context), child: Text(cta)),
        ]),
      ),
    );
  }

  Widget _reportRow(Map<String, dynamic> r) {
    // Title: prefer display_name/template_name/name, then generic fallback
    final title = (r['display_name'] ?? r['template_name'] ?? r['name'] ?? 'Assessment').toString();
    final ts = r['completed_at']?.toString();
    final type = r['assessment_type']?.toString() ?? 'other';
    final templateId = r['template_id']?.toString();
    final assessmentId = r['id']?.toString();
    final summary = (r['summary'] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_iconFor(type), color: Colors.amber),
        title: Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ts != null) Text(_friendlyDate(ts), style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'Poppins')),
            const SizedBox(height: 4),
            if (summary != null) _summaryText(type, summary),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.history, color: Colors.grey, size: 20),
          tooltip: 'View History',
          onPressed: () => _openHistory(type, templateId, title),
        ),
        onTap: () {
          // Navigate to report view for this specific assessment
          if (assessmentId != null && assessmentId.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ApprenticeReportScreen(
                  assessmentId: assessmentId,
                  title: title,
                ),
              ),
            );
          } else {
            _toast('Report not available for this assessment');
          }
        },
      ),
    );
  }

  void _openHistory(String type, String? templateId, String title) {
    switch (type) {
      case 'master':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AssessmentHistoryScreen(
              mode: HistoryMode.selfMaster,
              title: 'Master T[root]H History',
            ),
          ),
        );
        break;
      case 'spiritual_gifts':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SpiritualGiftsHistoryScreen()),
        );
        break;
      default:
        if (templateId != null && templateId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AssessmentHistoryScreen(
                mode: HistoryMode.selfGeneric,
                title: '$title History',
                templateId: templateId,
              ),
            ),
          );
        } else {
          _toast('History not available for this assessment type');
        }
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'master': return Icons.auto_graph;
      case 'spiritual_gifts': return Icons.auto_awesome;
      default: return Icons.assignment;
    }
  }

  Widget _summaryText(String type, Map<String, dynamic> summary) {
    if (type == 'master') {
      final overall = summary['overall_score'];
      final top3 = (summary['top3'] as List<dynamic>? ?? const []).cast<Map>();
      final cats = top3.map((m) => m['category']?.toString()).whereType<String>().toList();
      final text = 'Overall ${overall ?? '-'} • ${cats.take(3).join(', ')}';
      return Text(text, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 12));
    }
    if (type == 'spiritual_gifts') {
      final top = (summary['top_gifts'] as List<dynamic>? ?? const []).cast<Map>();
      final names = top.map((m) => (m['gift'] ?? m['gift_name'] ?? '').toString()).toList();
      return Text(names.take(3).join(', '), style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 12));
    }
    return const SizedBox.shrink();
  }

  Widget _chip({required String text, String? value}) {
    final label = text.length > 14 ? '${text.substring(0, 14)}…' : text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.withOpacity(0.45))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12)),
        if (value != null) ...[
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12)),
        ]
      ]),
    );
  }

  String _friendlyDate(String iso) {
    try { 
      final d = DateTime.parse(iso).toLocal(); 
      final hour = d.hour;
      final minute = d.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} at $hour12:$minute $period'; 
    } catch (_) { return iso; }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));
  }
}
