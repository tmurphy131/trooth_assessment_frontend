import 'package:flutter/material.dart';
import 'package:trooth_assessment/utils/assessments.dart';
import 'package:trooth_assessment/screens/mentor_spiritual_gifts_screen.dart';
import 'assessment_results_screen.dart';
import '../services/api_service.dart';

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
  List<Map<String, dynamic>> _assessments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getApprenticeSubmittedAssessments(widget.apprenticeId, limit: 100);
      setState(() {
        _assessments = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load assessments: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${widget.apprenticeName} · Assessments', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.amber),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')))
              : _assessments.isEmpty
                  ? ListView(children: const [SizedBox(height: 200), Center(child: Text('No submissions yet', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')))])
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _assessments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _item(context, _assessments[i]),
                    ),
    );
  }

  Widget _item(BuildContext context, Map<String, dynamic> a) {
    final id = (a['id'] ?? a['assessment_id']).toString();
    final createdAt = a['created_at']?.toString();
  final cat = (a['template_name'] ?? a['category'] ?? a['template_id'] ?? 'Assessment').toString();
    final scores = (a['scores'] as Map?)?.cast<String, dynamic>() ?? const {};
    final overall = scores['overall_score'] ?? scores['overall'];
    String subtitle = '';
    if (overall != null) subtitle = 'Overall: $overall/10';
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0x33FFC107), child: Icon(Icons.analytics, color: Colors.amber)),
        title: Text(cat, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
          if (createdAt != null) Text(_formatDate(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')),
        ]),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () {
          final assessment = a;
          // Spiritual Gifts: go to gifts screen with apprentice preselected
          if (isSpiritualGiftsAssessment(assessment)) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MentorSpiritualGiftsScreen(
                  initialApprenticeId: widget.apprenticeId,
                  initialApprenticeName: widget.apprenticeName,
                ),
              ),
            );
            return;
          }
          // Otherwise go to the mentor submission detail route
          Navigator.of(context).pushNamed(
            '/mentor/submissions/$id',
            arguments: {
              'apprenticeName': widget.apprenticeName,
              'apprenticeId': widget.apprenticeId,
            },
          );
        },
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year;
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d · $h12:$mm $ap';
    } catch (_) {
      return iso;
    }
  }
}
