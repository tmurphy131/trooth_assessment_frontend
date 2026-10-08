/// A single-player trivia game run by the server (backend spec 001).
///
/// The app never holds a question's answer before it's answered:
/// [TriviaSessionQuestion] has no correct-option field, and grading only
/// arrives afterwards in [TriviaLastAnswer].
enum TriviaSessionStatus {
  active,
  awaitingGrace,
  finished;

  /// Unknown values fail safe to [finished] so the app shows results.
  static TriviaSessionStatus fromApi(String? value) => switch (value) {
        'active' => TriviaSessionStatus.active,
        'awaiting_grace' => TriviaSessionStatus.awaitingGrace,
        _ => TriviaSessionStatus.finished,
      };
}

class TriviaSessionQuestion {
  final int index;
  final int id;
  final String text;
  final String type; // multiple_choice | true_false

  /// Option letter → text, only the options present (true/false has a and b).
  final Map<String, String> options;

  const TriviaSessionQuestion({
    required this.index,
    required this.id,
    required this.text,
    required this.type,
    required this.options,
  });

  factory TriviaSessionQuestion.fromJson(Map<String, dynamic> json) {
    final options = <String, String>{};
    for (final letter in const ['a', 'b', 'c', 'd']) {
      final text = json['option_$letter'] as String?;
      if (text != null && text.isNotEmpty) options[letter] = text;
    }
    return TriviaSessionQuestion(
      index: json['index'] as int? ?? 0,
      id: json['id'] as int,
      text: json['question_text'] as String? ?? '',
      type: json['question_type'] as String? ?? 'multiple_choice',
      options: options,
    );
  }
}

class TriviaLastAnswer {
  final int questionId;
  final String? selected;
  final bool correct;
  final String correctOption;
  final bool timedOut;

  const TriviaLastAnswer({
    required this.questionId,
    required this.selected,
    required this.correct,
    required this.correctOption,
    required this.timedOut,
  });

  factory TriviaLastAnswer.fromJson(Map<String, dynamic> json) => TriviaLastAnswer(
        questionId: json['question_id'] as int,
        selected: json['selected'] as String?,
        correct: json['correct'] as bool? ?? false,
        correctOption: json['correct_option'] as String? ?? '',
        timedOut: json['timed_out'] as bool? ?? false,
      );
}

class TriviaSessionState {
  final String sessionId;
  final TriviaSessionStatus status;
  final int score;
  final int streak;
  final int correctCount;
  final int graceTokens;
  final int graceTokensUsed;
  final int questionNumber;
  final int totalQuestions;
  final int timeLimitMs;
  final TriviaSessionQuestion? question;
  final TriviaLastAnswer? lastAnswer;
  final int? graceExpiresInMs;

  /// Final result once [status] is finished; same shape as before
  /// (score, streak_length, correct_count, is_new_high_score, …).
  final Map<String, dynamic>? result;

  const TriviaSessionState({
    required this.sessionId,
    required this.status,
    required this.score,
    required this.streak,
    required this.correctCount,
    required this.graceTokens,
    required this.graceTokensUsed,
    required this.questionNumber,
    required this.totalQuestions,
    required this.timeLimitMs,
    this.question,
    this.lastAnswer,
    this.graceExpiresInMs,
    this.result,
  });

  factory TriviaSessionState.fromJson(Map<String, dynamic> json) {
    final question = json['question'] as Map<String, dynamic>?;
    final lastAnswer = json['last_answer'] as Map<String, dynamic>?;
    return TriviaSessionState(
      sessionId: json['session_id'] as String,
      status: TriviaSessionStatus.fromApi(json['status'] as String?),
      score: json['score'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      correctCount: json['correct_count'] as int? ?? 0,
      graceTokens: json['grace_tokens'] as int? ?? 0,
      graceTokensUsed: json['grace_tokens_used'] as int? ?? 0,
      questionNumber: json['question_number'] as int? ?? 1,
      totalQuestions: json['total_questions'] as int? ?? 0,
      timeLimitMs: json['time_limit_ms'] as int? ?? 30000,
      question: question == null ? null : TriviaSessionQuestion.fromJson(question),
      lastAnswer: lastAnswer == null ? null : TriviaLastAnswer.fromJson(lastAnswer),
      graceExpiresInMs: json['grace_expires_in_ms'] as int?,
      result: json['result'] as Map<String, dynamic>?,
    );
  }

  /// Streak multiplier, matching the server's scoring (100 × multiplier per correct answer).
  int get multiplier {
    if (streak < 5) return 1;
    if (streak < 10) return 2;
    if (streak < 15) return 3;
    if (streak < 20) return 4;
    return 5;
  }
}
