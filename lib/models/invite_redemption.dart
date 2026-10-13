/// Result of redeeming a mentor's invite code (backend spec 006, `POST /invitations/redeem`).
library;

enum InviteRelationship { created, reactivated, alreadyActive }

class InviteRedemption {
  final String mentorId;
  final String? mentorName;
  final InviteRelationship relationship;

  const InviteRedemption({required this.mentorId, this.mentorName, required this.relationship});

  /// Throws if `mentor_id` is missing; callers turn that into an [ApiException].
  factory InviteRedemption.fromJson(Map<String, dynamic> json) => InviteRedemption(
        mentorId: json['mentor_id'] as String,
        mentorName: json['mentor_name'] as String?,
        relationship: switch (json['relationship']) {
          'reactivated' => InviteRelationship.reactivated,
          'already_active' => InviteRelationship.alreadyActive,
          // Unknown values are treated as a new connection.
          _ => InviteRelationship.created,
        },
      );
}
