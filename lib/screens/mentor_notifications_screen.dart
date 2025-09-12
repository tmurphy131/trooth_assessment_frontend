import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MentorNotificationsScreen extends StatefulWidget {
  final Future<void> Function()? onActivity; // callback to parent to refresh badge counts
  const MentorNotificationsScreen({super.key, this.onActivity});

  @override
  State<MentorNotificationsScreen> createState() => _MentorNotificationsScreenState();
}

class _MentorNotificationsScreenState extends State<MentorNotificationsScreen> {
  final _api = ApiService();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _mode = 'active'; // 'active' | 'history'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = _mode == 'active'
          ? await _api.mentorNotifications()
          : await _api.mentorNotificationsHistory();
      setState(() { _items = list.cast<Map<String, dynamic>>(); });
    } catch (e) {
      setState(() { _error = 'Failed to load: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _dismiss(String id) async {
    try {
      await _api.dismissNotification(id);
      if (_mode == 'active') {
        setState(() { _items.removeWhere((e) => e['id'] == id); });
      } else {
        await _load();
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dismissed')));
      if (widget.onActivity != null) widget.onActivity!();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dismiss failed: $e')));
    }
  }

  Widget _modeSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Active', style: TextStyle(fontFamily: 'Poppins')),
            selected: _mode == 'active',
            onSelected: (v) async {
              if (!v || _mode == 'active') return; setState(() { _mode = 'active'; }); await _load();
            },
            selectedColor: Colors.amber.withOpacity(.25),
            backgroundColor: Colors.grey[800],
            labelStyle: TextStyle(color: _mode == 'active' ? Colors.amber : Colors.white),
          ),
          const SizedBox(width: 12),
            ChoiceChip(
            label: const Text('History', style: TextStyle(fontFamily: 'Poppins')),
            selected: _mode == 'history',
            onSelected: (v) async {
              if (!v || _mode == 'history') return; setState(() { _mode = 'history'; }); await _load();
            },
            selectedColor: Colors.blueGrey.withOpacity(.35),
            backgroundColor: Colors.grey[800],
            labelStyle: TextStyle(color: _mode == 'history' ? Colors.lightBlueAccent : Colors.white),
          ),
          const Spacer(),
          if (_mode == 'active' && _items.isNotEmpty)
            TextButton.icon(
              onPressed: _loading ? null : () async {
                try {
                  final count = await _api.dismissAllNotifications();
                  await _load();
                  if (widget.onActivity != null) widget.onActivity!();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dismissed $count notifications')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bulk dismiss failed: $e')));
                }
              },
              icon: const Icon(Icons.clear_all, color: Colors.amber, size: 18),
              label: const Text('Dismiss All', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.amber),
          )
        ],
      ),
    );
  }

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    DateTime? dt;
    try { dt = DateTime.parse(iso).toLocal(); } catch (_) {}
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
  // Fallback simple date (M/D)
  return '${dt.month}/${dt.day}';
  }

  String? _parseAgreementIdFromLink(String? link) {
    if (link == null || link.isEmpty) return null;
    // Expect formats like "/agreements/{id}" or "/agreements/{id}/..."
    final parts = link.split('/').where((p) => p.isNotEmpty).toList();
    final idx = parts.indexOf('agreements');
    if (idx >= 0 && idx + 1 < parts.length) {
      return parts[idx + 1];
    }
    return null;
  }

  List<String> _extractProposals(String message) {
    // Message format example: "Meeting reschedule requested — Reason: X | Proposals: 2025-01-02 16:00, 2025-01-03 17:00"
    final i = message.toLowerCase().indexOf('proposals:');
    if (i < 0) return const [];
    final sub = message.substring(i + 'proposals:'.length).trim();
    // Stop at a separator if present
    final stopIdx = sub.indexOf('|');
    final listStr = (stopIdx >= 0 ? sub.substring(0, stopIdx) : sub).trim();
    if (listStr.isEmpty) return const [];
    return listStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _showRespondDialog({required String agreementId, required List<String> proposals}) async {
    String decision = 'accepted';
    String? selectedFromList = proposals.isNotEmpty ? proposals.first : null;
    final selectedCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Respond to Reschedule', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Decision', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      ChoiceChip(
                        label: const Text('Accept', style: TextStyle(fontFamily: 'Poppins')),
                        selected: decision == 'accepted',
                        onSelected: (v) => setState(() => decision = 'accepted'),
                        selectedColor: Colors.green.withOpacity(.2),
                        labelStyle: TextStyle(color: decision == 'accepted' ? Colors.green : Colors.white),
                        backgroundColor: Colors.grey[800],
                      ),
                      ChoiceChip(
                        label: const Text('Decline', style: TextStyle(fontFamily: 'Poppins')),
                        selected: decision == 'declined',
                        onSelected: (v) => setState(() => decision = 'declined'),
                        selectedColor: Colors.red.withOpacity(.2),
                        labelStyle: TextStyle(color: decision == 'declined' ? Colors.redAccent : Colors.white),
                        backgroundColor: Colors.grey[800],
                      ),
                      ChoiceChip(
                        label: const Text('Propose', style: TextStyle(fontFamily: 'Poppins')),
                        selected: decision == 'proposed',
                        onSelected: (v) => setState(() => decision = 'proposed'),
                        selectedColor: Colors.orange.withOpacity(.2),
                        labelStyle: TextStyle(color: decision == 'proposed' ? Colors.orange : Colors.white),
                        backgroundColor: Colors.grey[800],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (decision != 'declined') ...[
                    if (proposals.isNotEmpty) ...[
                      const Text('Select a proposed time', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedFromList,
                        items: proposals.map((p) => DropdownMenuItem<String>(value: p, child: Text(p, style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (v) => setState(() => selectedFromList = v),
                        dropdownColor: Colors.grey[900],
                        decoration: const InputDecoration(enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber,width:2))),
                      ),
                      const SizedBox(height: 8),
                      const Text('Or enter a different time', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                    ],
                    if (proposals.isEmpty)
                      const Text('Enter a time (e.g., 2025-01-03 16:00 PT)', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                    const SizedBox(height: 6),
                    TextField(
                      controller: selectedCtrl,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        hintText: 'e.g., 2025-01-03 16:00 PT',
                        hintStyle: TextStyle(color: Colors.white38),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text('Optional note', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: submitting ? null : () async {
                  setState(() { submitting = true; });
                  try {
                    String? selectedTime;
                    if (decision != 'declined') {
                      final manual = selectedCtrl.text.trim();
                      selectedTime = manual.isNotEmpty ? manual : selectedFromList;
                    }
                    await _api.respondReschedule(
                      agreementId,
                      decision: decision,
                      selectedTime: selectedTime,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response sent')));
                    await _load();
                    // Notify parent to refresh badge count after handling the request.
                    if (widget.onActivity != null) await widget.onActivity!();
                    // TODO: trigger a higher-level agreements refresh (e.g., via an inherited widget or provider) so meeting info updates immediately.
                  } catch (e) {
                    setState(() { submitting = false; });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                },
                child: submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.amber,
      child: Column(
        children: [
          _modeSwitcher(),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent)),
                            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          )
                        ],
                      )
                    : _items.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(child: Text(_mode == 'active' ? 'No notifications' : 'No history', style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins'))),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final n = _items[index];
                              final msg = (n['message'] ?? '') as String;
                              final createdAt = n['created_at'] as String?;
                              final isRead = n['is_read'] == true;
                              final link = n['link'] as String?;
                              final agId = _parseAgreementIdFromLink(link);
                              final proposals = _extractProposals(msg);
                              final isReschedule = msg.toLowerCase().contains('reschedule');
                              final actions = <Widget>[];
                              final inActive = _mode == 'active';
                              if (inActive) {
                                if (isReschedule && agId != null) {
                                  actions.add(TextButton(
                                    onPressed: () => _showRespondDialog(agreementId: agId, proposals: proposals),
                                    child: const Text('Respond', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                                  ));
                                }
                                actions.add(TextButton(
                                  onPressed: () => _dismiss(n['id'] as String),
                                  child: const Text('Dismiss', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                                ));
                              }
                              return Card(
                                color: Colors.grey[850],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: (isRead ? Colors.grey : Colors.amber).withOpacity(.2),
                                            child: Icon(isReschedule ? Icons.event : Icons.notifications, color: isRead ? Colors.grey : Colors.amber),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  msg,
                                                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                                                ),
                                                if (createdAt != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _relativeTime(createdAt),
                                                    style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 12),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (actions.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: -4,
                                          children: actions.map((w) => SizedBox(height: 32, child: w)).toList(),
                                        )
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
