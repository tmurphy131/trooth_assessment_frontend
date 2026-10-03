import 'package:flutter/material.dart';

import '../models/prayer_entry.dart';
import '../services/api_service.dart';
import '../utils/errors.dart';
import 'prayer_journal_screen.dart' show PrayerEntryCard;

/// Read-only list of the prayer journal entries an apprentice chose to share.
class MentorApprenticePrayersScreen extends StatefulWidget {
  final String apprenticeId;
  final String apprenticeName;
  const MentorApprenticePrayersScreen({super.key, required this.apprenticeId, required this.apprenticeName});

  @override
  State<MentorApprenticePrayersScreen> createState() => _MentorApprenticePrayersScreenState();
}

class _MentorApprenticePrayersScreenState extends State<MentorApprenticePrayersScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<PrayerEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final entries = await _api.mentorGetSharedPrayerEntries(widget.apprenticeId);
      if (!mounted) return;
      setState(() { _entries = entries; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load prayer requests: ${friendlyError(e)}'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${widget.apprenticeName} · Prayer requests', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')))
              : RefreshIndicator(
                  color: Colors.amber,
                  onRefresh: _load,
                  child: _entries.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 200),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'No shared prayer requests yet.\nEntries appear here when your apprentice chooses to share them.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
                            ),
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => PrayerEntryCard(entry: _entries[i], showShareBadge: false, dark: true),
                        ),
                ),
    );
  }
}
