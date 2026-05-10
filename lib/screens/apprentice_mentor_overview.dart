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
  List<Map<String, dynamic>> _activeMentors = [];
  List<Map<String, dynamic>> _pendingAgreements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final status = await _api.getMentorStatus();
      List<Map<String, dynamic>> pending = [];
      try {
        final p = await _api.listPendingAgreements();
        pending = p.cast<Map<String, dynamic>>();
      } catch (_) {}
      setState(() {
        _activeMentors = (status['mentors'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ?? [];
        _pendingAgreements = pending;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _confirmRevoke(Map<String, dynamic> mentor) async {
    final mentorId = mentor['id'] as String;
    final mentorName = mentor['name'] as String? ?? 'your mentor';
    final reasonCtrl = TextEditingController();
    bool submitting = false;
    final hasPending = _pendingAgreements.any((a) => a['mentor_id'] == mentorId);
    await showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text('End Mentorship with $mentorName',
                style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPending) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.redAccent),
                        color: Colors.redAccent.withOpacity(.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                        'You have a pending agreement with this mentor. Resolve or revoke that agreement before ending the mentorship.',
                        style: TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Optional reason (shared with mentor):',
                    style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
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
                const Text(
                    'This will notify the mentor and archive the relationship. Your other mentorships are unaffected.',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Poppins')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: submitting || hasPending
                    ? null
                    : () async {
                        setState(() { submitting = true; });
                        try {
                          await _api.revokeMentor(
                              mentorId: mentorId, reason: reasonCtrl.text.trim());
                          if (!mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mentorship ended')));
                          await _load();
                        } catch (e) {
                          setState(() { submitting = false; });
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm End'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMentorCard(Map<String, dynamic> mentor) {
    final name = mentor['name'] as String? ?? 'Unknown';
    final email = mentor['email'] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.amber.withOpacity(.2),
              child: Text(initial,
                  style: const TextStyle(
                      fontSize: 20,
                      color: Colors.amber,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Chip(
                    label: const Text('Active', style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                    backgroundColor: Colors.green.withOpacity(.15),
                    labelStyle: const TextStyle(color: Colors.green),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 2),
                    Text(email,
                        style: const TextStyle(
                            color: Colors.white70, fontFamily: 'Poppins', fontSize: 12)),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: () => _confirmRevoke(mentor),
              child: const Text('End', style: TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
            ),
          ],
        ),
      ),
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
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final hasActive = _activeMentors.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active mentors
          if (hasActive) ...[
            Text('Your Mentors',
                style: TextStyle(
                    color: Colors.amber[300],
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 8),
            ..._activeMentors.map(_buildMentorCard),
            const SizedBox(height: 8),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(.12),
                border: Border.all(color: Colors.redAccent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                  'No active mentors. Historical agreements and resources are available in read-only mode.',
                  style: TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
            ),
            const SizedBox(height: 24),
          ],
          // Pending agreements
          if (_pendingAgreements.isNotEmpty) ...[
            Text('Pending Agreements',
                style: TextStyle(
                    color: Colors.amber[300],
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 8),
            ..._pendingAgreements.map((a) => Card(
                  color: Colors.grey[850],
                  child: ListTile(
                    title: Text('Agreement ${a['id'].toString().substring(0, 6)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${a['mentor_name'] ?? 'Mentor'} · ${a['status']}',
                        style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                    trailing: a['status'] == 'awaiting_apprentice'
                        ? TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Open sign flow')));
                            },
                            child: const Text('Review & Sign',
                                style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                          )
                        : null,
                  ),
                )),
            const SizedBox(height: 24),
          ],
          const Text('Mentor Overview',
              style: TextStyle(
                  color: Colors.white70, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
              'Your mentors help guide your growth. Use this section to stay aligned on agreements, meetings, and shared resources.',
              style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12)),
        ],
      ),
    );
  }
}
