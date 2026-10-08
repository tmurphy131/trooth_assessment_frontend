part of '../api_service.dart';

/// The question changed under the user (they answered across midnight).
class DailyQuestionExpiredException implements Exception {
  const DailyQuestionExpiredException();
  @override
  String toString() => "That was yesterday's question. Here's today's.";
}

// /    Daily trivia                                                    /
extension DailyTriviaApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*  📅  Daily trivia (backend spec 002)                                 */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<DailyToday> dailyTriviaToday() async {
    const path = '/trivia/daily/today';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return DailyToday.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw ApiException(r.statusCode, 'dailyTriviaToday failed (${r.statusCode}) ${r.body}');
  }

  /// Throws [DailyQuestionExpiredException] when [questionDate] is no longer today.
  Future<DailyAnswerOutcome> dailyTriviaAnswer({required DateTime questionDate, required String option}) async {
    const path = '/trivia/daily/today/answer';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(),
        body: jsonEncode({'question_date': isoDate(questionDate), 'option': option}));
    if (r.statusCode == 200) return DailyAnswerOutcome.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    if (r.statusCode == 409 && r.body.contains('question_expired')) throw const DailyQuestionExpiredException();
    throw ApiException(r.statusCode, 'dailyTriviaAnswer failed (${r.statusCode}) ${r.body}');
  }

  Future<DailyStreak> dailyTriviaStreak() async {
    const path = '/trivia/daily/streak';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return DailyStreak.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw ApiException(r.statusCode, 'dailyTriviaStreak failed (${r.statusCode}) ${r.body}');
  }

  /// Saves the device's IANA timezone, used for the user's daily date and 9am reminder.
  Future<void> setMyTimezone(String timezone) async {
    const path = '/users/me/timezone';
    final r = await _http.put(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode({'timezone': timezone}));
    if (r.statusCode == 200) return;
    throw ApiException(r.statusCode, 'setMyTimezone failed (${r.statusCode})');
  }
}
