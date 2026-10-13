import '../services/api_service.dart';
import 'errors.dart';

/// User-facing text for a failed agreement creation, chosen by status code only
/// (Principle XII; backend spec 007 contract).
String agreementCreateErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 403:
        return "This apprentice isn't connected to you anymore. Refresh and try again.";
      case 422:
        return 'Choose an apprentice or enter an email.';
    }
  }
  return friendlyError(error);
}
