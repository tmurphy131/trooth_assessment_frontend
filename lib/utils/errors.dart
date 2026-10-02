import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// A message that's safe to show a user. Raw exceptions can contain URLs,
/// status codes and response bodies; debug builds still append them.
String friendlyError(Object error) {
  final String message;
  if (error is NetworkException) {
    message = error.message;
  } else if (error is PremiumRequiredException) {
    message = error.message;
  } else if (error is FirebaseAuthException) {
    message = error.message ?? 'Sign-in failed. Please try again.';
  } else if (error is TimeoutException) {
    message = 'This is taking too long. Please try again.';
  } else {
    message = 'Something went wrong. Please try again.';
  }
  return kDebugMode ? '$message ($error)' : message;
}
