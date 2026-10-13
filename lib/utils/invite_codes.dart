import 'package:flutter/services.dart';

import '../models/invite_redemption.dart';
import '../services/api_service.dart';
import 'errors.dart';

/// Store links used in shared invite messages (same as the backend invitation page).
const kAppStoreUrl = 'https://apps.apple.com/app/t-root-h-discipleship/id6757311543';
const kPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.trooth.flutterTroothAssessment';

/// Uppercases input as it's typed so codes read like the mentor's `K7QM-3XPR`.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// User-facing text for a failed redeem. Chosen by status code only (Principle XII):
/// the backend tells "expired" and "already used" apart only in its error text.
String inviteCodeErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 404:
        return "We couldn't find that code. Check it and try again.";
      case 400:
        return "This code can't be used. It may have expired or already been used. Ask your mentor for a new one.";
      case 403:
        return 'Invite codes are for apprentice accounts.';
      case 429:
        return 'Too many tries. Please wait a while and try again.';
    }
  }
  return friendlyError(error);
}

/// Confirmation shown after a successful redeem.
String inviteRedeemedMessage(InviteRedemption r) {
  final name = (r.mentorName == null || r.mentorName!.trim().isEmpty) ? 'your mentor' : r.mentorName!.trim();
  return r.relationship == InviteRelationship.alreadyActive
      ? "You're already connected with $name."
      : "You're now connected with $name.";
}

/// Text a mentor sends through the share sheet.
String buildInviteShareMessage({required String mentorName, required String code}) =>
    '$mentorName invited you to T[root]H Discipleship.\n\n'
    'Your invite code: $code\n\n'
    'Install the app, sign in, and enter the code to connect.\n'
    'iPhone: $kAppStoreUrl\n'
    'Android: $kPlayStoreUrl';
