import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spiritual_gifts_models.dart';
import '../services/api_service.dart';
import '../widgets/version_badge.dart';
import '../widgets/spiritual_gifts_report_view.dart';
import '../utils/haptics.dart';
import '../ui/ui_constants.dart';
import 'spiritual_gifts_definitions_screen.dart';
import 'spiritual_gifts_history_screen.dart';

/// Displays a Spiritual Gifts result (either freshly submitted or fetched latest).
/// Expects either a pre-parsed result OR will fetch latest on init.
class SpiritualGiftsResultsScreen extends StatefulWidget {
  final Map<String, dynamic>? rawResult; // optional raw JSON from submit
  const SpiritualGiftsResultsScreen({super.key, this.rawResult});

  @override
  State<SpiritualGiftsResultsScreen> createState() => _SpiritualGiftsResultsScreenState();
}

class _SpiritualGiftsResultsScreenState extends State<SpiritualGiftsResultsScreen> {
  final _api = ApiService();
  SpiritualGiftsResult? _result;
  bool _loading = true;
  String? _error;
  bool _emailingSelf = false; // loading state for self email
  DateTime? _retryAt; // rate limit next allowed
  Timer? _tick;
  final FocusNode _emailButtonFocus = FocusNode(debugLabel: 'emailReportButton');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.rawResult != null) {
        _result = SpiritualGiftsResult.fromJson(widget.rawResult!);
        setState(() => _loading = false);
        return;
      }
      final json = await _api.getSpiritualGiftsLatest();
      if (json.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No spiritual gifts assessment found yet. Take the assessment first.';
        });
        return;
      }
      _result = SpiritualGiftsResult.fromJson(json);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load results: $e';
      });
    }
  }

  Future<void> _handleEmailSelf() async {
    if (_emailingSelf) return;
    if (_retryAt != null && DateTime.now().isBefore(_retryAt!)) {
      _snack('Please wait ${_remainingSeconds()}s before retrying.', error: true);
      return;
    }
    setState(() => _emailingSelf = true);
    try {
      await _api.emailMySpiritualGiftsReport();
      _snack('Email requested. Check your inbox.');
      Haptics.success();
    } catch (e) {
      // Attempt to surface cleaner backend detail
      final msg = _friendlyEmailError(e.toString());
      if (e.toString().contains('RATE_LIMIT')) {
        // Attempt to parse retry_after_seconds=### from error string
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
      _snack(msg, error: true);
    } finally {
      if (mounted) setState(() => _emailingSelf = false);
    }
  }

  String _friendlyEmailError(String raw) {
    if (raw.contains('RATE_LIMIT')) {
      return 'Rate limit reached. ${_retryAt != null ? 'Wait ${_remainingSeconds()}s.' : 'Try again later.'}';
    }
    // Try to extract FastAPI validation detail
    try {
      final regJson = RegExp(r'\{"detail":.*\}$');
      final match = regJson.firstMatch(raw);
      if (match != null) {
        final decoded = jsonDecode(match.group(0)!);
        if (decoded is Map && decoded['detail'] is List && decoded['detail'].isNotEmpty) {
          final first = decoded['detail'][0];
          if (first is Map) {
            final msg = first['msg'];
            if (msg is String && msg.isNotEmpty) {
              return 'Email failed: ${msg.toLowerCase().replaceFirst(RegExp('^field '), '')}';
            }
          }
        }
      }
    } catch (_) {}
    return 'Failed to email report. Please try again.';
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_retryAt == null) {
        t.cancel();
        return;
      }
      if (DateTime.now().isAfter(_retryAt!)) {
        setState(() => _retryAt = null);
        // Cooldown ended → focus the email button (post-frame to ensure enabled state applied)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_emailingSelf) {
            _emailButtonFocus.requestFocus();
          }
        });
        t.cancel();
      } else {
        setState(() {}); // refresh countdown text
      }
    });
  }

  String _remainingSeconds() {
    if (_retryAt == null) return '0';
    final diff = _retryAt!.difference(DateTime.now());
    final secs = diff.inSeconds;
    return secs < 0 ? '0' : secs.toString();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _emailButtonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Spiritual Gifts Results', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: Semantics(
                  label: 'Assessment template version ${_result!.templateVersion}',
                  child: VersionBadge(versionLabel: 'v${_result!.templateVersion}'),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return _LoadingSkeleton();
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _init);
    }
    if (_result == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _init,
      backgroundColor: Colors.grey[900],
      color: Colors.amber,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(UISpace.s16, UISpace.s16, UISpace.s16, UISpace.s40),
        children: [
          SpiritualGiftsReportView(
            result: _result!,
            actions: _ActionsSection(
              onEmail: _handleEmailSelf,
              emailing: _emailingSelf,
              onHistory: _openHistory,
              onDefinitions: _showDefinitions,
              cooldownSeconds: _retryAt != null ? _retryAt!.difference(DateTime.now()).inSeconds.clamp(0, 9999) : 0,
              emailButtonFocus: _emailButtonFocus,
            ),
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpiritualGiftsHistoryScreen()),
    );
  }

  void _showDefinitions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpiritualGiftsDefinitionsScreen()),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: error ? Colors.redAccent : Colors.grey[800],
    ));
  }
}

class _ActionsSection extends StatelessWidget {
  final VoidCallback onEmail;
  final bool emailing;
  final VoidCallback onHistory;
  final VoidCallback onDefinitions;
  final int cooldownSeconds; // remaining cooldown
  final FocusNode? emailButtonFocus;
  const _ActionsSection({required this.onEmail, required this.onHistory, required this.onDefinitions, this.emailing = false, this.cooldownSeconds = 0, this.emailButtonFocus});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                focusNode: emailButtonFocus,
                // Disable while emailing OR while cooldown active
                onPressed: (emailing || cooldownSeconds > 0) ? null : onEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (emailing || cooldownSeconds > 0)
                      ? Colors.amber.withOpacity(0.45)
                      : Colors.amber,
                  foregroundColor: Colors.black.withOpacity((emailing || cooldownSeconds > 0) ? 0.6 : 1.0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.amber.withOpacity(0.35),
                  disabledForegroundColor: Colors.black.withOpacity(0.45),
                ),
                icon: emailing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                    : Icon(Icons.email_outlined, color: (emailing || cooldownSeconds > 0) ? Colors.black.withOpacity(0.55) : Colors.black),
                label: Semantics(
                  label: emailing ? 'Sending email report' : 'Email my spiritual gifts report',
                  excludeSemantics: true,
                  child: Text(
                    emailing
                        ? 'Sending...'
                        : cooldownSeconds > 0
                            ? 'Wait ${cooldownSeconds}s'
                            : 'Email Me',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onHistory,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.history),
                label: Semantics(
                  label: 'View my submission history',
                  excludeSemantics: true,
                  child: Text('History', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDefinitions,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[700]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
                label: Semantics(
                  label: 'Open spiritual gifts definitions',
                  excludeSemantics: true,
                  child: Text('Gift Definitions', style: TextStyle(fontFamily: 'Poppins')),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading skeleton while results fetch.
class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey[800]!;
    final highlight = Colors.grey[700]!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(UISpace.s16, UISpace.s16, UISpace.s16, UISpace.s40),
      children: [
        _sectionHeaderSkeleton(baseColor, highlight, width: 140),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: List.generate(3, (i) => _topCardSkeleton(baseColor, highlight, context)).toList(),
        ),
        const SizedBox(height: 32),
        _sectionHeaderSkeleton(baseColor, highlight, width: 170),
        const SizedBox(height: 12),
        _legendSkeleton(baseColor, highlight),
        const SizedBox(height: 16),
        _listSkeleton(baseColor, highlight, itemCount: 6),
        const SizedBox(height: 40),
        _sectionHeaderSkeleton(baseColor, highlight, width: 100),
        const SizedBox(height: 20),
        _actionsSkeleton(baseColor, highlight),
      ],
    );
  }

  Widget _sectionHeaderSkeleton(Color base, Color highlight, {double width = 120}) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: 22,
        width: width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _topCardSkeleton(Color base, Color highlight, BuildContext context) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: MediaQuery.of(context).size.width / 2 - 28,
        height: 140,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[850], shape: BoxShape.circle)),
                const Spacer(),
                Container(width: 50, height: 20, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(8)),),
              ],
            ),
            const SizedBox(height: 12),
            Container(width: 90, height: 14, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }

  Widget _legendSkeleton(Color base, Color highlight) {
    return Row(
      children: [
        ...List.generate(2, (i) => Padding(
          padding: EdgeInsets.only(right: i==1?0:8),
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(width: 60, height: 22, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
          ),
        )),
        const SizedBox(width: 8),
        Shimmer.fromColors(
          baseColor: base,
            highlightColor: highlight,
          child: Container(width: 110, height: 12, color: base),
        ),
      ],
    );
  }

  Widget _listSkeleton(Color base, Color highlight, {int itemCount = 6}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Column(
        children: List.generate(itemCount, (i) => Column(
          children: [
            if (i>0) Divider(height:1,color: Colors.grey[850]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: base,
                    highlightColor: highlight,
                    child: Container(width: 40, height: 40, decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 140, height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 8),
                        Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 100, height: 10, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)))),
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

  Widget _actionsSkeleton(Color base, Color highlight) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Container(height: 48, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Container(height: 48, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Container(height: 48, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        )
      ],
    );
  }
}
