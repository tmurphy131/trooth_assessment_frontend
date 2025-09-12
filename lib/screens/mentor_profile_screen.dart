import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.amber.withOpacity(.15),
                          backgroundImage: _avatarCtrl.text.trim().isNotEmpty ? NetworkImage(_avatarCtrl.text.trim()) : null,
                          child: _avatarCtrl.text.trim().isEmpty ? const Icon(Icons.person, color: Colors.amber) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _avatarCtrl,
                            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                            decoration: const InputDecoration(
                              labelText: 'Avatar URL',
                              labelStyle: TextStyle(color: Colors.amber),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                            ),
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
                  ],
                ),
    );
  }
}
