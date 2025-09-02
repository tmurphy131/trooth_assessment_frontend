class OnboardingValidationResult {
  final String? firstNameError;
  final String? lastNameError;
  final String? roleError;
  const OnboardingValidationResult({this.firstNameError, this.lastNameError, this.roleError});
  bool get hasErrors => firstNameError != null || lastNameError != null || roleError != null;
}

OnboardingValidationResult validateOnboarding(String first, String last, String? role) {
  String? firstErr;
  String? lastErr;
  String? roleErr;

  if (first.trim().isEmpty) firstErr = 'First name required';
  if (last.trim().isEmpty) lastErr = 'Last name required';
  if (role == null) roleErr = 'Role required';

  // Basic character validation (letters, hyphen, apostrophe, space)
  final reg = RegExp(r"^[A-Za-z\-' ]+");
  if (first.isNotEmpty && !reg.hasMatch(first)) {
    firstErr = 'Invalid chars';
  }
  if (last.isNotEmpty && !reg.hasMatch(last)) {
    lastErr = 'Invalid chars';
  }
  return OnboardingValidationResult(firstNameError: firstErr, lastNameError: lastErr, roleError: roleErr);
}
