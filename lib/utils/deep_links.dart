// Pure parsing for app links and named routes, kept free of Flutter widgets
// so it can be unit tested. main.dart maps the parsed routes to screens.

/// A screen the app can open from a link, notification or named route.
sealed class AppRoute {
  const AppRoute();
}

class DraftAssessmentRoute extends AppRoute {
  const DraftAssessmentRoute(this.draftId);
  final String draftId;
}

class AgreementSignRoute extends AppRoute {
  const AgreementSignRoute(this.tokenType, this.token);
  final String tokenType;
  final String token;
}

class MentorSubmissionRoute extends AppRoute {
  const MentorSubmissionRoute(this.assessmentId);
  final String assessmentId;
}

class MentorReportRoute extends AppRoute {
  const MentorReportRoute(this.assessmentId);
  final String assessmentId;
}

class TriviaChallengeRoute extends AppRoute {
  const TriviaChallengeRoute(this.challengeId);
  final String challengeId;
}

/// Maps an incoming link to a named route, or null if the app doesn't
/// handle it.
///
/// Supports both `trooth://agreements/sign/{type}/{token}` and
/// `https://links.onlyblv.com/agreements/sign/{type}/{token}`. In the custom
/// scheme the first part (`agreements`, `assessment`) parses as the URI host,
/// so it's put back in front of the path before matching.
String? routeNameForLink(Uri link) {
  final segments = link.scheme == 'trooth'
      ? [link.host, ...link.pathSegments]
      : link.pathSegments;
  final route = _parseSegments(segments);
  return switch (route) {
    DraftAssessmentRoute(:final draftId) => '/assessment/draft/${_enc(draftId)}',
    AgreementSignRoute(:final tokenType, :final token) =>
      '/agreements/sign/${_enc(tokenType)}/${_enc(token)}',
    _ => null, // Only drafts and agreements are reachable from outside links.
  };
}

/// Parses a named route (as passed to `onGenerateRoute`).
AppRoute? parseRouteName(String? name) {
  if (name == null || name.isEmpty) return null;
  final uri = Uri.tryParse(name);
  if (uri == null) return null;
  return _parseSegments(uri.pathSegments);
}

AppRoute? _parseSegments(List<String> s) {
  if (s.any((part) => part.isEmpty)) return null;
  if (s.length == 3 && s[0] == 'assessment' && s[1] == 'draft') {
    return DraftAssessmentRoute(s[2]);
  }
  if (s.length == 4 && s[0] == 'agreements' && s[1] == 'sign') {
    return AgreementSignRoute(s[2], s[3]);
  }
  if (s.length == 3 && s[0] == 'mentor' && s[1] == 'submissions') {
    return MentorSubmissionRoute(s[2]);
  }
  if (s.length == 4 && s[0] == 'mentor' && s[1] == 'submissions' && s[3] == 'report') {
    return MentorReportRoute(s[2]);
  }
  if (s.length == 3 && s[0] == 'trivia' && s[1] == 'challenges') {
    return TriviaChallengeRoute(s[2]);
  }
  return null;
}

String _enc(String part) => Uri.encodeComponent(part);
