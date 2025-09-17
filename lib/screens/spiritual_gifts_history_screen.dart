import 'package:flutter/material.dart';
import '../models/spiritual_gifts_models.dart';
import '../services/api_service.dart';

/// Paginated history of Spiritual Gifts submissions for the authenticated user.
class SpiritualGiftsHistoryScreen extends StatefulWidget {
  const SpiritualGiftsHistoryScreen({super.key});

  @override
  State<SpiritualGiftsHistoryScreen> createState() => _SpiritualGiftsHistoryScreenState();
}

class _SpiritualGiftsHistoryScreenState extends State<SpiritualGiftsHistoryScreen> {
  final _api = ApiService();
  final List<SpiritualGiftsResult> _items = [];
  String? _nextCursor;
  bool _initialLoading = true;
  bool _pageLoading = false;
  bool _error = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() { _initialLoading = true; _error = false; _errorMsg = null; });
    try {
      final json = await _api.getSpiritualGiftsHistory(limit: 10);
      final page = SpiritualGiftsHistoryPage.fromJson(json);
      setState(() {
        _items..clear()..addAll(page.items);
        _nextCursor = page.nextCursor;
        _initialLoading = false;
      });
      // If history is empty but user has a latest submission (possible backend not returning self history yet), fallback to latest.
      if (_items.isEmpty) {
        try {
          final latestJson = await _api.getSpiritualGiftsLatest();
          if (latestJson.isNotEmpty) {
            final latest = SpiritualGiftsResult.fromJson(latestJson);
            setState(() { _items.add(latest); });
          }
        } catch (_) {/* silent fallback */}
      }
    } catch (e) {
      setState(() { _initialLoading = false; _error = true; _errorMsg = 'Failed to load history: $e'; });
    }
  }

  Future<void> _refresh() async {
    try {
      final json = await _api.getSpiritualGiftsHistory(limit: 10);
      final page = SpiritualGiftsHistoryPage.fromJson(json);
      setState(() {
        _items..clear()..addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      _snack('Refresh failed: $e', error: true);
    }
  }

  Future<void> _loadMore() async {
    if (_pageLoading || _nextCursor == null) return;
    setState(() => _pageLoading = true);
    try {
      final json = await _api.getSpiritualGiftsHistory(cursor: _nextCursor, limit: 10);
      final page = SpiritualGiftsHistoryPage.fromJson(json);
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      _snack('Failed to load more: $e', error: true);
    } finally {
      setState(() => _pageLoading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: error ? Colors.redAccent : Colors.grey[800],
      ),
    );
  }

  void _openResult(SpiritualGiftsResult r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _HistoryDetailSheet(result: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Gifts History', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
              const SizedBox(height: 16),
              Text(_errorMsg ?? 'Unknown error', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadInitial,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.amber,
        backgroundColor: Colors.grey[900],
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('No submissions yet.', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'))),
            SizedBox(height: 40),
            Center(child: Text('If you recently completed an assessment, pull to refresh.', style: TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 12))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.amber,
      backgroundColor: Colors.grey[900],
      child: ListView.builder(
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            if (_nextCursor == null) {
              return const SizedBox(height: 70); // end spacer
            }
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
            return _HistoryItem(result: r, onTap: () => _openResult(r));
        },
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final SpiritualGiftsResult result;
  final VoidCallback onTap;
  const _HistoryItem({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = result.submittedAt.toLocal();
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
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.amber.withOpacity(0.18),
              child: Text(
                'v${result.templateVersion}',
                style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _topGiftNames(result),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.month}/${date.day}/${date.year}  •  ${_time(date)}',
                    style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                  )
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  static String _topGiftNames(SpiritualGiftsResult r) => r.topGifts
      .take(3)
      .map((g) => (g.displayName ?? _humanize(g.giftSlug)).split(' ').first)
      .join(', ');

  static String _time(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:$m $suffix';
  }

  static String _humanize(String slug) => slug
      .split('_')
      .map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1))
      .join(' ');
}

class _HistoryDetailSheet extends StatelessWidget {
  final SpiritualGiftsResult result;
  const _HistoryDetailSheet({required this.result});

  @override
  Widget build(BuildContext context) {
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
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Text('v${result.templateVersion}',
                      style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(
                  _formatDate(result.submittedAt.toLocal()),
                  style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Top Gifts',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: result.topGifts.map((g) => _GiftChip(gift: g)).toList(),
            ),
      const SizedBox(height: 26),
      _EmailReportSection(submissionId: result.submissionId),
      const SizedBox(height: 26),
            const Text('Full Ranking',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
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
                    child: Text(
                      '${g.rank}',
                      style: TextStyle(color: i < 3 ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    g.displayName ?? _humanize(g.giftSlug),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  ),
                  subtitle: Text(
                    '${(g.normalized * 100).toStringAsFixed(1)}% • Score ${g.rawScore.toStringAsFixed(1)}',
                    style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';

  static String _humanize(String slug) => slug
      .split('_')
      .map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1))
      .join(' ');
}

class _GiftChip extends StatelessWidget {
  final GiftScore gift;
  const _GiftChip({required this.gift});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('#${gift.rank}', style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(
            gift.displayName ?? _humanize(gift.giftSlug),
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          ),
          const SizedBox(width: 8),
          Text('${(gift.normalized * 100).toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 11)),
        ],
      ),
    );
  }

  static String _humanize(String slug) => slug
      .split('_')
      .map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1))
      .join(' ');
}

class _EmailReportSection extends StatefulWidget {
  final String submissionId;
  const _EmailReportSection({required this.submissionId});

  @override
  State<_EmailReportSection> createState() => _EmailReportSectionState();
}

class _EmailReportSectionState extends State<_EmailReportSection> {
  bool _sending = false;
  String? _message; // success or error

  Future<void> _send() async {
    if (_sending) return;
    setState(() { _sending = true; _message = null; });
    final api = ApiService();
    try {
      await api.emailMySpiritualGiftsReportForSubmission(widget.submissionId);
      if (!mounted) return;
      setState(() { _message = 'Report email requested. Check your inbox shortly.'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _message = e.toString(); });
    } finally {
      if (mounted) setState(() { _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.email_outlined),
                label: Text(
                  _sending ? 'Sending...' : 'Email this report',
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(
            _message!,
            style: TextStyle(
              color: _message!.startsWith('Report email') ? Colors.greenAccent : Colors.redAccent,
              fontFamily: 'Poppins',
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
