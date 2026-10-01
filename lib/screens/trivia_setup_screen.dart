import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'trivia_game_screen.dart';
import 'trivia_challenge_create_screen.dart';

enum TriviaMode { single, multiplayer }

const _kCategories = [
  ('old_testament', 'Old Testament'),
  ('new_testament', 'New Testament'),
  ('theology_doctrine', 'Theology & Doctrine'),
  ('discipleship_living', 'Discipleship & Living'),
  ('random', 'Random Mix'),
];

const _kDifficulties = [
  ('beginner', 'Beginner', 'Well-known Bible facts and core stories'),
  ('challenger', 'Challenger', 'Less common details and secondary characters'),
  ('expert', 'Expert', 'Obscure details and nuanced theology'),
];

class TriviaSetupScreen extends StatefulWidget {
  final TriviaMode mode;

  const TriviaSetupScreen({super.key, required this.mode});

  @override
  State<TriviaSetupScreen> createState() => _TriviaSetupScreenState();
}

class _TriviaSetupScreenState extends State<TriviaSetupScreen> {
  String _selectedCategory = 'old_testament';
  String _selectedDifficulty = 'beginner';
  int _selectedNumQuestions = 20; // multiplayer only
  bool _isLoading = false;

  Future<void> _startSinglePlayer() async {
    setState(() => _isLoading = true);
    try {
      final questions = await ApiService().triviaDrawQuestions(
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        count: 50,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TriviaGameScreen(
            questions: questions,
            category: _selectedCategory,
            difficulty: _selectedDifficulty,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load questions: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToMultiplayerCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TriviaChallengeCreateScreen(
          category: _selectedCategory,
          difficulty: _selectedDifficulty,
          numQuestions: _selectedNumQuestions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSingle = widget.mode == TriviaMode.single;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: Text(
          isSingle ? 'Single Player Setup' : 'Multiplayer Setup',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Category'),
            const SizedBox(height: 10),
            ..._kCategories.map((c) => _choiceRow(
              label: c.$2,
              value: c.$1,
              groupValue: _selectedCategory,
              onTap: () => setState(() => _selectedCategory = c.$1),
            )),
            const SizedBox(height: 24),
            _sectionLabel('Difficulty'),
            const SizedBox(height: 10),
            ..._kDifficulties.map((d) => _choiceRow(
              label: d.$2,
              subtitle: d.$3,
              value: d.$1,
              groupValue: _selectedDifficulty,
              onTap: () => setState(() => _selectedDifficulty = d.$1),
            )),
            if (!isSingle) ...[
              const SizedBox(height: 24),
              _sectionLabel('Number of Questions'),
              const SizedBox(height: 10),
              ...[20, 25, 30].map((n) => _choiceRow(
                label: '$n questions',
                value: n.toString(),
                groupValue: _selectedNumQuestions.toString(),
                onTap: () => setState(() => _selectedNumQuestions = n),
              )),
            ],
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (isSingle ? _startSinglePlayer : _goToMultiplayerCreate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        isSingle ? 'Start Game' : 'Choose Opponent',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
        fontSize: 14,
      ),
    );
  }

  Widget _choiceRow({
    required String label,
    String? subtitle,
    required String value,
    required String groupValue,
    required VoidCallback onTap,
  }) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFD700).withOpacity(0.12) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFFFD700) : Colors.grey[800]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFFFFD700) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? const Color(0xFFFFD700) : Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Poppins',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
