import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Placeholder list of spiritual gift definitions.
/// Later this can be fetched from backend metadata endpoint.
class SpiritualGiftsDefinitionsScreen extends StatefulWidget {
  const SpiritualGiftsDefinitionsScreen({super.key});
  @override
  State<SpiritualGiftsDefinitionsScreen> createState() => _SpiritualGiftsDefinitionsScreenState();
}

class _SpiritualGiftsDefinitionsScreenState extends State<SpiritualGiftsDefinitionsScreen> {
  final TextEditingController _search = TextEditingController();
  final _api = ApiService();
  List<Map<String, String>> _all = [];
  bool _loading = true;
  bool _error = false;
  static final List<Map<String, String>> _fallback = [
    {
      'slug': 'teaching',
      'name': 'Teaching',
      'desc': 'Ability to explain and clarify truth so others grow in understanding and obedience.',
      'refs': 'Acts 18:24-28; Romans 12:7'
    },
    {
      'slug': 'leadership',
      'name': 'Leadership',
      'desc': 'Capacity to cast vision, mobilize, and guide people toward God-honoring goals.',
      'refs': 'Romans 12:8; Hebrews 13:7'
    },
    {
      'slug': 'mercy',
      'name': 'Mercy',
      'desc': 'Gifted empathy and compassion that moves to restorative action for the hurting.',
      'refs': 'Romans 12:8; Luke 10:33-37'
    },
    {
      'slug': 'service',
      'name': 'Service',
      'desc': 'Joyful capacity to meet practical needs and free others to function effectively.',
      'refs': 'Romans 12:7; Acts 6:1-7'
    },
    {
      'slug': 'encouragement',
      'name': 'Encouragement',
      'desc': 'Ability to strengthen, comfort, and urge others toward faithfulness.',
      'refs': 'Romans 12:8; Acts 14:21-22'
    },
    {
      'slug': 'giving',
      'name': 'Giving',
      'desc': 'Spirit-led impulse to generously resource kingdom work with unusual joy and sacrifice.',
      'refs': 'Romans 12:8; 2 Corinthians 8:1-5'
    },
    {
      'slug': 'wisdom',
      'name': 'Wisdom',
      'desc': 'Insight to apply knowledge and scripture to complex, gray, or pivotal situations.',
      'refs': '1 Corinthians 12:8; James 3:17'
    },
    {
      'slug': 'knowledge',
      'name': 'Knowledge',
      'desc': 'Ability to grasp, synthesize, or recall spiritual truth for timely use.',
      'refs': '1 Corinthians 12:8; Colossians 1:9-10'
    },
    {
      'slug': 'shepherding',
      'name': 'Shepherding',
      'desc': 'Capacity to guide, guard, and grow a group toward maturity over time.',
      'refs': 'Ephesians 4:11-12; 1 Peter 5:2'
    },
    {
      'slug': 'evangelism',
      'name': 'Evangelism',
      'desc': 'Spirit-empowered ability to communicate the gospel clearly and fruitfully.',
      'refs': 'Ephesians 4:11; Acts 8:5-12'
    },
    {
      'slug': 'faith',
      'name': 'Faith',
      'desc': 'Extraordinary confidence in God’s promises that inspires bold steps of obedience.',
      'refs': '1 Corinthians 12:9; Hebrews 11'
    },
    {
      'slug': 'hospitality',
      'name': 'Hospitality',
      'desc': 'Capacity to create welcoming spaces that foster kingdom relational growth.',
      'refs': '1 Peter 4:9-10; Romans 12:13'
    },
  ];

  String _query = '';

  static List<Map<String,String>> _cached = [];

  @override
  void initState() {
    super.initState();
    _search.addListener(() { setState(() => _query = _search.text.trim().toLowerCase()); });
    _init();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Use cached if already fetched during app session.
    if (_cached.isNotEmpty) {
      setState(() { _all = _cached; _loading = false; });
      return;
    }
    try {
      final defs = await _api.getSpiritualGiftsDefinitions();
      if (!mounted) return;
      if (defs.isEmpty) {
        // 404 or empty -> fallback
        _all = _fallback;
      } else {
        _all = defs.map((d) => {
          'slug': (d['slug'] ?? d['gift_slug'] ?? '').toString(),
          'name': (d['name'] ?? d['display_name'] ?? d['gift_name'] ?? d['slug'] ?? 'Gift').toString(),
          'desc': (d['description'] ?? d['desc'] ?? 'No description provided.').toString(),
          'refs': (d['scripture_refs'] ?? d['refs'] ?? '').toString(),
        }).cast<Map<String,String>>().toList();
        // Attempt ordering if full set present.
        _applyCanonicalOrdering();
        _cached = _all;
      }
      setState(() { _loading = false; });
    } catch (e) {
      if (!mounted) return;
      _all = _fallback;
      setState(() { _loading = false; _error = true; });
    }
  }

  // Orders definitions to match canonical MAP sequence if all 24 are present.
  void _applyCanonicalOrdering() {
    // Canonical ordered names/slugs from spec (using expected display names).
    const ordered = [
      'Leadership','Pastor/Shepherd','Discernment','Exhortation','Hospitality','Prophecy','Knowledge','Miracles','Healing','Helps','Mercy','Evangelism','Faith','Teaching','Wisdom','Intercession','Service','Tongues & Interpretation','Giving','Missionary','Apostleship','Craftsmanship','Administration','Music/Worship'
    ];
    if (_all.length < 24) return; // Only enforce when full set delivered.
    // Build lookup by lowercased normalized name (strip punctuation & spaces & slashes & ampersands for robustness).
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final map = {for (final m in _all) norm(m['name'] ?? m['slug'] ?? ''): m};
    final reordered = <Map<String,String>>[];
    for (final name in ordered) {
      final n = norm(name);
      final found = map[n];
      if (found != null) reordered.add(found);
    }
    // If we matched at least half (robust), append any stragglers not already included
    if (reordered.length >= 12) {
      final existingSet = reordered.map((e) => e['slug']).toSet();
      reordered.addAll(_all.where((m) => !existingSet.contains(m['slug'])));
      _all = reordered;
    }
  }

  List<Map<String, String>> get _filtered {
    final list = _all;
    if (_query.isEmpty) return list;
    return list.where((m) {
      final hay = (m['name']! + ' ' + m['desc']! + ' ' + (m['slug'] ?? '')).toLowerCase();
      return hay.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Gift Definitions', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : items.isEmpty
                    ? _EmptyState(query: _query, error: _error)
                    : RefreshIndicator(
                        onRefresh: _init,
                        backgroundColor: Colors.grey[900],
                        color: Colors.amber,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[850]),
                          itemBuilder: (_, i) => _DefinitionTile(data: items[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: Colors.grey[900], boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6)]),
      child: TextField(
        controller: _search,
        style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        cursorColor: Colors.amber,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[850],
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          hintText: 'Search gifts...',
          hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Poppins'),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.amber),
          ),
        ),
      ),
    );
  }
}

class _DefinitionTile extends StatelessWidget {
  final Map<String, String> data;
  const _DefinitionTile({required this.data});
  @override
  Widget build(BuildContext context) {
    return _ExpandableDefinition(data: data, onOpenFull: () => _openDetail(context));
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _DefinitionDetail(data: data),
    );
  }
}

class _DefinitionDetail extends StatelessWidget {
  final Map<String, String> data;
  const _DefinitionDetail({required this.data});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(data['name']!, style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 14),
            Text(data['desc']!, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', height: 1.4)),
            const SizedBox(height: 14),
            Text('Scripture References', style: TextStyle(color: Colors.grey[300], fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(data['refs']!, style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 13)),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.close),
                label: const Text('Close', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ExpandableDefinition extends StatefulWidget {
  final Map<String, String> data;
  final VoidCallback onOpenFull;
  const _ExpandableDefinition({required this.data, required this.onOpenFull});
  @override
  State<_ExpandableDefinition> createState() => _ExpandableDefinitionState();
}

class _ExpandableDefinitionState extends State<_ExpandableDefinition> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.data['name'] ?? 'Gift';
    final desc = widget.data['desc'] ?? '';
    final refs = widget.data['refs'] ?? '';
    final preview = desc.length > 140 && !_expanded ? desc.substring(0, 137).trimRight() + '…' : desc;
    return Container(
      color: Colors.black,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        onLongPress: widget.onOpenFull,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Text(name, style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(preview, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', height: 1.3)),
                        const SizedBox(height: 6),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 180),
                          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          firstChild: Text(refs, style: TextStyle(color: Colors.grey[500], fontFamily: 'Poppins', fontSize: 11)),
                          secondChild: Text(refs, style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12)),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: _expanded ? 'Collapse definition for $name' : 'Expand definition for $name',
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                      label: Text(_expanded ? 'Less' : 'More', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onOpenFull,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Open', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  final bool error;
  const _EmptyState({required this.query, this.error = false});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, color: Colors.white24, size: 56),
            const SizedBox(height: 18),
            Text(
              error
                  ? 'Failed to load definitions. Showing fallback.'
                  : (query.isEmpty ? 'No definitions available yet.' : 'No matches for "$query"'),
              style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'These are placeholder definitions and will be replaced with authoritative content.',
              style: TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
