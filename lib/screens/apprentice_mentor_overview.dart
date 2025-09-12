import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ApprenticeMentorOverview extends StatefulWidget {
  const ApprenticeMentorOverview({super.key});

  @override
  State<ApprenticeMentorOverview> createState() => _ApprenticeMentorOverviewState();
}

class _ApprenticeMentorOverviewState extends State<ApprenticeMentorOverview> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _mentorStatus; // { has_active, mentor }
  List<Map<String, dynamic>> _pendingAgreements = [];
  bool _revoking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final status = await _api.getMentorStatus();
      List<Map<String,dynamic>> pending = [];
      try {
        final p = await _api.listPendingAgreements();
        pending = p.cast<Map<String,dynamic>>();
      } catch (_) {}
      setState(() {
        _mentorStatus = status;
        _pendingAgreements = pending;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _confirmRevoke() async {
    final reasonCtrl = TextEditingController();
    bool submitting = false;
    final hasPending = _pendingAgreements.isNotEmpty;
    await showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('End Mentorship', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPending) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.redAccent), color: Colors.redAccent.withOpacity(.12), borderRadius: BorderRadius.circular(6)),
                    child: const Text('You have a pending agreement. Resolve or revoke that agreement before ending the mentorship.', style: TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Optional reason (shared with mentor):', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('This will notify your mentor and archive the relationship. You can request a new mentor later.', style: TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Poppins')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: submitting || hasPending ? null : () async {
                  setState(() { submitting = true; });
                  try {
                    await _api.revokeMentor(reason: reasonCtrl.text.trim());
                    if (!mounted) return;
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mentorship ended')));
                    await _load();
                  } catch (e) {
                    setState(() { submitting = false; });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                },
                child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm End'),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _statusChip() {
    if (_mentorStatus == null || _mentorStatus!["has_active"] != true) {
      return Chip(
        label: const Text('Ended', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.redAccent.withOpacity(.15),
        labelStyle: const TextStyle(color: Colors.redAccent),
      );
    }
    return Chip(
      label: const Text('Active', style: TextStyle(fontFamily: 'Poppins')),
      backgroundColor: Colors.green.withOpacity(.15),
      labelStyle: const TextStyle(color: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            )
          ],
        ),
      );
    }

    final hasActive = _mentorStatus?["has_active"] == true;
    final mentor = _mentorStatus?['mentor'] as Map<String,dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.amber.withOpacity(.2),
                child: Text(
                  mentor != null && (mentor['name'] ?? '').toString().isNotEmpty
                    ? mentor['name'][0].toUpperCase()
                    : '?',
                  style: const TextStyle(fontSize: 24, color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mentor != null ? (mentor['name'] ?? 'Unknown') : 'No Active Mentor',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(children: [ _statusChip() ]),
                    if (mentor != null && mentor['email'] != null) ...[
                      const SizedBox(height: 4),
                      Text(mentor['email'], style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 12)),
                    ]
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (hasActive) ...[
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _revoking ? null : _confirmRevoke,
                  child: const Text('End Mentorship', style: TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
                )
              ],
            ),
            const SizedBox(height: 24),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(.12),
                border: Border.all(color: Colors.redAccent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Mentorship ended. Historical agreements and resources are available in read-only mode.',
                style: TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
            ),
            const SizedBox(height: 24),
          ],
          if (_pendingAgreements.isNotEmpty) ...[
            Text('Pending Agreements', style: TextStyle(color: Colors.amber[300], fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._pendingAgreements.map((a) => Card(
              color: Colors.grey[850],
              child: ListTile(
                title: Text('Agreement ${a['id'].toString().substring(0,6)}', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                subtitle: Text(a['status'], style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                trailing: a['status'] == 'awaiting_apprentice'
                  ? TextButton(
                      onPressed: () {
                        // TODO: navigate to sign flow
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open sign flow')));
                      },
                      child: const Text('Review & Sign', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                    )
                  : null,
              ),
            )),
            const SizedBox(height: 24),
          ],
          const Text('Mentor Overview', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Your mentor helps guide your growth. Use this section to stay aligned on agreements, meetings, and shared resources.',
            style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12)),
        ],
      ),
    );
  }
}
