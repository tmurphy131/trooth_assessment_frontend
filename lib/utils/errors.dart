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
  } else if (error is ApiException) {
    message = switch (error.statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      403 => "You don't have access to this.",
      404 => "We couldn't find that. It may have been removed.",
      409 => 'That conflicts with a recent change. Please refresh and try again.',
      426 => 'Please update the app to keep playing trivia.',
      429 => 'Too many requests. Please wait a moment and try again.',
      >= 500 => 'The server had a problem. Please try again shortly.',
      _ => 'Something went wrong. Please try again.',
    };
  } else if (error is FirebaseAuthException) {
    message = error.message ?? 'Sign-in failed. Please try again.';
  } else if (error is TimeoutException) {
    message = 'This is taking too long. Please try again.';
  } else {
    message = 'Something went wrong. Please try again.';
  }
  return kDebugMode ? '$message ($error)' : message;
}
