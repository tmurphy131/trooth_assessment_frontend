import 'package:flutter_test/flutter_test.dart';
import 'package:trooth_assessment/utils/deep_links.dart';

void main() {
  group('routeNameForLink', () {
    final cases = <String, String?>{
      'trooth://assessment/draft/abc123': '/assessment/draft/abc123',
      'trooth://agreements/sign/apprentice/tok_1': '/agreements/sign/apprentice/tok_1',
      'https://links.onlyblv.com/agreements/sign/parent/tok_2': '/agreements/sign/parent/tok_2',
      // Unsupported or malformed links are ignored.
      'trooth://assessment/draft': null,
      'trooth://agreements/sign/apprentice': null,
      'https://links.onlyblv.com/somewhere/else': null,
      'trooth://mentor/submissions/abc': null, // internal route, not linkable
      'https://links.onlyblv.com/': null,
    };
    cases.forEach((link, expected) {
      test(link, () => expect(routeNameForLink(Uri.parse(link)), expected));
    });

    test('link output round-trips through parseRouteName, including odd characters', () {
      final name = routeNameForLink(Uri.parse('trooth://agreements/sign/apprentice/a%2Fb%20c'))!;
      final route = parseRouteName(name);
      expect(route, isA<AgreementSignRoute>());
      expect((route as AgreementSignRoute).token, 'a/b c');
    });
  });

  group('parseRouteName', () {
    test('draft', () {
      final r = parseRouteName('/assessment/draft/d1');
      expect(r, isA<DraftAssessmentRoute>());
      expect((r as DraftAssessmentRoute).draftId, 'd1');
    });

    test('mentor submission and report', () {
      expect(parseRouteName('/mentor/submissions/a1'), isA<MentorSubmissionRoute>());
      final r = parseRouteName('/mentor/submissions/a1/report');
      expect(r, isA<MentorReportRoute>());
      expect((r as MentorReportRoute).assessmentId, 'a1');
    });

    test('trivia challenge', () {
      final r = parseRouteName('/trivia/challenges/c9');
      expect((r as TriviaChallengeRoute).challengeId, 'c9');
    });

    test('rejects unknown, empty and malformed names', () {
      expect(parseRouteName(null), isNull);
      expect(parseRouteName(''), isNull);
      expect(parseRouteName('/'), isNull);
      expect(parseRouteName('/mentor/submissions//report'), isNull);
      expect(parseRouteName('/unknown/route/x'), isNull);
    });
  });
}
