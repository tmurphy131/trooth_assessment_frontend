import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'trivia_challenge_detail_screen.dart';

class TriviaChallengeCreateScreen extends StatefulWidget {
  final String category;
  final String difficulty;
  final int numQuestions;

  const TriviaChallengeCreateScreen({
    super.key,
    required this.category,
    required this.difficulty,
    required this.numQuestions,
  });

  @override
  State<TriviaChallengeCreateScreen> createState() => _TriviaChallengeCreateScreenState();
}

class _TriviaChallengeCreateScreenState extends State<TriviaChallengeCreateScreen> {
  final _api = ApiService();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _recentOpponents = [];
  bool _isLoadingConnections = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    try {
      final data = await _api.triviaGetConnections();
      if (mounted) {
        setState(() {
          _connections = List<Map<String, dynamic>>.from(data['connections'] ?? []);
          _recentOpponents = List<Map<String, dynamic>>.from(data['recent_opponents'] ?? []);
          _isLoadingConnections = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingConnections = false);
    }
  }

  Future<void> _createChallenge(String email) async {
    setState(() => _isCreating = true);
    try {
      final challenge = await _api.triviaCreateChallenge({
        'challenged_email': email,
        'category': widget.category,
        'difficulty': widget.difficulty,
        'num_questions': widget.numQuestions,
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TriviaChallengeDetailScreen(
            challengeId: challenge['id'] as String,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create challenge: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: const Text(
          'Choose Opponent',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isCreating
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFFD700)),
                  SizedBox(height: 16),
                  Text('Creating challenge...', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingConnections)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                    ))
                  else ...[
                    if (_connections.isNotEmpty) ...[
                      _sectionLabel('Mentors & Apprentices'),
                      const SizedBox(height: 10),
                      ..._connections.map((c) => _personCard(c)),
                      const SizedBox(height: 20),
                    ],
                    if (_recentOpponents.isNotEmpty) ...[
                      _sectionLabel('Recent Opponents'),
                      const SizedBox(height: 10),
                      ..._recentOpponents.map((c) => _personCard(c)),
                      const SizedBox(height: 20),
                    ],
                  ],
                  _sectionLabel('Challenge by Email'),
                  const SizedBox(height: 10),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                          decoration: InputDecoration(
                            hintText: "Opponent's email address",
                            hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Poppins'),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFFFD700)),
                            ),
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter an email address';
                            if (!v.contains('@')) return 'Enter a valid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState?.validate() == true) {
                                _createChallenge(_emailController.text.trim());
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'Send Challenge',
                              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFFFD700),
        fontFamily: 'Poppins',
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  Widget _personCard(Map<String, dynamic> person) {
    final name = person['name'] as String? ?? '';
    final email = person['email'] as String? ?? '';
    final relation = person['relation'] as String? ?? '';
    final relLabel = relation == 'mentor' ? 'Mentor' : relation == 'apprentice' ? 'Apprentice' : 'Recent';

    return GestureDetector(
      onTap: () => _createChallenge(email),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[800],
              radius: 20,
              child: Text(
                (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(email, style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(relLabel, style: const TextStyle(color: Colors.blueAccent, fontFamily: 'Poppins', fontSize: 11)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.send, color: Color(0xFFFFD700), size: 18),
          ],
        ),
      ),
    );
  }
}
