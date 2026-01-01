import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'simple_login_screen.dart';

class MentorProfileScreen extends StatefulWidget {
  const MentorProfileScreen({super.key});

  @override
  State<MentorProfileScreen> createState() => _MentorProfileScreenState();
}

class _MentorProfileScreenState extends State<MentorProfileScreen> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await _api.getMyMentorProfile();
      _nameCtrl.text = (p['name'] ?? '').toString();
      _emailCtrl.text = (p['email'] ?? '').toString();
      _roleCtrl.text = (p['role_title'] ?? '').toString();
      _orgCtrl.text = (p['organization'] ?? '').toString();
      _phoneCtrl.text = (p['phone'] ?? '').toString();
      _avatarCtrl.text = (p['avatar_url'] ?? '').toString();
      _bioCtrl.text = (p['bio'] ?? '').toString();
    } catch (e) {
      _error = 'Failed to load: $e';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() { _loading = true; });
    try {
      await _api.updateMyMentorProfile(
        avatarUrl: _avatarCtrl.text.trim().isNotEmpty ? _avatarCtrl.text.trim() : null,
        roleTitle: _roleCtrl.text.trim().isNotEmpty ? _roleCtrl.text.trim() : null,
        organization: _orgCtrl.text.trim().isNotEmpty ? _orgCtrl.text.trim() : null,
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        bio: _bioCtrl.text.trim().isNotEmpty ? _bioCtrl.text.trim() : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Widget _buildAvatarPreview() {
    final url = _avatarCtrl.text.trim();
    if (url.isEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.amber.withOpacity(.15),
        child: const Icon(Icons.person, color: Colors.amber),
      );
    }
    // Validate URL format
    final isValidUrl = Uri.tryParse(url)?.hasAbsolutePath == true && 
                       (url.startsWith('http://') || url.startsWith('https://'));
    if (!isValidUrl) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.red.withOpacity(.15),
        child: const Icon(Icons.error_outline, color: Colors.red),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: 60,
        height: 60,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.amber.withOpacity(.15),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.red.withOpacity(.15),
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.red),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _roleCtrl.dispose();
    _orgCtrl.dispose();
    _phoneCtrl.dispose();
    _avatarCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, color: Colors.amber)),
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Save', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        _buildAvatarPreview(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _avatarCtrl,
                            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                            decoration: const InputDecoration(
                              labelText: 'Avatar URL',
                              labelStyle: TextStyle(color: Colors.amber),
                              hintText: 'https://example.com/photo.jpg',
                              hintStyle: TextStyle(color: Colors.grey),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                            ),
                            onChanged: (_) => setState(() {}), // Refresh avatar preview
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.amber),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.amber),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _roleCtrl,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Role/Title',
                        labelStyle: TextStyle(color: Colors.amber),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _orgCtrl,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Organization',
                        labelStyle: TextStyle(color: Colors.amber),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        labelStyle: TextStyle(color: Colors.amber),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bioCtrl,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        labelStyle: TextStyle(color: Colors.amber),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 16),
                    // Danger Zone - Close Account
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red.shade700, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Danger Zone',
                                style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Once you close your account, all of your data will be permanently deleted. This action cannot be undone.',
                            style: TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _showCloseAccountDialog,
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              label: const Text('Close Account', style: TextStyle(color: Colors.red, fontFamily: 'Poppins')),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Future<void> _showCloseAccountDialog() async {
    bool confirmed = false;
    Map<String, dynamic>? deletionSummary;
    bool loadingSummary = true;

    // Load deletion summary first
    try {
      deletionSummary = await _api.getAccountDeletionSummary();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load account data: $e'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    loadingSummary = false;

    if (!mounted) return;

    final items = deletionSummary?['items_to_delete'] as Map<String, dynamic>? ?? {};

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
              const SizedBox(width: 8),
              const Text('Close Account', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is PERMANENT and cannot be undone.',
                  style: TextStyle(color: Colors.red, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The following data will be permanently deleted:',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 12),
                if (loadingSummary)
                  const Center(child: CircularProgressIndicator(color: Colors.amber))
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var entry in items.entries)
                          if (entry.value > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.remove_circle_outline, color: Colors.red, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${entry.value} ${_formatItemName(entry.key)}',
                                    style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                        if (items.values.every((v) => v == 0))
                          const Text(
                            'No associated data found.',
                            style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: confirmed,
                        onChanged: (v) => setDialogState(() => confirmed = v ?? false),
                        activeColor: Colors.red,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'I understand that this action is permanent and all my data will be deleted forever.',
                        style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
            ),
            ElevatedButton(
              onPressed: confirmed ? () => _executeCloseAccount(ctx) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmed ? Colors.red : Colors.grey[700],
              ),
              child: const Text('Delete My Account', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            ),
          ],
        ),
      ),
    );
  }

  String _formatItemName(String key) {
    // Convert snake_case to readable format
    return key.replaceAll('_', ' ').replaceAllMapped(
      RegExp(r'(^|\s)(\w)'),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
    );
  }

  Future<void> _executeCloseAccount(BuildContext dialogContext) async {
    Navigator.of(dialogContext).pop(); // Close dialog first

    setState(() { _loading = true; });

    try {
      await _api.closeAccount(confirmationText: 'DELETE');

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Navigate to login screen and clear the navigation stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SimpleLoginScreen()),
        (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been successfully closed.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to close account: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
