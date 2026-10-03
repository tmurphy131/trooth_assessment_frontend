import 'package:flutter/material.dart';
import 'package:trooth_assessment/theme.dart';

import '../models/prayer_entry.dart';
import '../services/api_service.dart';
import '../services/prayer_reminder_service.dart';
import '../utils/errors.dart';
import 'prayer_entry_editor_screen.dart';

class PrayerJournalScreen extends StatefulWidget {
  const PrayerJournalScreen({super.key});

  @override
  State<PrayerJournalScreen> createState() => _PrayerJournalScreenState();
}

class _PrayerJournalScreenState extends State<PrayerJournalScreen> {
  final _api = ApiService();
  List<PrayerEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  PrayerCategory? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _entries.isEmpty;
      _error = null;
    });
    try {
      final entries = await _api.getPrayerEntries();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn\'t load your journal: ${friendlyError(e)}';
        _loading = false;
      });
    }
  }

  List<PrayerEntry> _visible({required bool answered}) => _entries
      .where((e) => e.isAnswered == answered)
      .where((e) => _categoryFilter == null || e.category == _categoryFilter)
      .toList();

  Future<void> _openEditor([PrayerEntry? entry]) async {
    // Answer toggles save immediately in the editor, so always refresh.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PrayerEntryEditorScreen(entry: entry)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prayer Journal'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Daily reminder',
              onPressed: () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => const _ReminderSheet(),
              ),
            ),
          ],
          bottom: TabBar(
            labelColor: kCharcoal,
            indicatorColor: kPrimaryGold,
            labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Active'), Tab(text: 'Answered')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: kPrimaryGold,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add),
          label: const Text('New prayer', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        ),
        body: Column(
          children: [
            _buildCategoryChips(),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: kPrimaryGold))
                  : _error != null
                      ? _buildMessage(_error!, action: TextButton(onPressed: _load, child: const Text('Try again')))
                      : TabBarView(
                          children: [
                            _buildList(_visible(answered: false), answered: false),
                            _buildList(_visible(answered: true), answered: true),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _chip(label: 'All', selected: _categoryFilter == null, onTap: () => setState(() => _categoryFilter = null)),
          for (final c in PrayerCategory.values)
            _chip(
              label: c.label,
              selected: _categoryFilter == c,
              onTap: () => setState(() => _categoryFilter = _categoryFilter == c ? null : c),
            ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12)),
        selected: selected,
        selectedColor: kPrimaryGold.withValues(alpha: 0.25),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildList(List<PrayerEntry> entries, {required bool answered}) {
    if (entries.isEmpty) {
      final text = _categoryFilter != null
          ? 'No ${_categoryFilter!.label.toLowerCase()} prayers here yet.'
          : answered
              ? 'Answered prayers will show up here.\nMark a prayer answered to remember God\'s faithfulness.'
              : 'Start your prayer journal.\nWrite down what you\'re bringing to God today.';
      return RefreshIndicator(
        color: kPrimaryGold,
        onRefresh: _load,
        child: ListView(children: [const SizedBox(height: 120), _buildMessage(text)]),
      );
    }
    return RefreshIndicator(
      color: kPrimaryGold,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => PrayerEntryCard(entry: entries[i], onTap: () => _openEditor(entries[i])),
      ),
    );
  }

  Widget _buildMessage(String text, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note, size: 48, color: kMutedText),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Poppins', color: kMutedText)),
          if (action != null) action,
        ],
      ),
    );
  }
}

/// Entry summary card, shared by the apprentice journal and the mentor view.
class PrayerEntryCard extends StatelessWidget {
  const PrayerEntryCard({super.key, required this.entry, this.onTap, this.showShareBadge = true, this.dark = false});

  final PrayerEntry entry;
  final VoidCallback? onTap;
  final bool showShareBadge;

  /// For the black mentor screens.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final meta = [
      entry.category.label,
      if (entry.prayingFor != null) 'for ${entry.prayingFor}',
      if (entry.scriptureRef != null) entry.scriptureRef!,
    ].join(' · ');
    final textColor = dark ? Colors.white : kCharcoal;
    final mutedColor = dark ? Colors.white60 : kMutedText;

    return Card(
      color: dark ? Colors.grey[850] : null,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(entry.category.icon, color: Colors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(height: 2),
                    Text(meta, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: mutedColor)),
                    if (entry.body != null) ...[
                      const SizedBox(height: 6),
                      Text(entry.body!,
                          maxLines: onTap == null ? null : 2,
                          overflow: onTap == null ? null : TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: textColor)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _badge(Icons.schedule, formatPrayerDate(entry.createdAt), mutedColor),
                        if (entry.isAnswered)
                          _badge(Icons.check_circle, 'Answered ${formatPrayerDate(entry.answeredAt!)}', Colors.green),
                        if (showShareBadge && entry.sharedWithMentor)
                          _badge(Icons.visibility_outlined, 'Shared with mentor', Colors.blue),
                      ],
                    ),
                    if (entry.isAnswered && entry.answerNote != null && onTap == null) ...[
                      const SizedBox(height: 6),
                      Text(entry.answerNote!,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontStyle: FontStyle.italic, color: mutedColor)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: color)),
      ],
    );
  }
}

String formatPrayerDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final sameYear = dt.year == DateTime.now().year;
  return '${months[dt.month - 1]} ${dt.day}${sameYear ? '' : ', ${dt.year}'}';
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet();

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  final _service = PrayerReminderService();
  bool _enabled = false;
  TimeOfDay _time = PrayerReminderService.defaultTime;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service.load().then((s) {
      if (!mounted) return;
      setState(() {
        _enabled = s.enabled;
        _time = s.time;
        _loading = false;
      });
    });
  }

  Future<void> _apply({required bool enabled, required TimeOfDay time}) async {
    setState(() => _loading = true);
    var ok = true;
    if (enabled) {
      ok = await _service.enable(time);
    } else {
      await _service.disable();
    }
    if (!mounted) return;
    setState(() {
      _enabled = enabled && ok;
      _time = time;
      _loading = false;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Notifications are turned off for T[root]H. Turn them on in Settings to get reminders.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Daily prayer reminder', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              subtitle: const Text('A gentle nudge on this device', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
              value: _enabled,
              activeThumbColor: kPrimaryGold,
              onChanged: _loading ? null : (v) => _apply(enabled: v, time: _time),
            ),
            ListTile(
              enabled: _enabled && !_loading,
              leading: const Icon(Icons.schedule),
              title: const Text('Time', style: TextStyle(fontFamily: 'Poppins')),
              trailing: Text(_time.format(context), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _time);
                if (picked != null) await _apply(enabled: true, time: picked);
              },
            ),
          ],
        ),
      ),
    );
  }
}
