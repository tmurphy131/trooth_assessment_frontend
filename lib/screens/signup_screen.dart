import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _role; // mentor | apprentice
  bool _showPassword = false;
  bool _isLoading = false;
  String? _error;
  bool _acceptedPrivacy = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a role')));
      return;
    }
    if (!_acceptedPrivacy || !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Privacy Policy and Terms of Service')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final first = _firstController.text.trim();
      final last = _lastController.text.trim();
      final fullName = [first, last].where((e) => e.isNotEmpty).join(' ');
      if (fullName.isNotEmpty) {
        await cred.user!.updateDisplayName(fullName);
      }

      // Backend user creation (ignore conflict duplicates gracefully)
      try {
        await ApiService().createUser(
          uid: cred.user!.uid,
            email: _emailController.text.trim(),
          role: _role!,
          displayName: fullName.isNotEmpty ? fullName : null,
        );
      } catch (e) {
        final msg = e.toString();
        if (!(msg.contains('409') || msg.contains('exist') || msg.contains('Already'))) {
          debugPrint('createUser backend error: $msg');
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name': fullName,
        'first_name': first,
        'last_name': last,
        'email': _emailController.text.trim(),
        'role': _role,
        'onboarded': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      final Widget destination = _role == 'mentor'
          ? const MentorDashboardNew()
          : const ApprenticeDashboardNew();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Enter your details to get started.'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _firstController,
                  decoration: _dec('First Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'First name required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastController,
                  decoration: _dec('Last Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Last name required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: _dec('Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: _dec('Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                  obscureText: !_showPassword,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text('Role', style: TextStyle(fontWeight: FontWeight.w600)),
                RadioListTile<String>(
                  title: const Text('Mentor'),
                  value: 'mentor',
                  groupValue: _role,
                  onChanged: (v) => setState(() => _role = v),
                ),
                RadioListTile<String>(
                  title: const Text('Apprentice'),
                  value: 'apprentice',
                  groupValue: _role,
                  onChanged: (v) => setState(() => _role = v),
                ),
                if (_role == null)
                  const Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 8),
                    child: Text('Please select a role', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                const SizedBox(height: 16),
                // Privacy Policy consent
                CheckboxListTile(
                  value: _acceptedPrivacy,
                  onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Wrap(
                    children: [
                      const Text('I have read and agree to the '),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('https://onlyblv.com/privacy.html'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(color: Colors.amber, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
                // Terms of Service consent
                CheckboxListTile(
                  value: _acceptedTerms,
                  onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Wrap(
                    children: [
                      const Text('I have read and agree to the '),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('https://onlyblv.com/terms.html'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text(
                          'Terms of Service',
                          style: TextStyle(color: Colors.amber, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_acceptedPrivacy || !_acceptedTerms)
                  const Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 8),
                    child: Text('You must accept both to continue', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign Up'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Already have an account? Log in'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
