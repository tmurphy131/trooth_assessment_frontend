import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'simple_login_screen.dart';

class ApprenticeProfileScreen extends StatefulWidget {
  const ApprenticeProfileScreen({super.key});

  @override
  State<ApprenticeProfileScreen> createState() => _ApprenticeProfileScreenState();
}

class _ApprenticeProfileScreenState extends State<ApprenticeProfileScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  String _name = '';
  String _email = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await _api.getUserProfile(user.uid);
        _name = (profile['name'] ?? '').toString();
        _email = (profile['email'] ?? '').toString();
        _role = (profile['role'] ?? '').toString();
      }
    } catch (e) {
      _error = 'Failed to load profile: $e';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.amber),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.amber.withOpacity(.15),
                        child: const Icon(Icons.person, color: Colors.amber, size: 50),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Name
                    _buildInfoCard(
                      icon: Icons.person_outline,
                      label: 'Name',
                      value: _name.isNotEmpty ? _name : 'Not set',
                    ),
                    const SizedBox(height: 12),
                    // Email
                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: _email.isNotEmpty ? _email : 'Not set',
                    ),
                    const SizedBox(height: 12),
                    // Role
                    _buildInfoCard(
                      icon: Icons.school_outlined,
                      label: 'Role',
                      value: _role.isNotEmpty ? _capitalizeFirst(_role) : 'Apprentice',
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
                            'Once you close your account, all of your data will be permanently deleted. This includes your assessments, drafts, agreements, and relationship with your mentor. This action cannot be undone.',
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

  Widget _buildInfoCard({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
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
