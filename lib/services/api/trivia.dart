part of '../api_service.dart';

// /    Trivia                                                          /
extension TriviaApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*  🎮  Trivia                                                          */
  /* ─────────────────────────────────────────────────────────────────── */

  // Single player runs as a server session: one question at a time, no answers
  // up front, graded and timed by the server (backend spec 001).

  Future<TriviaSessionState> triviaStartSingle({
    required String category,
    required String difficulty,
  }) async {
    const path = '/trivia/single/start';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(),
        body: jsonEncode({'category': category, 'difficulty': difficulty}));
    if (r.statusCode == 200) return TriviaSessionState.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw ApiException(r.statusCode, 'triviaStartSingle failed (${r.statusCode}) ${r.body}');
  }

  /// [selected] is null when the player's timer ran out.
  Future<TriviaSessionState> triviaAnswerSingle(
    String sessionId, {
    required int questionId,
    String? selected,
  }) async {
    final path = '/trivia/single/$sessionId/answer';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(),
        body: jsonEncode({'question_id': questionId, 'selected': selected}));
    if (r.statusCode == 200) return TriviaSessionState.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw ApiException(r.statusCode, 'triviaAnswerSingle failed (${r.statusCode}) ${r.body}');
  }

  Future<TriviaSessionState> triviaGraceSingle(String sessionId, {required bool use}) async {
    final path = '/trivia/single/$sessionId/grace';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode({'use': use}));
    if (r.statusCode == 200) return TriviaSessionState.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw ApiException(r.statusCode, 'triviaGraceSingle failed (${r.statusCode}) ${r.body}');
  }

  /// Ends the game (idempotent) and returns its result.
  Future<Map<String, dynamic>> triviaFinishSingle(String sessionId) async {
    final path = '/trivia/single/$sessionId/finish';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaFinishSingle failed (${r.statusCode}) ${r.body}');
  }

  Future<List<Map<String, dynamic>>> triviaGetLeaderboard({
    String? category,
    String? difficulty,
    int limit = 50,
  }) async {
    final params = <String>[];
    if (category != null) params.add('category=$category');
    if (difficulty != null) params.add('difficulty=$difficulty');
    params.add('limit=$limit');
    final path = '/trivia/leaderboard?${params.join('&')}';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(r.body));
    throw ApiException(r.statusCode, 'triviaGetLeaderboard failed (${r.statusCode}) ${r.body}');
  }

  /// Current (else upcoming, else most recent) leaderboard competition, or null.
  Future<Map<String, dynamic>?> triviaGetCompetition() async {
    const path = '/trivia/competition';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>?;
    throw ApiException(r.statusCode, 'triviaGetCompetition failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaCreateChallenge(Map<String, dynamic> payload) async {
    const path = '/trivia/challenges';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 403) throw PremiumRequiredException('Creating challenges is a premium feature.');
    throw ApiException(r.statusCode, 'triviaCreateChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<List<Map<String, dynamic>>> triviaListChallenges() async {
    const path = '/trivia/challenges';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(r.body));
    throw ApiException(r.statusCode, 'triviaListChallenges failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaGetChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaGetChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaAcceptChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId/accept';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaAcceptChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaDeclineChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId/decline';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaDeclineChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaCancelChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId';
    final r = await _http.delete(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaCancelChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaForfeitChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId/forfeit';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaForfeitChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaSubmitChallengeAnswer(
    String challengeId,
    Map<String, dynamic> answer,
  ) async {
    final path = '/trivia/challenges/$challengeId/answer';
    final payload = {'answer': answer};
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaSubmitChallengeAnswer failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaNudge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId/nudge';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaNudge failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaGetProfile(String userId) async {
    final path = '/trivia/profile/$userId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaGetProfile failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaGetConnections() async {
    const path = '/trivia/connections';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaGetConnections failed (${r.statusCode}) ${r.body}');
  }
}
