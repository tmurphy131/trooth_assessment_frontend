import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';

class MentorAgreementsScreen extends StatefulWidget {
  const MentorAgreementsScreen({super.key});

  @override
  State<MentorAgreementsScreen> createState() => _MentorAgreementsScreenState();
}

class _MentorAgreementsScreenState extends State<MentorAgreementsScreen> {
  final _api = ApiService();
  bool _loadingTemplates = true;
  bool _creating = false;
  String? _error;
  List<Map<String, dynamic>> _templates = [];

  // Form fields
  int? _selectedVersion;
  final _apprenticeEmailCtrl = TextEditingController();
  final _meetingLocationCtrl = TextEditingController();
  final _meetingDurationCtrl = TextEditingController(text: '60');
  bool _apprenticeIsMinor = false;
  bool _parentRequired = false;
  final _parentEmailCtrl = TextEditingController();

  // Created agreement state
  Map<String, dynamic>? _currentAgreement; // draft / awaiting_apprentice / etc
  bool _submitting = false;
  bool _resendingParent = false;
  bool _revoking = false;
  bool _loadingExisting = false;
  List<Map<String,dynamic>> _agreements = [];
  int _agreementsSkip = 0;
  final int _agreementsLimit = 25;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  _loadExisting();
  }

  Future<void> _loadTemplates() async {
    setState(() { _loadingTemplates = true; _error = null; });
    try {
      final list = await _api.listAgreementTemplates();
      setState(() {
        _templates = list.cast<Map<String, dynamic>>();
        if (_templates.isNotEmpty) {
          _selectedVersion = _templates.first['version'] as int?;
        }
        _loadingTemplates = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load templates: $e'; _loadingTemplates = false; });
    }
  }

  Future<void> _createAgreement() async {
    if (_selectedVersion == null || _apprenticeEmailCtrl.text.isEmpty) return;
    setState(() { _creating = true; _error = null; _currentAgreement = null; });
    try {
      final ag = await _api.createAgreement(
        templateVersion: _selectedVersion!,
        apprenticeEmail: _apprenticeEmailCtrl.text.trim(),
        fields: {
          'meeting_location': _meetingLocationCtrl.text.trim().isEmpty ? 'TBD' : _meetingLocationCtrl.text.trim(),
          'meeting_duration_minutes': int.tryParse(_meetingDurationCtrl.text.trim()) ?? 60,
        },
        apprenticeIsMinor: _apprenticeIsMinor,
        parentRequired: _parentRequired,
        parentEmail: _parentRequired ? _parentEmailCtrl.text.trim() : null,
      );
      setState(() { _currentAgreement = ag; });
      await _loadExisting(refresh: true);
    } catch (e) {
      setState(() { _error = 'Create failed: $e'; });
    } finally {
      setState(() { _creating = false; });
    }
  }

  Future<void> _loadExisting({bool refresh = false}) async {
    if (refresh) { _agreementsSkip = 0; _agreements = []; }
    setState(() { _loadingExisting = true; });
    try {
      final list = await _api.listAgreements(skip: _agreementsSkip, limit: _agreementsLimit);
      setState(() {
        if (refresh) {
          _agreements = list.cast<Map<String,dynamic>>();
        } else {
          _agreements.addAll(list.cast<Map<String,dynamic>>());
        }
      });
    } catch (e) {
      setState(() { _error = 'Load agreements failed: $e'; });
    } finally {
      setState(() { _loadingExisting = false; });
    }
  }

  Future<void> _submitAgreement() async {
    if (_currentAgreement == null) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final updated = await _api.submitAgreement(_currentAgreement!['id']);
      setState(() { _currentAgreement = updated; });
    } catch (e) {
      setState(() { _error = 'Submit failed: $e'; });
    } finally {
      setState(() { _submitting = false; });
    }
  }

  Future<void> _resendParent() async {
    if (_currentAgreement == null) return;
    setState(() { _resendingParent = true; _error = null; });
    try {
      final updated = await _api.resendParentToken(agreementId: _currentAgreement!['id']);
      setState(() { _currentAgreement = updated; });
      _showSnack('Parent token resent');
    } catch (e) {
      setState(() { _error = 'Resend failed: $e'; });
    } finally {
      setState(() { _resendingParent = false; });
    }
  }

  Future<void> _revokeAgreement() async {
    if (_currentAgreement == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Revoke Agreement', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to revoke this agreement?', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.amber))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Revoke', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _revoking = true; _error = null; });
    try {
      final updated = await _api.revokeAgreement(_currentAgreement!['id']);
      setState(() { _currentAgreement = updated; });
      _showSnack('Agreement revoked');
    } catch (e) {
      setState(() { _error = 'Revoke failed: $e'; });
    } finally {
      setState(() { _revoking = false; });
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.amber, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Mentor Agreements', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: _loadingTemplates ? null : _loadTemplates,
          )
        ],
      ),
      body: _loadingTemplates
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
                      child: Text(_error!, style: const TextStyle(color: Colors.red, fontFamily: 'Poppins')),
                    ),
                  const Text('Create Agreement', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                  const SizedBox(height: 12),
                  _buildCreateForm(),
                  const SizedBox(height: 24),
                  if (_currentAgreement != null) _buildAgreementStatusCard(),
                  const SizedBox(height: 32),
                  _buildExistingAgreementsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCreateForm() {
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              value: _selectedVersion,
              decoration: const InputDecoration(labelText: 'Template Version'),
              dropdownColor: Colors.grey[900],
              items: _templates.map((t) => DropdownMenuItem<int>(
                value: t['version'] as int?,
                child: Text('v${t['version']} - ${(t['notes'] ?? '')}'.trim(), style: const TextStyle(color: Colors.white)),
              )).toList(),
              onChanged: (v) => setState(() => _selectedVersion = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apprenticeEmailCtrl,
              decoration: const InputDecoration(labelText: 'Apprentice Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _meetingLocationCtrl,
              decoration: const InputDecoration(labelText: 'Meeting Location (token: {{meeting_location}})'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _meetingDurationCtrl,
              decoration: const InputDecoration(labelText: 'Meeting Duration (minutes)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _apprenticeIsMinor,
              activeColor: Colors.amber,
              contentPadding: EdgeInsets.zero,
              title: const Text('Apprentice is a minor', style: TextStyle(color: Colors.white)),
              onChanged: (v) => setState(() { _apprenticeIsMinor = v; if (!v) { _parentRequired = false; } }),
            ),
            if (_apprenticeIsMinor)
              SwitchListTile(
                value: _parentRequired,
                activeColor: Colors.amber,
                contentPadding: EdgeInsets.zero,
                title: const Text('Parent signature required', style: TextStyle(color: Colors.white)),
                onChanged: (v) => setState(() { _parentRequired = v; }),
              ),
            if (_parentRequired)
              TextFormField(
                controller: _parentEmailCtrl,
                decoration: const InputDecoration(labelText: 'Parent Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.note_add),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: _creating ? null : _createAgreement,
                label: Text(_creating ? 'Creating...' : 'Create Draft'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreementStatusCard() {
    final ag = _currentAgreement!;
    final status = ag['status'];
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Agreement Status', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status, style: TextStyle(color: _statusColor(status), fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                )
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == 'draft')
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitAgreement,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: Text(_submitting ? 'Submitting...' : 'Submit to Apprentice'),
                  ),
                if (status == 'awaiting_parent')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    onPressed: _resendingParent ? null : _resendParent,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                    label: Text(_resendingParent ? 'Resending...' : 'Resend Parent Link'),
                  ),
                if (status != 'revoked' && status != 'expired')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.block),
                    onPressed: _revoking ? null : _revokeAgreement,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    label: Text(_revoking ? 'Revoking...' : 'Revoke'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Apprentice Email: ${ag['apprentice_email']}', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            if (ag['parent_email'] != null) Text('Parent Email: ${ag['parent_email']}', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            if (ag['apprentice_signature_name'] != null) Text('Apprentice Signed: ${ag['apprentice_signature_name']}', style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Poppins')),
            if (ag['parent_signature_name'] != null) Text('Parent Signed: ${ag['parent_signature_name']}', style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Poppins')),
            if (ag['content_rendered'] != null) ...[
              const SizedBox(height: 12),
              const Text('Agreement Preview', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(.25), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[800]!)),
                constraints: const BoxConstraints(maxHeight: 300),
                child: Markdown(
                  data: ag['content_rendered'],
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13, height: 1.25),
                    h1: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.bold),
                    h2: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold),
                    h3: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.bold),
                    strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    blockquote: TextStyle(color: Colors.grey[300], fontStyle: FontStyle.italic),
                    code: const TextStyle(fontFamily: 'monospace', color: Colors.lightBlueAccent),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showFullMarkdown(ag['content_rendered']),
                  child: const Text('Expand', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                ),
              )
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExistingAgreementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Existing Agreements', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const Spacer(),
            IconButton(
              onPressed: () => _loadExisting(refresh: true),
              icon: const Icon(Icons.refresh, color: Colors.amber),
              tooltip: 'Refresh',
            )
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingExisting && _agreements.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.amber))),
        if (!_loadingExisting && _agreements.isEmpty)
          Text('No agreements yet', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')),
        ..._agreements.map(_buildAgreementListTile),
        if (_agreements.length >= (_agreementsSkip + _agreementsLimit))
          TextButton(
            onPressed: _loadingExisting ? null : () { _agreementsSkip += _agreementsLimit; _loadExisting(); },
            child: _loadingExisting ? const CircularProgressIndicator() : const Text('Load more', style: TextStyle(color: Colors.amber)),
          )
      ],
    );
  }

  Widget _buildAgreementListTile(Map<String,dynamic> ag) {
    final status = ag['status'];
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withOpacity(.2),
          child: Icon(Icons.description, color: _statusColor(status)),
        ),
        title: Text(ag['apprentice_email'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        subtitle: Text(status, style: TextStyle(color: _statusColor(status), fontFamily: 'Poppins')),
        onTap: () async {
          // Fetch latest details & show
          try {
            final full = await _api.getAgreement(ag['id']);
            setState(() { _currentAgreement = full; });
            _showSnack('Loaded agreement');
          } catch (e) {
            _showSnack('Failed to fetch agreement');
          }
        },
      ),
    );
  }

  void _showFullMarkdown(String markdown) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.grey[900],
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 600),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Agreement Content', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.amber))
                ],
              ),
              const Divider(color: Colors.grey),
              Expanded(
                child: Markdown(
                  data: markdown,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14, height: 1.3),
                    h1: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.bold),
                    h2: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.bold),
                    h3: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold),
                    code: const TextStyle(fontFamily: 'monospace', color: Colors.lightBlueAccent),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft': return Colors.grey;
      case 'awaiting_apprentice': return Colors.orange;
      case 'awaiting_parent': return Colors.purple;
      case 'fully_signed': return Colors.green;
      case 'revoked': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  void dispose() {
    _apprenticeEmailCtrl.dispose();
    _meetingLocationCtrl.dispose();
    _meetingDurationCtrl.dispose();
    _parentEmailCtrl.dispose();
    super.dispose();
  }
}
