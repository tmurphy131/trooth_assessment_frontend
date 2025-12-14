import 'package:flutter/material.dart';
import '../models/mentor_report_v2.dart';
import '../widgets/kpi_card.dart';
import '../widgets/insight_card.dart';

class MentorReportV2Screen extends StatelessWidget {
  final MentorReportV2 report;
  final String apprenticeName;
  const MentorReportV2Screen({super.key, required this.report, required this.apprenticeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mentor Report · $apprenticeName')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: KpiCard(title: 'Biblical Knowledge', value: '${report.snapshot.overallMcPercent}%', subtitle: report.snapshot.knowledgeBand)),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(title: 'Spiritual Life', value: _deriveOpenLevel(report), subtitle: 'Open-ended')),
          ]),
          const SizedBox(height: 12),
          if (report.biblicalKnowledge != null && report.biblicalKnowledge!.topicBreakdown.isNotEmpty) ...[
            const Text('Knowledge Breakdown', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...report.biblicalKnowledge!.topicBreakdown.map((t) => ListTile(title: Text(t.topic), subtitle: Text('${t.correct}/${t.total} (${((t.total==0?0: (t.correct/t.total*100)).toStringAsFixed(1))}%)'), trailing: t.note==null?null:Text(t.note!)))
          ],
          const SizedBox(height: 12),
          const Text('Insights', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...report.openEndedInsights.map((i) => InsightCard(insight: i)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Top Strengths', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...report.snapshot.topStrengths.map((s) => Text('• $s')),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Top Gaps', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...report.snapshot.topGaps.map((s) => Text('• $s')),
            ])),
          ]),
          const SizedBox(height: 12),
          const Text('Four‑Week Plan', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: report.fourWeekPlan.rhythm.map((e) => Text('• $e')).toList())),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: report.fourWeekPlan.checkpoints.map((e) => Text('• $e')).toList())),
          ]),
          const SizedBox(height: 12),
          const Text('Conversation Starters', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...report.conversationStarters.map((e) => Text('• $e')),
          const SizedBox(height: 12),
          const Text('Recommended Resources', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...report.recommendedResources.map((res) => Text('• ${res.title} — ${res.why} (${res.type})')),
        ],
      ),
    );
  }

  String _deriveOpenLevel(MentorReportV2 r) {
    final levels = r.openEndedInsights.map((e) => e.level).toList();
    if (levels.isEmpty) return '-';
    levels.sort();
    String best = levels.first; int bestCount = 1; int run = 1;
    for (int i=1;i<levels.length;i++) { if (levels[i]==levels[i-1]) { run++; if (run>bestCount) { best=levels[i]; bestCount=run; } } else { run=1; } }
    return best;
  }
}
