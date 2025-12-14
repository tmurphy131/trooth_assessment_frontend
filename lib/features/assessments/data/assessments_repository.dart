import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../../services/api_service.dart';
import '../models/submission_models.dart';
import '../models/mentor_report_v2.dart';

class AssessmentsRepository {
  final ApiService _api;
  AssessmentsRepository(this._api);

  // Tiny in-memory caches
  final Map<String, SubmissionDetail> _submissionCache = {};
  final Map<String, MentorReportV2> _reportCache = {};

  Future<SubmissionDetail> getSubmissionDetail(String assessmentId, {bool force = false}) async {
    if (!force && _submissionCache.containsKey(assessmentId)) return _submissionCache[assessmentId]!;
    final raw = await _api.fetchSubmissionDetail(assessmentId: assessmentId);
    // The mentor detail endpoint returns the Assessment with answers and scores; adapt to expected shape if needed.
    // Build a tolerant detail object. If questions not present, synthesize simple question items from answers map.
    Map<String, dynamic> detail = (raw['submission'] as Map<String, dynamic>?) ?? raw;
    if (!(detail.containsKey('questions'))) {
      final answers = (detail['answers'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final apprentice = {
        'id': detail['apprentice_id'] ?? detail['apprentice']?['id'] ?? '',
        'name': detail['apprentice_name'] ?? detail['apprentice']?['name'] ?? 'Apprentice',
      };
      final questions = answers.entries.map((e) => {
            'id': e.key,
            'type': 'open',
            'text': e.key, // Without template context, we label with the key
            'apprentice_answer': e.value?.toString(),
          }).toList();
      detail = {
        'submission_id': detail['id'] ?? assessmentId,
        'id': detail['id'] ?? assessmentId,
        'apprentice': apprentice,
        'submitted_at': detail['created_at'] ?? detail['submitted_at'],
        'questions': questions,
      };
    }
    final model = SubmissionDetail.fromJson(detail);
    _submissionCache[assessmentId] = model;
    return model;
  }

  Future<MentorReportV2> getMentorReportV2(String assessmentId, {bool force = false}) async {
    if (!force && _reportCache.containsKey(assessmentId)) return _reportCache[assessmentId]!;
    final raw = await _api.fetchMentorReportV2Json(assessmentId: assessmentId);
    // mentor_report_v2 might be nested under the Assessment
    final blob = raw['mentor_report_v2'] ?? (raw['scores']?['mentor_blob_v2']);
    if (blob == null) {
      // fallback to mock
      final text = await rootBundle.loadString('assets/mock/mentor_report_v2.json');
      final json = jsonDecode(text) as Map<String, dynamic>;
      final model = MentorReportV2.fromJson(json);
      _reportCache[assessmentId] = model;
      return model;
    }
    final model = MentorReportV2.fromJson((blob as Map).cast<String, dynamic>());
    _reportCache[assessmentId] = model;
    return model;
  }
}
