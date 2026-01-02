/// Model representing a mentor's note on an assessment
class MentorNote {
  final String id;
  final String assessmentId;
  final String mentorId;
  final String content;
  final String? followUpPlan;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MentorNote({
    required this.id,
    required this.assessmentId,
    required this.mentorId,
    required this.content,
    this.followUpPlan,
    required this.isPrivate,
    required this.createdAt,
    this.updatedAt,
  });

  factory MentorNote.fromJson(Map<String, dynamic> json) {
    return MentorNote(
      id: json['id'] as String,
      assessmentId: json['assessment_id'] as String,
      mentorId: json['mentor_id'] as String,
      content: json['content'] as String,
      followUpPlan: json['follow_up_plan'] as String?,
      isPrivate: json['is_private'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assessment_id': assessmentId,
      'mentor_id': mentorId,
      'content': content,
      'follow_up_plan': followUpPlan,
      'is_private': isPrivate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  MentorNote copyWith({
    String? id,
    String? assessmentId,
    String? mentorId,
    String? content,
    String? followUpPlan,
    bool? isPrivate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MentorNote(
      id: id ?? this.id,
      assessmentId: assessmentId ?? this.assessmentId,
      mentorId: mentorId ?? this.mentorId,
      content: content ?? this.content,
      followUpPlan: followUpPlan ?? this.followUpPlan,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether this note is shared (visible to apprentice)
  bool get isShared => !isPrivate;

  /// Check if note has been edited
  bool get wasEdited => updatedAt != null && updatedAt != createdAt;

  /// Get display timestamp (updated_at if edited, otherwise created_at)
  DateTime get displayTimestamp => updatedAt ?? createdAt;
}
