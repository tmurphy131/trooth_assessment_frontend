import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _kDifficulties = [
  ('beginner', 'Beginner'),
  ('challenger', 'Challenger'),
  ('expert', 'Expert'),
];

const _kCategories = [
  (null, 'All Categories'),
  ('old_testament', 'Old Testament'),
  ('new_testament', 'New Testament'),
  ('theology_doctrine', 'Theology & Doctrine'),
  ('discipleship_living', 'Discipleship & Living'),
];

class TriviaLeaderboardScreen extends StatefulWidget {
  const TriviaLeaderboardScreen({super.key});

  @override
  State<TriviaLeaderboardScreen> createState() => _TriviaLeaderboardScreenState();
}

class _TriviaLeaderboardScreenState extends State<TriviaLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;
  String? _category;
  final Map<int, List<Map<String, dynamic>>> _cache = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to Challenger (index 1) — the 60-day competition tier
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentDifficulty => _kDifficulties[_tabController.index].$1;

  Future<void> _load() async {
    final tab = _tabController.index;
    setState(() { _isLoading = true; _error = null; });
    try {
      final entries = await _api.triviaGetLeaderboard(
        category: _category,
        difficulty: _currentDifficulty,
      );
      if (mounted) {
        setState(() {
          _cache[tab] = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> get _entries => _cache[_tabController.index] ?? [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: const Text(
          'Leaderboard',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD700)),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          tabs: const [
            Tab(text: 'Beginner'),
            Tab(text: 'Challenger'),
            Tab(text: 'Expert'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          if (_tabController.index == 1) _buildCompetitionBadge(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButton<String?>(
        value: _category,
        isExpanded: true,
        dropdownColor: Colors.grey[850],
        style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13),
        underline: const SizedBox.shrink(),
        items: _kCategories.map((c) => DropdownMenuItem(
          value: c.$1,
          child: Text(c.$2, overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (v) { setState(() => _category = v); _load(); },
      ),
    );
  }

  Widget _buildCompetitionBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFFD700).withOpacity(0.08),
      child: Row(
        children: const [
          Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 15),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '60-Day Launch Competition · Challenger · All-time best score per player',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text(
          'No scores yet.\nBe the first on the leaderboard!',
          style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      itemBuilder: (_, i) => _buildEntry(_entries[i], i),
    );
  }

  Widget _buildEntry(Map<String, dynamic> entry, int index) {
    final rank = entry['rank'] as int? ?? index + 1;
    final name = entry['display_name'] as String? ?? 'Unknown';
    final score = entry['score'] as int? ?? 0;
    final streak = entry['streak_length'] as int? ?? 0;

    Color rankColor = Colors.white54;
    Widget rankWidget = Text(
      '#$rank',
      style: TextStyle(color: rankColor, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14),
    );

    if (rank == 1) rankWidget = const Text('🥇', style: TextStyle(fontSize: 22));
    if (rank == 2) rankWidget = const Text('🥈', style: TextStyle(fontSize: 22));
    if (rank == 3) rankWidget = const Text('🥉', style: TextStyle(fontSize: 22));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: rank <= 3 ? const Color(0xFFFFD700).withOpacity(0.07) : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank <= 3 ? const Color(0xFFFFD700).withOpacity(0.3) : Colors.grey[800]!,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 36, child: Center(child: rankWidget)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toString(),
                style: const TextStyle(color: Color(0xFFFFD700), fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'streak: $streak',
                style: const TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
