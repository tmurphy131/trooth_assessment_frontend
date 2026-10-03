import 'package:flutter/material.dart';
import 'package:trooth_assessment/theme.dart';

import '../models/prayer_entry.dart';
import '../services/api_service.dart';
import '../utils/errors.dart';
import 'prayer_journal_screen.dart' show formatPrayerDate;

/// Create a new prayer entry, or edit / answer / delete an existing one.
class PrayerEntryEditorScreen extends StatefulWidget {
  const PrayerEntryEditorScreen({super.key, this.entry});

  final PrayerEntry? entry;

  @override
  State<PrayerEntryEditorScreen> createState() => _PrayerEntryEditorScreenState();
}

class _PrayerEntryEditorScreenState extends State<PrayerEntryEditorScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _body = TextEditingController(text: widget.entry?.body);
  late final _prayingFor = TextEditingController(text: widget.entry?.prayingFor);
  late final _scripture = TextEditingController(text: widget.entry?.scriptureRef);
  late PrayerCategory _category = widget.entry?.category ?? PrayerCategory.request;
  late bool _shared = widget.entry?.sharedWithMentor ?? false;
  late PrayerEntry? _entry = widget.entry;
  bool _saving = false;

  bool get _isNew => _entry == null;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _prayingFor.dispose();
    _scripture.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final draft = PrayerEntry(
      id: _entry?.id ?? '',
      title: _title.text.trim(),
      body: _body.text,
      category: _category,
      prayingFor: _prayingFor.text,
      scriptureRef: _scripture.text,
      sharedWithMentor: _shared,
      createdAt: _entry?.createdAt ?? DateTime.now(),
    );
    await _run(() async {
      if (_isNew) {
        await _api.createPrayerEntry(draft);
      } else {
        await _api.updatePrayerEntry(draft);
      }
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _toggleAnswered() async {
    final entry = _entry!;
    if (entry.isAnswered) {
      await _run(() async {
        final updated = await _api.unmarkPrayerAnswered(entry.id);
        setState(() => _entry = updated);
      });
      return;
    }
    final note = await _askAnswerNote();
    if (note == null) return; // cancelled
    await _run(() async {
      final updated = await _api.markPrayerAnswered(entry.id, answerNote: note);
      setState(() => _entry = updated);
    });
  }

  Future<String?> _askAnswerNote() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prayer answered 🙌', style: TextStyle(fontFamily: 'Poppins')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 5000,
          decoration: const InputDecoration(hintText: 'How did God answer? (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Mark answered')),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this prayer?', style: TextStyle(fontFamily: 'Poppins')),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _api.deletePrayerEntry(_entry!.id);
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New prayer' : 'Prayer'),
          centerTitle: true,
          actions: [
            if (!_isNew)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: _saving ? null : _delete,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_entry?.isAnswered ?? false) _buildAnsweredBanner(_entry!),
              TextFormField(
                controller: _title,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'What are you praying about?'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a short title' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _body,
                maxLength: 5000,
                minLines: 4,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Your prayer (optional)', alignLabelWithHint: true),
              ),
              const SizedBox(height: 8),
              Text('Category', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: kCharcoal)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in PrayerCategory.values)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 16),
                      label: Text(c.label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                      selected: _category == c,
                      selectedColor: kPrimaryGold.withValues(alpha: 0.25),
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _prayingFor,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Praying for (optional)', hintText: 'e.g. Mom, my small group'),
              ),
              TextFormField(
                controller: _scripture,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Scripture (optional)', hintText: 'e.g. Philippians 4:6-7'),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: kSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  title: const Text('Share with my mentor', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _shared ? 'Your mentor can see this entry.' : 'Only you can see this entry.',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                  ),
                  value: _shared,
                  activeThumbColor: kPrimaryGold,
                  onChanged: (v) => setState(() => _shared = v),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isNew ? 'Save prayer' : 'Save changes',
                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              ),
              if (!_isNew) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _toggleAnswered,
                  icon: Icon(_entry!.isAnswered ? Icons.undo : Icons.check_circle_outline),
                  label: Text(_entry!.isAnswered ? 'Move back to active' : 'Mark as answered',
                      style: const TextStyle(fontFamily: 'Poppins')),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnsweredBanner(PrayerEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 6),
            Text('Answered ${formatPrayerDate(entry.answeredAt!)}',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Colors.green)),
          ]),
          if (entry.answerNote != null) ...[
            const SizedBox(height: 6),
            Text(entry.answerNote!, style: TextStyle(fontFamily: 'Poppins', color: kCharcoal)),
          ],
        ],
      ),
    );
  }
}
