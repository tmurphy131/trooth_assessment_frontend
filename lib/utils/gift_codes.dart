/// Canonical gift code `TROOTH-XXXX-XXXX` from whatever the apprentice typed, or null if
/// it can't be one. The backend matches the exact form, dashes included.
String? normalizeGiftCode(String raw) {
  var s = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (s.startsWith('TROOTH') && s.length > 8) s = s.substring(6);
  if (s.length != 8) return null;
  return 'TROOTH-${s.substring(0, 4)}-${s.substring(4)}';
}
