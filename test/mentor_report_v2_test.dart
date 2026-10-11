import 'package:flutter_test/flutter_test.dart';
import 'package:trooth_assessment/features/assessments/models/mentor_report_v2.dart';

void main() {
  test('v2.1 report keeps Health Score and Biblical Knowledge separate', () {
    final report = MentorReportV2.fromJson({
      'health_score': 80,
      'health_band': 'Maturing',
      'biblical_knowledge': {'percent': 86.2, 'weak_topics': ['Bible Study']},
      'strengths': ['Morning Psalm reading'],
      'gaps': ['Sharing faith at work'],
      'insights': [],
      'flags': {'red': [], 'yellow': [], 'green': []},
    });

    expect(report.snapshot.healthScore, 80);
    expect(report.snapshot.overallMcPercent, 86.2);
    expect(report.snapshot.knowledgeBand, 'Maturing');
  });

  test('legacy report falls back to the MC percent for the headline', () {
    final report = MentorReportV2.fromJson({
      'snapshot': {'overall_mc_percent': 72, 'knowledge_band': 'Average'},
      'flags': {'red': [], 'yellow': [], 'green': []},
    });

    expect(report.snapshot.healthScore, 72);
    expect(report.snapshot.overallMcPercent, 72);
  });
}
