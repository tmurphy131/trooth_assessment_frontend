part of '../api_service.dart';

// /    Trivia                                                          /
extension TriviaApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*  🎮  Trivia                                                          */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<List<Map<String, dynamic>>> triviaDrawQuestions({
    required String category,
    required String difficulty,
    int count = 20,
  }) async {
    final path = '/trivia/questions/draw?category=${Uri.encodeQueryComponent(category)}&difficulty=$difficulty&count=$count';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(r.body));
    throw ApiException(r.statusCode, 'triviaDrawQuestions failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaSubmitSingleGame(Map<String, dynamic> payload) async {
    const path = '/trivia/single/submit';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaSubmitSingleGame failed (${r.statusCode}) ${r.body}');
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
