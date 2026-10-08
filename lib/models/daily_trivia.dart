/// The daily trivia question, its result and the user's streak (backend spec 002).
///
/// Like [TriviaSessionQuestion], [DailyQuestion] has no correct-option field:
/// the answer only arrives in [DailyAnswerResult] after the server grades it.
library;

DateTime _date(String iso) {
  final d = DateTime.parse(iso);
  return DateTime(d.year, d.month, d.day);
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class DailyQuestion {
  final DateTime date;
  final String category;
  final String categoryLabel;
  final String difficulty;
  final String difficultyLabel;
  final String type; // multiple_choice | true_false
  final String text;

  /// Option letter → text, only the options present (true/false has a and b).
  final Map<String, String> options;

  const DailyQuestion({
    required this.date,
    required this.category,
    required this.categoryLabel,
    required this.difficulty,
    required this.difficultyLabel,
    required this.type,
    required this.text,
    required this.options,
  });

  factory DailyQuestion.fromJson(Map<String, dynamic> json) {
    final options = <String, String>{};
    for (final letter in const ['a', 'b', 'c', 'd']) {
      final text = json['option_$letter'] as String?;
      if (text != null && text.isNotEmpty) options[letter] = text;
    }
    return DailyQuestion(
      date: _date(json['date'] as String),
      category: json['category'] as String? ?? '',
      categoryLabel: json['category_label'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      difficultyLabel: json['difficulty_label'] as String? ?? '',
      type: json['question_type'] as String? ?? 'multiple_choice',
      text: json['question_text'] as String? ?? '',
      options: options,
    );
  }
}

class DailyAnswerResult {
  final String selected;
  final bool correct;
  final String correctOption;

  const DailyAnswerResult({required this.selected, required this.correct, required this.correctOption});

  factory DailyAnswerResult.fromJson(Map<String, dynamic> json) => DailyAnswerResult(
        selected: json['selected_option'] as String,
        correct: json['correct'] as bool? ?? false,
        correctOption: json['correct_option'] as String,
      );
}

enum DailyRewardStatus {
  pending,
  active,
  superseded,
  expired;

  static DailyRewardStatus fromApi(String? value) => switch (value) {
        'active' => DailyRewardStatus.active,
        'superseded' => DailyRewardStatus.superseded,
        'expired' => DailyRewardStatus.expired,
        _ => DailyRewardStatus.pending,
      };
}

class DailyReward {
  final int id;
  final int tier;
  final int percent;
  final bool perfect;
  final DailyRewardStatus status;
  final String? code;
  final DateTime? expiresAt;
  final String shopUrl;

  const DailyReward({
    required this.id,
    required this.tier,
    required this.percent,
    required this.perfect,
    required this.status,
    required this.code,
    required this.expiresAt,
    required this.shopUrl,
  });

  factory DailyReward.fromJson(Map<String, dynamic> json) => DailyReward(
        id: json['id'] as int,
        tier: json['tier'] as int,
        percent: json['percent'] as int,
        perfect: json['perfect'] as bool? ?? false,
        status: DailyRewardStatus.fromApi(json['status'] as String?),
        code: json['discount_code'] as String?,
        expiresAt: json['expires_at'] == null ? null : DateTime.parse(json['expires_at'] as String).toLocal(),
        shopUrl: json['shop_url'] as String? ?? '',
      );
}

class NextMilestone {
  final int tier;
  final int daysRemaining;
  final int percent;
  final int percentIfPerfect;

  const NextMilestone({
    required this.tier,
    required this.daysRemaining,
    required this.percent,
    required this.percentIfPerfect,
  });

  factory NextMilestone.fromJson(Map<String, dynamic> json) => NextMilestone(
        tier: json['tier'] as int,
        daysRemaining: json['days_remaining'] as int,
        percent: json['percent'] as int,
        percentIfPerfect: json['percent_if_perfect'] as int,
      );
}

enum DayStatus {
  correct,
  wrong,
  freeze;

  static DayStatus fromApi(String? value) => switch (value) {
        'correct' => DayStatus.correct,
        'wrong' => DayStatus.wrong,
        _ => DayStatus.freeze,
      };
}

class DailyStreak {
  /// Below this the week row is shown; from it, the month calendar (spec US2).
  static const monthViewFrom = 7;

  final int current;
  final int longest;
  final int freezes;
  final int maxFreezes;
  final bool perfectRun;
  final bool answeredToday;
  final DateTime? startedOn;

  /// Local date → status for the last ~2 months; days without an entry are blank.
  final Map<DateTime, DayStatus> calendar;
  final NextMilestone? nextMilestone;
  final DailyReward? reward;

  const DailyStreak({
    required this.current,
    required this.longest,
    required this.freezes,
    required this.maxFreezes,
    required this.perfectRun,
    required this.answeredToday,
    required this.startedOn,
    required this.calendar,
    required this.nextMilestone,
    required this.reward,
  });

  bool get showMonth => current >= monthViewFrom;

  factory DailyStreak.fromJson(Map<String, dynamic> json) => DailyStreak(
        current: json['current_streak'] as int? ?? 0,
        longest: json['longest_streak'] as int? ?? 0,
        freezes: json['freezes_available'] as int? ?? 0,
        maxFreezes: json['max_freezes'] as int? ?? 2,
        perfectRun: json['perfect_run'] as bool? ?? true,
        answeredToday: json['answered_today'] as bool? ?? false,
        startedOn: json['streak_started_on'] == null ? null : _date(json['streak_started_on'] as String),
        calendar: {
          for (final day in (json['calendar'] as List? ?? const []).cast<Map<String, dynamic>>())
            _date(day['date'] as String): DayStatus.fromApi(day['status'] as String?),
        },
        nextMilestone: json['next_milestone'] == null
            ? null
            : NextMilestone.fromJson(json['next_milestone'] as Map<String, dynamic>),
        reward: json['active_reward'] == null
            ? null
            : DailyReward.fromJson(json['active_reward'] as Map<String, dynamic>),
      );
}

/// `GET /trivia/daily/today`
class DailyToday {
  final DailyQuestion question;
  final DailyAnswerResult? answer;
  final DailyStreak streak;

  const DailyToday({required this.question, required this.answer, required this.streak});

  factory DailyToday.fromJson(Map<String, dynamic> json) => DailyToday(
        question: DailyQuestion.fromJson(json['question'] as Map<String, dynamic>),
        answer: json['answer'] == null ? null : DailyAnswerResult.fromJson(json['answer'] as Map<String, dynamic>),
        streak: DailyStreak.fromJson(json['streak'] as Map<String, dynamic>),
      );
}

/// `POST /trivia/daily/today/answer`
class DailyAnswerOutcome {
  final DailyQuestion question;
  final DailyAnswerResult answer;
  final DailyStreak streak;
  final int freezesUsed;
  final bool streakReset;
  final bool freezeEarned;
  final DailyReward? newReward;

  const DailyAnswerOutcome({
    required this.question,
    required this.answer,
    required this.streak,
    required this.freezesUsed,
    required this.streakReset,
    required this.freezeEarned,
    required this.newReward,
  });

  factory DailyAnswerOutcome.fromJson(Map<String, dynamic> json) => DailyAnswerOutcome(
        question: DailyQuestion.fromJson(json['question'] as Map<String, dynamic>),
        answer: DailyAnswerResult.fromJson(json['answer'] as Map<String, dynamic>),
        streak: DailyStreak.fromJson(json['streak'] as Map<String, dynamic>),
        freezesUsed: json['freezes_used'] as int? ?? 0,
        streakReset: json['streak_reset'] as bool? ?? false,
        freezeEarned: json['freeze_earned'] as bool? ?? false,
        newReward: json['new_reward'] == null
            ? null
            : DailyReward.fromJson(json['new_reward'] as Map<String, dynamic>),
      );
}
