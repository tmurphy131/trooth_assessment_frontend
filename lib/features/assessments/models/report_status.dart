// Assessment report states from the backend (specs/003-report-status-states).
//
// The backend stores an instant placeholder score at submit, so "has scores" no longer means the
// report is finished; only `status == 'done'` does. See contracts/report-states.md.

/// What a report screen should show for an assessment.
enum ReportPhase { preparing, done, delayed }

class ReportStatus {
  final ReportPhase phase;

  /// Short, user-safe reason when [phase] is [ReportPhase.delayed] (e.g. "AI provider unavailable").
  final String? reason;
  final int? healthScore;

  const ReportStatus(this.phase, {this.reason, this.healthScore});

  /// Parses `GET /assessments/{id}/status`. Never throws: anything unexpected is "preparing".
  factory ReportStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final ReportPhase phase;
    if (status is String) {
      phase = switch (status) {
        'done' => ReportPhase.done,
        'failed' => ReportPhase.delayed,
        _ => ReportPhase.preparing,
      };
    } else if (status == null) {
      // Older backends without a status field: fall back to "has scores".
      phase = json['has_scores'] == true ? ReportPhase.done : ReportPhase.preparing;
    } else {
      phase = ReportPhase.preparing;
    }
    final rawReason = json['reason'];
    final reason = rawReason is String && rawReason.trim().isNotEmpty ? rawReason.trim() : null;
    final health = json['health_score'];
    return ReportStatus(
      phase,
      reason: phase == ReportPhase.delayed ? reason : null,
      healthScore: health is num ? health.round() : null,
    );
  }
}

enum PremiumReportKind { ready, generating, unavailable, premiumRequired }

/// Outcome of a Premium full-report request.
class PremiumReportResult {
  final PremiumReportKind kind;
  final Map<String, dynamic>? report;
  final bool cached;

  const PremiumReportResult._(this.kind, {this.report, this.cached = false});

  const PremiumReportResult.ready(Map<String, dynamic> report, {bool cached = false})
      : this._(PremiumReportKind.ready, report: report, cached: cached);
  const PremiumReportResult.generating() : this._(PremiumReportKind.generating);
  const PremiumReportResult.unavailable() : this._(PremiumReportKind.unavailable);
  const PremiumReportResult.premiumRequired() : this._(PremiumReportKind.premiumRequired);

  bool get isReady => kind == PremiumReportKind.ready;
}
