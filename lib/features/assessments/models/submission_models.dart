class SubmissionDetail {
  final String submissionId;
  final DateTime? submittedAt;
  final ApprenticeRef apprentice;
  final List<QuestionItem> questions;

  SubmissionDetail({required this.submissionId, required this.submittedAt, required this.apprentice, required this.questions});

  factory SubmissionDetail.fromJson(Map<String, dynamic> json) {
    final id = (json['submission_id'] ?? json['id'] ?? json['submissionId'])?.toString();
    if (id == null) throw FormatException('submission_id missing');
    final apprentice = ApprenticeRef.fromJson(json['apprentice'] as Map<String, dynamic>);
    final items = (json['questions'] as List<dynamic>? ?? [])
        .map((e) => QuestionItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return SubmissionDetail(
      submissionId: id,
      submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at']) : null,
      apprentice: apprentice,
      questions: items,
    );
  }
}

class ApprenticeRef {
  final String id;
  final String name;
  ApprenticeRef({required this.id, required this.name});
  factory ApprenticeRef.fromJson(Map<String, dynamic> json) {
    return ApprenticeRef(id: (json['id'] ?? '').toString(), name: (json['name'] ?? json['email'] ?? 'Apprentice').toString());
  }
}

class QuestionItem {
  final String questionId;
  final String category;
  final String text;
  final String type; // mc | open
  final List<OptionItem> options;
  final String? apprenticeAnswer;
  final String? chosenOptionId;
  final RubricDetails? rubric;

  QuestionItem({
    required this.questionId,
    required this.category,
    required this.text,
    required this.type,
    required this.options,
    this.apprenticeAnswer,
    this.chosenOptionId,
    this.rubric,
  });

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    return QuestionItem(
      questionId: (json['question_id'] ?? json['id'] ?? '').toString(),
      category: (json['category'] ?? 'General').toString(),
      text: (json['text'] ?? '').toString(),
      type: (json['type'] ?? json['question_type'] ?? 'open').toString(),
      options: (json['options'] as List<dynamic>? ?? []).map((e) => OptionItem.fromJson(e as Map<String, dynamic>)).toList(growable: false),
      apprenticeAnswer: json['apprentice_answer']?.toString(),
      chosenOptionId: json['chosen_option_id']?.toString(),
      rubric: json['rubric'] == null ? null : RubricDetails.fromJson(json['rubric'] as Map<String, dynamic>),
    );
  }
}

class OptionItem {
  final String? id;
  final String text;
  final bool isCorrect;
  OptionItem({this.id, required this.text, required this.isCorrect});
  factory OptionItem.fromJson(Map<String, dynamic> json) {
    return OptionItem(id: json['id']?.toString(), text: (json['text'] ?? json['option_text'] ?? '').toString(), isCorrect: (json['is_correct'] ?? false) == true);
  }
}

class RubricDetails {
  final int? understanding;
  final int? practice;
  final int? gospelCenteredness;
  final int? humility;
  final int? teachability;
  RubricDetails({this.understanding, this.practice, this.gospelCenteredness, this.humility, this.teachability});
  factory RubricDetails.fromJson(Map<String, dynamic> json) {
    int? _i(dynamic v) => v == null ? null : (v as num).toInt();
    return RubricDetails(
      understanding: _i(json['understanding']),
      practice: _i(json['practice']),
      gospelCenteredness: _i(json['gospel_centeredness'] ?? json['gospelCenteredness']),
      humility: _i(json['humility']),
      teachability: _i(json['teachability']),
    );
  }
}
