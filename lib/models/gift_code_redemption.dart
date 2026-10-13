/// Result of redeeming a mentor's gift code (`POST /apprentice/redeem-code`).
///
/// The backend answers business failures (invalid, used, expired, already Premium)
/// with HTTP 200 and `success: false`; callers branch on [success], not [message].
library;

class GiftCodeRedemption {
  final bool success;
  final String message;
  final String? mentorName;
  final String? expiresAt;

  const GiftCodeRedemption({required this.success, required this.message, this.mentorName, this.expiresAt});

  /// Throws if `success` or `message` is missing; callers turn that into an [ApiException].
  factory GiftCodeRedemption.fromJson(Map<String, dynamic> json) => GiftCodeRedemption(
        success: json['success'] as bool,
        message: json['message'] as String,
        mentorName: json['mentor_name'] as String?,
        expiresAt: json['expires_at'] as String?,
      );
}
