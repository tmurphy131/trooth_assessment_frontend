import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum HistoryMode { selfMaster, selfGeneric, mentorMaster, mentorGeneric }

class AssessmentHistoryScreen extends StatefulWidget {
  final HistoryMode mode;
  final String? templateId;   // for generic
  final String? apprenticeId; // for mentor
  final String title;

  const AssessmentHistoryScreen({
    super.key,
    required this.mode,
    required this.title,
    this.templateId,
    this.apprenticeId,
  });

  @override
  State<AssessmentHistoryScreen> createState() => _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String? _cursor;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _fetch(initial: true);
  }

  Future<void> _fetch({bool initial = false}) async {
    if (initial) { setState(() { _loading = true; _error = null; _items = []; _cursor = null; _hasMore = false; }); }
    try {
      Map<String, dynamic> page;
      switch (widget.mode) {
        case HistoryMode.selfMaster:
          page = await _api.getMasterTroothHistory(cursor: _cursor, limit: 20);
          break;
        case HistoryMode.selfGeneric:
          page = await _api.getGenericHistory(widget.templateId!, cursor: _cursor, limit: 20);
          break;
        case HistoryMode.mentorMaster:
          page = await _api.mentorGetMasterTroothHistory(widget.apprenticeId!, cursor: _cursor, limit: 20);
          break;
        case HistoryMode.mentorGeneric:
          page = await _api.mentorGetGenericHistory(widget.templateId!, widget.apprenticeId!, cursor: _cursor, limit: 20);
          break;
      }
      final items = (page['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final next = page['next_cursor']?.toString();
      setState(() {
        _items.addAll(items);
        _cursor = next;
        _hasMore = next != null && next.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load history: $e'; _loading = false; });
    }
  }

  Future<void> _email(Map<String, dynamic> row) async {
    try {
      switch (widget.mode) {
        case HistoryMode.selfMaster:
          await _api.emailMyMasterTroothReport(assessmentId: row['id']?.toString());
          break;
        case HistoryMode.selfGeneric:
          await _api.emailMyGenericReport(widget.templateId!, assessmentId: row['id']?.toString());
          break;
        case HistoryMode.mentorMaster:
          // No mentor email endpoint for master specified; show info.
          _toast('Email sending for Master by mentor not available');
          return;
        case HistoryMode.mentorGeneric:
          await _api.mentorEmailGenericReport(widget.templateId!, widget.apprenticeId!, assessmentId: row['id']?.toString());
          break;
      }
      _toast('Report emailed');
    } catch (e) {
      _toast('Email failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
        actions: [IconButton(onPressed: () => _fetch(initial: true), icon: const Icon(Icons.refresh, color: Colors.amber))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? _errorView()
              : _listView(),
    );
  }

  Widget _errorView() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: () => _fetch(initial: true), child: const Text('Retry')),
    ]),
  );

  Widget _listView() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (ctx, i) => _row(_items[i]),
          ),
        ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton(
              onPressed: () => _fetch(initial: false),
              child: const Text('Load more'),
            ),
          ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> row) {
    final createdAt = row['created_at']?.toString();
    final scores = row['scores'] as Map<String, dynamic>?;
    final overall = scores?['overall'] ?? scores?['overall_score'] ?? scores?['overall_percent'];
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(createdAt != null ? _safeDate(createdAt) : 'Submission', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        subtitle: overall != null ? Text('Overall: $overall', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')) : null,
        trailing: TextButton.icon(
          onPressed: () => _email(row),
          icon: const Icon(Icons.mail_outline, color: Colors.amber, size: 18),
          label: const Text('Email', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
        ),
      ),
    );
  }

  String _safeDate(String iso) {
    try { final d = DateTime.parse(iso).toLocal(); return '${d.day}/${d.month}/${d.year}'; } catch (_) { return iso; }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));
  }
}
