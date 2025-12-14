/// Utilities for working with assessment metadata across the app.
library assessments_utils;

bool isSpiritualGiftsAssessment(Map<String, dynamic> assessment) {
  // Try several potential fields that may identify the template/category
  final keys = <String?>[
    assessment['template_key']?.toString(),
    assessment['template_id']?.toString(),
    assessment['template']?.toString(),
    assessment['template_name']?.toString(),
    assessment['category']?.toString(),
    assessment['name']?.toString(),
  ];
  final haystack = keys.whereType<String>().map((s) => s.toLowerCase()).join('|');
  if (haystack.isEmpty) return false;

  // Direct key match used by our backend
  if (haystack.contains('spiritual_gifts_v1')) return true;
  // Common slugs/names
  if (haystack.contains('spiritual-gifts') || haystack.contains('spiritual_gifts')) return true;
  // Fuzzy: contains both words somewhere
  return haystack.contains('spiritual') && haystack.contains('gift');
}
