import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../models/spiritual_gifts_models.dart';
import '../services/api_service.dart';
import '../widgets/version_badge.dart';
import 'spiritual_gifts_definitions_screen.dart';
import '../utils/haptics.dart';
import 'spiritual_gifts_full_report_screen.dart';

/// Mentor view: pick an apprentice, view latest gifts result, navigate to history.
class MentorSpiritualGiftsScreen extends StatefulWidget {
  final String? initialApprenticeId;
  final String? initialApprenticeName; // reserved for future UI polish
  const MentorSpiritualGiftsScreen({super.key, this.initialApprenticeId, this.initialApprenticeName});

  @override
  State<MentorSpiritualGiftsScreen> createState() => _MentorSpiritualGiftsScreenState();
}

class _MentorSpiritualGiftsScreenState extends State<MentorSpiritualGiftsScreen> {
  final _api = ApiService();
  List<dynamic> _apprentices = [];
  String? _selectedApprenticeId;
  SpiritualGiftsResult? _latest;
  bool _loadingList = true;
  bool _loadingResult = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApprentices();
  }

  Future<void> _loadApprentices() async {
    setState(() { _loadingList = true; _error = null; });
    try {
      final list = await _api.listApprentices();
      setState(() {
        _apprentices = list;
        _loadingList = false;
      });
      await _restoreLastSelection();
    } catch (e) {
      setState(() { _loadingList = false; _error = 'Failed to load apprentices: $e'; });
    }
  }

  Future<void> _restoreLastSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Prefer explicitly provided apprentice if valid
      final provided = widget.initialApprenticeId;
      if (provided != null && _apprentices.any((a) => a['id'].toString() == provided)) {
        setState(() { _selectedApprenticeId = provided; });
        await _saveLast(provided);
        _loadLatest(provided);
        return;
      }
      // Otherwise fall back to last selection from preferences
      final last = prefs.getString('last_apprentice_id');
      if (last != null && _apprentices.any((a) => a['id'].toString() == last)) {
        setState(() { _selectedApprenticeId = last; });
        _loadLatest(last);
      }
    } catch (_) {/* ignore persistence errors */}
  }

  Future<void> _loadLatest(String apprenticeId) async {
    setState(() { _loadingResult = true; _error = null; });
    try {
      final json = await _api.mentorGetApprenticeSpiritualGiftsLatest(apprenticeId);
      if (json.isEmpty) {
        setState(() { _latest = null; _loadingResult = false; });
      } else {
        setState(() { _latest = SpiritualGiftsResult.fromJson(json); _loadingResult = false; });
      }
    } catch (e) {
      setState(() { _loadingResult = false; _error = 'Failed to load latest result: $e'; });
    }
  }

  void _openHistory() {
    if (_selectedApprenticeId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MentorSpiritualGiftsHistoryScreen(apprenticeId: _selectedApprenticeId!),
      ),
    );
  }

  void _openDefinitions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpiritualGiftsDefinitionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Mentor Gifts', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined, color: Colors.white70),
            tooltip: 'Definitions',
            onPressed: _openDefinitions,
          ),
          if (_selectedApprenticeId != null)
            Semantics(
              label: 'Open apprentice gifts history',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.history, color: Colors.amber),
                onPressed: _openHistory,
                tooltip: 'History',
              ),
            )
        ],
      ),
    body: _loadingList
      ? const _MentorLoadingSkeleton(showPicker: true)
      : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadApprentices,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildApprenticePicker(),
        Expanded(child: _buildResultArea()),
      ],
    );
  }

  Widget _buildApprenticePicker() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(color: Colors.grey[900], boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)]),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Select apprentice dropdown',
              hint: 'Choose an apprentice to view their spiritual gifts report',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedApprenticeId,
                  dropdownColor: Colors.grey[900],
                  hint: const Text('Select Apprentice', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: _apprentices.map((a) {
                    final id = a['id']?.toString() ?? '';
                    final name = a['name']?.toString() ?? 'Unnamed';
                    return DropdownMenuItem(
                      value: id,
                      child: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() { _selectedApprenticeId = val; _latest = null; });
                    if (val != null) {
                      Haptics.selection();
                      _loadLatest(val);
                      _saveLast(val);
                    }
                  },
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _loadApprentices,
            icon: const Icon(Icons.refresh, color: Colors.amber),
            tooltip: 'Refresh list',
          )
        ],
      ),
    );
  }

  Widget _buildResultArea() {
    if (_selectedApprenticeId == null) {
      return const Center(
        child: Text('Pick an apprentice to view results.', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
      );
    }
    if (_loadingResult) {
      return const _MentorLoadingSkeleton(showPicker: false);
    }
    if (_latest == null) {
      return const Center(
        child: Text('No submission yet.', style: TextStyle(color: Colors.white54, fontFamily: 'Poppins')),
      );
    }
    return _MentorLatestResultView(result: _latest!, apprenticeId: _selectedApprenticeId!);
  }

  Future<void> _saveLast(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_apprentice_id', id);
    } catch (_) {/* ignore */}
  }
}

class _MentorLatestResultView extends StatefulWidget {
  final SpiritualGiftsResult result;
  final String apprenticeId;
  const _MentorLatestResultView({required this.result, required this.apprenticeId});
  @override
  State<_MentorLatestResultView> createState() => _MentorLatestResultViewState();
}

class _MentorLatestResultViewState extends State<_MentorLatestResultView> {
  final _api = ApiService();
  bool _emailing = false;
  DateTime? _retryAt;
  Timer? _tick;
  Future<void> _emailMentor() async {
    if (_emailing) return;
    if (_retryAt != null && DateTime.now().isBefore(_retryAt!)) {
      _snack('Wait ${_remaining()}s before retrying.', error: true);
      return;
    }
    setState(() => _emailing = true);
    try {
      await _api.mentorEmailSpiritualGiftsReport(widget.apprenticeId);
      _snack('Email to mentor requested.');
      Haptics.success();
    } catch (e) {
      if (e.toString().contains('RATE_LIMIT')) {
        final reg = RegExp(r'retry_after_seconds[=:\s]+(\d+)');
        final m = reg.firstMatch(e.toString());
        if (m != null) {
          final secs = int.tryParse(m.group(1)!);
          if (secs != null) {
            _retryAt = DateTime.now().add(Duration(seconds: secs));
            _startTicker();
          }
        }
      }
      final msg = e.toString().contains('RATE_LIMIT')
          ? 'Rate limit hit. ${_retryAt != null ? 'Wait ${_remaining()}s.' : 'Try again later.'}'
          : 'Failed to request email: $e';
      _snack(msg, error: true);
    } finally {
      if (mounted) setState(() => _emailing = false);
    }
  }
  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_retryAt == null) { t.cancel(); return; }
      if (DateTime.now().isAfter(_retryAt!)) { setState(() => _retryAt = null); t.cancel(); } else { setState(() {}); }
    });
  }
  String _remaining() {
    if (_retryAt == null) return '0';
    final s = _retryAt!.difference(DateTime.now()).inSeconds;
    return s < 0 ? '0' : s.toString();
  }
  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: error ? Colors.redAccent : Colors.grey[850],
    ));
  }
  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final truncated = result.topGifts;
    final expanded = result.topGiftsExpanded;
    final hasTies = expanded.length > truncated.length;
    final tieExtras = hasTies ? expanded.where((e) => !truncated.any((t) => t.giftSlug == e.giftSlug)).toList() : const <GiftScore>[];
    final thirdScore = expanded.length >= 3 ? expanded[2].rawScore : (expanded.isNotEmpty ? expanded.last.rawScore : 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
      children: [
        // Report Header (mentor view variant)
        Semantics(
          header: true,
          child: const Text('Spiritual Gifts Report', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VersionBadge(versionLabel: 'v${result.templateVersion}', padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Apprentice name could be enhanced if API provides it alongside result; placeholder slug or id omitted here.
                  Text(
                    'Assessed: ${_formatDate(result.submittedAt.toLocal())}',
                    style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    label: 'Assessment description',
                    readOnly: true,
                    child: Text(
                      'This Spiritual Gifts Assessment helps identify the ways God has uniquely equipped the apprentice to serve the church and others. Results highlight strongest gifts and provide definitions to help in understanding and application.',
                      style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12, height: 1.4, fontFamily: 'Poppins'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SpiritualGiftsDefinitionsScreen()),
                        );
                      },
                      icon: const Icon(Icons.menu_book_outlined, size: 16, color: Colors.amber),
                      label: const Text('View Gift Definitions', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            button: true,
            label: _emailing
                ? 'Sending PDF report'
                : (_retryAt != null && DateTime.now().isBefore(_retryAt!)
                    ? 'Email rate limited. Wait ${_remaining()} seconds'
                    : 'Email myself a PDF copy of this apprentice\'s spiritual gifts report'),
            child: ElevatedButton.icon(
              onPressed: _emailing || (_retryAt != null && DateTime.now().isBefore(_retryAt!)) ? null : _emailMentor,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _emailing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                _emailing
                    ? 'Sending...'
                    : _retryAt != null && DateTime.now().isBefore(_retryAt!)
                        ? 'Wait ${_remaining()}s'
                        : 'Email PDF',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            const Text('Top Gifts', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
            if (hasTies) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('Tie at 3rd', style: TextStyle(color: Colors.amber[200], fontSize: 11, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hasTies
              ? 'Apprentice has multiple gifts sharing the 3rd-place score. All are shown.'
              : 'Top three apprentice gifts.',
          style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: truncated.map((g) => _GiftBadge(gift: g)).toList()),
        if (hasTies) ...[
          const SizedBox(height: 16),
          Text('Also tied at 3rd', style: TextStyle(color: Colors.amber[300], fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: tieExtras.map((g) => _GiftBadge(gift: g)).toList()),
        ],
        const SizedBox(height: 32),
        const Text('Full Ranking', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          hasTies
              ? 'Gifts scoring at least ${thirdScore.toStringAsFixed(1)} are considered tied for 3rd.'
              : 'Ordered by score (descending). Top three highlighted.',
          style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: result.gifts.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[800]),
            itemBuilder: (context, i) {
              final g = result.gifts[i];
              final isTieBoundary = hasTies && g.rawScore == thirdScore;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: i < 3 ? Colors.amber : Colors.grey[800],
                  child: Text('${g.rank}', style: TextStyle(color: i < 3 ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(g.displayName ?? _humanize(g.giftSlug), style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                subtitle: Text(
                  '${(g.normalized * 100).toStringAsFixed(1)}% • Raw ${g.rawScore.toStringAsFixed(1)}${isTieBoundary ? '  (3rd place score)' : ''}',
                  style: TextStyle(color: isTieBoundary ? Colors.amber[300] : Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                ),
              );
            },
        ),
      ],
    );
  }
  static String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';
  static String _humanize(String slug) => slug.split('_').map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1)).join(' ');
}

/// Mentor history view using apprentice-specific endpoints.
class MentorSpiritualGiftsHistoryScreen extends StatefulWidget {
  final String apprenticeId;
  const MentorSpiritualGiftsHistoryScreen({super.key, required this.apprenticeId});

  @override
  State<MentorSpiritualGiftsHistoryScreen> createState() => _MentorSpiritualGiftsHistoryScreenState();
}

class _MentorSpiritualGiftsHistoryScreenState extends State<MentorSpiritualGiftsHistoryScreen> {
  final _api = ApiService();
  final List<SpiritualGiftsResult> _items = [];
  String? _nextCursor;
  bool _initialLoading = true;
  bool _pageLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() { _initialLoading = true; _error = null; });
    try {
      final json = await _api.mentorGetApprenticeSpiritualGiftsHistory(widget.apprenticeId, limit: 10);
      final page = SpiritualGiftsHistoryPage.fromJson(json);
      setState(() { _items..clear()..addAll(page.items); _nextCursor = page.nextCursor; _initialLoading = false; });
    } catch (e) {
      setState(() { _initialLoading = false; _error = 'Failed: $e'; });
    }
  }

  Future<void> _loadMore() async {
    if (_pageLoading || _nextCursor == null) return;
    setState(() => _pageLoading = true);
    try {
      final json = await _api.mentorGetApprenticeSpiritualGiftsHistory(widget.apprenticeId, cursor: _nextCursor, limit: 10);
      final page = SpiritualGiftsHistoryPage.fromJson(json);
      setState(() { _items.addAll(page.items); _nextCursor = page.nextCursor; });
    } catch (e) {
      _snack('Load more failed: $e', error: true);
    } finally { setState(() => _pageLoading = false); }
  }

  Future<void> _refresh() async {
    try {
      final json = await _api.mentorGetApprenticeSpiritualGiftsHistory(widget.apprenticeId, limit: 10);
      final page = SpiritualGiftsHistoryPage.fromJson(json);
      setState(() { _items..clear()..addAll(page.items); _nextCursor = page.nextCursor; });
    } catch (e) { _snack('Refresh failed: $e', error: true); }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: error ? Colors.redAccent : Colors.grey[850],
    ));
  }

  void _openDetail(SpiritualGiftsResult r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _MentorHistoryDetail(result: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Apprentice Gifts History', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) return const Center(child: CircularProgressIndicator(color: Colors.amber));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitial,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: const Text('Retry'),
            )
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        backgroundColor: Colors.grey[900],
        color: Colors.amber,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('No submissions yet.', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      backgroundColor: Colors.grey[900],
      color: Colors.amber,
      child: ListView.builder(
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            if (_nextCursor == null) return const SizedBox(height: 70);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: _pageLoading
                    ? const CircularProgressIndicator(color: Colors.amber)
                    : ElevatedButton(
                        onPressed: _loadMore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Load More', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                      ),
              ),
            );
          }
          final r = _items[index];
          return _MentorHistoryItem(result: r, onTap: () => _openDetail(r));
        },
      ),
    );
  }
}

class _GiftBadge extends StatelessWidget {
  final GiftScore gift;
  const _GiftBadge({required this.gift});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('#${gift.rank}', style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(gift.displayName ?? _humanize(gift.giftSlug), style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${(gift.normalized * 100).toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 11)),
        ],
      ),
    );
  }
  static String _humanize(String slug) => slug.split('_').map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1)).join(' ');
}

class _MentorHistoryItem extends StatelessWidget {
  final SpiritualGiftsResult result;
  final VoidCallback onTap;
  const _MentorHistoryItem({required this.result, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final date = result.submittedAt.toLocal();
    final hasTie = result.topGiftsExpanded.length > result.topGifts.length;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[850]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Text('v${result.templateVersion}', style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_topGiftNames(result), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${date.month}/${date.day}/${date.year}', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12)),
                      if (hasTie) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: const Text('Tie 3rd', style: TextStyle(color: Colors.amber, fontSize: 10, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  static String _topGiftNames(SpiritualGiftsResult r) => r.topGifts.take(3).map((g) => (g.displayName ?? _humanize(g.giftSlug)).split(' ').first).join(', ');
  static String _humanize(String slug) => slug.split('_').map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1)).join(' ');
}

class _MentorHistoryDetail extends StatelessWidget {
  final SpiritualGiftsResult result;
  const _MentorHistoryDetail({required this.result});
  @override
  Widget build(BuildContext context) {
    final truncated = result.topGifts;
    final expanded = result.topGiftsExpanded;
    final hasTies = expanded.length > truncated.length;
    final tieExtras = hasTies ? expanded.where((e) => !truncated.any((t) => t.giftSlug == e.giftSlug)).toList() : const <GiftScore>[];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Row(
              children: [
                VersionBadge(versionLabel: 'v${result.templateVersion}', padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                const Spacer(),
                Text('${result.submittedAt.month}/${result.submittedAt.day}/${result.submittedAt.year}', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Semantics(
                  header: true,
                  child: const Text('Top Gifts', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (hasTies) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('Tie at 3rd', style: TextStyle(color: Colors.amber[200], fontSize: 11, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: truncated.map((g) => _GiftBadge(gift: g)).toList()),
            if (hasTies) ...[
              const SizedBox(height: 14),
              Text('Also tied at 3rd', style: TextStyle(color: Colors.amber[300], fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: tieExtras.map((g) => _GiftBadge(gift: g)).toList()),
            ],
            const SizedBox(height: 26),
            Semantics(
              header: true,
              child: const Text('Full Ranking', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: result.gifts.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[800]),
              itemBuilder: (context, i) {
                final g = result.gifts[i];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: i < 3 ? Colors.amber : Colors.grey[800],
                    child: Text('${g.rank}', style: TextStyle(color: i < 3 ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(g.displayName ?? _humanize(g.giftSlug), style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                  subtitle: Text('${(g.normalized * 100).toStringAsFixed(1)}% • Raw ${g.rawScore.toStringAsFixed(1)}', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12)),
                );
              },
            ),
            const SizedBox(height: 26),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpiritualGiftsFullReportScreen(
                        result: result,
                        apprenticeId: null, // historical specific result already provided
                        readOnly: true,
                        allowDefinitions: true,
                        showActionsSection: false,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('View Full Report', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
  static String _humanize(String slug) => slug.split('_').map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1)).join(' ');
}

/// Shimmer skeleton while mentor apprentices or results load.
class _MentorLoadingSkeleton extends StatelessWidget {
  final bool showPicker;
  const _MentorLoadingSkeleton({required this.showPicker});

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey[800]!;
    final highlight = Colors.grey[700]!;
    return Column(
      children: [
        if (showPicker)
          _pickerSkeleton(baseColor, highlight),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
            children: [
              _sectionHeaderSkeleton(baseColor, highlight, width: 120),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(3, (i) => _topCardSkeleton(baseColor, highlight, context)).toList(),
              ),
              const SizedBox(height: 34),
              _sectionHeaderSkeleton(baseColor, highlight, width: 140),
              const SizedBox(height: 14),
              _listSkeleton(baseColor, highlight, items: 6),
            ],
          ),
        )
      ],
    );
  }

  Widget _pickerSkeleton(Color base, Color highlight) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.grey[900], boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)]),
        child: Row(
          children: [
            Container(height: 40, width: 180, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
            const Spacer(),
            Container(height: 40, width: 40, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeaderSkeleton(Color base, Color highlight, {double width = 120}) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: 22,
        width: width,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _topCardSkeleton(Color base, Color highlight, BuildContext context) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: MediaQuery.of(context).size.width / 2 - 30,
        height: 118,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[850]!)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
                const Spacer(),
                Container(width: 44, height: 18, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6))),
              ],
            ),
            const SizedBox(height: 12),
            Container(width: 90, height: 12, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(width: double.infinity, height: 8, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Container(width: double.infinity, height: 8, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }

  Widget _listSkeleton(Color base, Color highlight, {int items = 6}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey[850]!)),
      child: Column(
        children: List.generate(items, (i) => Column(
          children: [
            if (i>0) Divider(height: 1, color: Colors.grey[850]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: base, shape: BoxShape.circle))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 140, height: 12, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 6),
                        Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 100, height: 8, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)))),
                      ],
                    ),
                  ),
                  Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 20, height: 20, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)))),
                ],
              ),
            )
          ],
        )),
      ),
    );
  }
}
