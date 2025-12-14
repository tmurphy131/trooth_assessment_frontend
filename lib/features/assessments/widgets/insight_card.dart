import 'package:flutter/material.dart';
import '../models/mentor_report_v2.dart';

class InsightCard extends StatelessWidget {
  final OpenEndedInsight insight;
  const InsightCard({super.key, required this.insight});

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'seedling':
      case 'low':
        return Colors.orange;
      case 'growing':
      case 'medium':
        return Colors.blue;
      case 'mature':
      case 'high':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _levelColor(insight.level).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(insight.level, style: TextStyle(color: _levelColor(insight.level))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          if (insight.observation.isNotEmpty) Text(insight.observation),
          if (insight.evidence.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('“${insight.evidence}”', style: const TextStyle(fontStyle: FontStyle.italic))),
          if (insight.nextStep.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Next step: ${insight.nextStep}')),
        ]),
      ),
    );
  }
}
