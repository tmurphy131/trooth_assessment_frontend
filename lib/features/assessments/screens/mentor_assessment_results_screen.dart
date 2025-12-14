import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class MentorAssessmentResultsList extends StatefulWidget {
  final String apprenticeId;
  final String apprenticeName;
  const MentorAssessmentResultsList({super.key, required this.apprenticeId, required this.apprenticeName});

  @override
  State<MentorAssessmentResultsList> createState() => _MentorAssessmentResultsListState();
}

class _MentorAssessmentResultsListState extends State<MentorAssessmentResultsList> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _assessments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getApprenticeSubmittedAssessments(widget.apprenticeId, limit: 50);
      final typed = list.map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>()).toList();
      if (!mounted) return;
      setState(() { _assessments = typed; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.apprenticeName} · Assessments')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: _assessments.isEmpty
                ? ListView(children: const [SizedBox(height: 200), Center(child: Text('No submissions yet'))])
                : ListView.separated(
                    itemCount: _assessments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _item(context, _assessments[i]),
                  ),
            ),
    );
  }

  Widget _item(BuildContext context, Map<String, dynamic> a) {
    final id = (a['id'] ?? a['assessment_id']).toString();
    final createdAt = a['created_at']?.toString();
    final cat = (a['category'] ?? a['template_id'] ?? 'assessment').toString();
    final scores = (a['scores'] as Map?)?.cast<String, dynamic>() ?? const {};
    final overall = scores['overall_score'];
    final top3 = (scores['top3'] as List?) ?? const [];
    String subtitle = '';
    if (overall != null) subtitle = 'Overall: $overall/10';
    if (top3.isNotEmpty) {
      final s = top3.take(2).map((e) => '${e['category']}: ${e['score']}').join(', ');
      subtitle = subtitle.isEmpty ? s : '$subtitle  ·  $s';
    }
    return ListTile(
      title: Text(cat),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (subtitle.isNotEmpty) Text(subtitle),
        if (createdAt != null) Text(_formatDate(createdAt), style: const TextStyle(color: Colors.grey)),
      ]),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).pushNamed(
          '/mentor/submissions/$id',
          arguments: {
            'apprenticeName': widget.apprenticeName,
            'apprenticeId': widget.apprenticeId,
          },
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final y = dt.year;
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d · $h:$mm $ap';
    } catch (_) {
      return iso;
    }
  }
}
