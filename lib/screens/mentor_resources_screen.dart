import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class MentorResourcesScreen extends StatefulWidget {
  const MentorResourcesScreen({super.key});

  @override
  State<MentorResourcesScreen> createState() => _MentorResourcesScreenState();
}

class _MentorResourcesScreenState extends State<MentorResourcesScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _apprentices = [];
  List<Map<String, dynamic>> _resources = [];
  String? _filterApprenticeId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final apprentices = await _api.listApprentices();
      final resources = await _api.listMentorResources();
      setState(() {
        _apprentices = apprentices.cast<Map<String, dynamic>>();
        _resources = resources.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load: $e'; _loading = false; });
    }
  }

  Future<void> _applyFilter(String? apprenticeId) async {
    setState(() { _filterApprenticeId = apprenticeId; _loading = true; _error = null; });
    try {
      final resources = await _api.listMentorResources(apprenticeId: apprenticeId);
      setState(() { _resources = resources.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load resources: $e'; _loading = false; });
    }
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
  }

  Future<void> _createOrEdit({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final linkCtrl = TextEditingController(text: existing?['link_url'] ?? '');
  String? apprenticeId = existing?['apprentice_id'] as String?;
    bool isShared = (existing?['is_shared'] ?? true) == true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(isEdit ? 'Edit Resource' : 'New Resource', style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.amber),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: TextStyle(color: Colors.amber),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    decoration: const InputDecoration(
                      labelText: 'Link URL (https://...)',
                      labelStyle: TextStyle(color: Colors.amber),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: apprenticeId,
                    isExpanded: true,
                    dropdownColor: Colors.grey[900],
                    iconEnabledColor: Colors.amber,
                    decoration: const InputDecoration(
                      labelText: 'Apprentice (optional)',
                      labelStyle: TextStyle(color: Colors.amber),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('— None —', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                      ),
                      const DropdownMenuItem<String>(
                        value: '__ALL__',
                        child: Text('All Apprentices', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                      ),
                      ..._apprentices.map((a) => DropdownMenuItem<String>(
                        value: a['id'] as String,
                        child: Text(a['name'] ?? a['email'] ?? 'Unnamed', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                      )),
                    ],
                    onChanged: (v) => setState(() { apprenticeId = v; }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Share with apprentice', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                      const Spacer(),
                      Switch(
                        value: isShared,
                        activeColor: Colors.amber,
                        onChanged: (v) => setState(() { isShared = v; }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: saving ? null : () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  setState(() { saving = true; });
                  try {
                    if (isEdit) {
                      await _api.updateMentorResource(
                        resourceId: existing['id'],
                        apprenticeId: (apprenticeId == null || (apprenticeId?.isEmpty ?? true)) ? null : apprenticeId,
                        title: title,
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        linkUrl: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
                        isShared: isShared,
                      );
                    } else {
                      await _api.createMentorResource(
                        apprenticeId: (apprenticeId == null || (apprenticeId?.isEmpty ?? true)) ? null : apprenticeId,
                        title: title,
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        linkUrl: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
                        isShared: isShared,
                      );
                    }
                    if (!mounted) return;
                    Navigator.of(ctx).pop();
                    await _applyFilter(_filterApprenticeId);
                  } catch (e) {
                    setState(() { saving = false; });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                  }
                },
                child: saving
                    ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.black))
                    : Text(isEdit ? 'Save' : 'Create'),
              )
            ],
          ),
        );
      }
    );
  }

  Future<void> _toggleShare(Map<String, dynamic> r) async {
    try {
      await _api.updateMentorResource(resourceId: r['id'], isShared: !(r['is_shared'] == true));
      await _applyFilter(_filterApprenticeId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  Future<void> _deleteResource(Map<String, dynamic> r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Resource', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${r['title']}"?', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          )
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteMentorResource(r['id']);
      await _applyFilter(_filterApprenticeId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Resources', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _loading ? null : () => _applyFilter(_filterApprenticeId), icon: const Icon(Icons.refresh, color: Colors.amber))
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        onPressed: () => _createOrEdit(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterApprenticeId,
                    isExpanded: true,
                    dropdownColor: Colors.grey[900],
                    iconEnabledColor: Colors.amber,
                    decoration: const InputDecoration(
                      labelText: 'Filter by apprentice',
                      labelStyle: TextStyle(color: Colors.amber),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All apprentices', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                      ),
                      ..._apprentices.map((a) => DropdownMenuItem<String>(
                        value: a['id'] as String,
                        child: Text(a['name'] ?? a['email'] ?? 'Unnamed', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                      )),
                    ],
                    onChanged: (v) => _applyFilter(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.amber)))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.white))))
            else if (_resources.isEmpty)
              Expanded(child: Center(child: Text('No resources yet', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'))))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _resources.length,
                  itemBuilder: (context, index) {
                    final r = _resources[index];
                    final title = (r['title'] ?? '').toString();
                    final desc = (r['description'] ?? '').toString();
                    final url = (r['link_url'] ?? '').toString();
                    final shared = r['is_shared'] == true;
                    return Card(
                      color: Colors.grey[850],
                      child: ListTile(
                        leading: Icon(shared ? Icons.public : Icons.lock, color: shared ? Colors.greenAccent : Colors.amber),
                        title: Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (desc.isNotEmpty) Text(desc, style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')),
                            if (url.isNotEmpty) Text(url, style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins'), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        onTap: () => _openLink(url),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            Switch(
                              value: shared,
                              activeColor: Colors.amber,
                              onChanged: (_) => _toggleShare(r),
                            ),
                            PopupMenuButton<String>(
                              color: Colors.grey[900],
                              iconColor: Colors.white,
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _createOrEdit(existing: r);
                                } else if (v == 'delete') {
                                  _deleteResource(r);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white, fontFamily: 'Poppins'))),
                                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent, fontFamily: 'Poppins'))),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
