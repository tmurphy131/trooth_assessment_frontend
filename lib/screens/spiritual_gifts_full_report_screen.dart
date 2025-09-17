import 'package:flutter/material.dart';
import '../models/spiritual_gifts_models.dart';
import '../widgets/spiritual_gifts_report_view.dart';
import '../utils/haptics.dart';
import '../services/api_service.dart';
import 'spiritual_gifts_definitions_screen.dart';

/// Generic full report screen for both apprentice (viewing historical submission)
/// and mentor (viewing apprentice submission) contexts.
/// If a [result] is provided it will render directly; otherwise it can fetch by latest (apprentice only).
class SpiritualGiftsFullReportScreen extends StatefulWidget {
  final SpiritualGiftsResult? result;
  final String? apprenticeId; // if mentor viewing specific latest maybe not needed if result passed
  final bool readOnly; // hides actions like email/history unless explicitly allowed
  final bool allowEmail;
  final bool allowDefinitions;
  final bool showActionsSection;

  const SpiritualGiftsFullReportScreen({
    super.key,
    this.result,
    this.apprenticeId,
    this.readOnly = true,
    this.allowEmail = false,
    this.allowDefinitions = true,
    this.showActionsSection = false,
  });

  @override
  State<SpiritualGiftsFullReportScreen> createState() => _SpiritualGiftsFullReportScreenState();
}

class _SpiritualGiftsFullReportScreenState extends State<SpiritualGiftsFullReportScreen> {
  SpiritualGiftsResult? _result;
  bool _loading = false;
  String? _error;
  final _api = ApiService();
  bool _emailing = false;
  DateTime? _retryAt;

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      _result = widget.result;
    } else {
      _fetchLatestIfNeeded();
    }
  }

  Future<void> _fetchLatestIfNeeded() async {
    if (widget.result != null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final json = await _api.getSpiritualGiftsLatest();
      if (json.isEmpty) {
        setState(() { _error = 'No assessment found yet.'; _loading = false; });
        return;
      }
      setState(() { _result = SpiritualGiftsResult.fromJson(json); _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load report: $e'; _loading = false; });
    }
  }

  Future<void> _handleEmail() async {
    if (_emailing) return;
    if (_retryAt != null && DateTime.now().isBefore(_retryAt!)) return;
    if (widget.apprenticeId != null) {
      // mentor email path
      setState(() => _emailing = true);
      try {
        await _api.mentorEmailSpiritualGiftsReport(widget.apprenticeId!);
        _snack('Email requested');
        Haptics.success();
      } catch (e) {
        if (e.toString().contains('RATE_LIMIT')) {
          final reg = RegExp(r'retry_after_seconds[=:\s]+(\d+)');
          final m = reg.firstMatch(e.toString());
          if (m != null) {
            final secs = int.tryParse(m.group(1)!);
            if (secs != null) _retryAt = DateTime.now().add(Duration(seconds: secs));
          }
        }
        _snack('Email failed: $e', error: true);
      } finally { if (mounted) setState(() => _emailing = false); }
    } else {
      setState(() => _emailing = true);
      try {
        await _api.emailMySpiritualGiftsReport();
        _snack('Email requested');
        Haptics.success();
      } catch (e) {
        _snack('Email failed: $e', error: true);
      } finally { if (mounted) setState(() => _emailing = false); }
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: error ? Colors.redAccent : Colors.grey[850],
    ));
  }

  void _openDefinitions() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SpiritualGiftsDefinitionsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cooldownSeconds = _retryAt != null ? _retryAt!.difference(DateTime.now()).inSeconds.clamp(0, 9999) : 0;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Full Spiritual Gifts Report', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchLatestIfNeeded,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                          child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                )
              : _result == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      children: [
                        SpiritualGiftsReportView(
                          result: _result!,
                          actions: widget.showActionsSection && !widget.readOnly
                              ? _InlineActions(
                                  emailing: _emailing,
                                  onEmail: widget.allowEmail ? _handleEmail : null,
                                  cooldownSeconds: cooldownSeconds,
                                  onDefinitions: widget.allowDefinitions ? _openDefinitions : null,
                                )
                              : null,
                        ),
                      ],
                    ),
    );
  }
}

class _InlineActions extends StatelessWidget {
  final VoidCallback? onEmail;
  final VoidCallback? onDefinitions;
  final bool emailing;
  final int cooldownSeconds;
  const _InlineActions({this.onEmail, this.onDefinitions, required this.emailing, required this.cooldownSeconds});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Row(
          children: [
            if (onEmail != null)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: emailing || cooldownSeconds > 0 ? null : onEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: emailing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                      : const Icon(Icons.email_outlined),
                  label: Text(
                    emailing
                        ? 'Sending...'
                        : cooldownSeconds > 0
                            ? 'Wait ${cooldownSeconds}s'
                            : 'Email Report',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (onDefinitions != null)
          OutlinedButton.icon(
            onPressed: onDefinitions,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.grey[700]!),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
            label: const Text('Gift Definitions', style: TextStyle(fontFamily: 'Poppins')),
          ),
      ],
    );
  }
}
