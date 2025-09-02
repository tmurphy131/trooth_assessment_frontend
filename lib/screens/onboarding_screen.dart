import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import '../utils/onboarding_validation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? role; // 'mentor' or 'apprentice'
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  bool _isSaving = false;
  // Field-level errors
  String? _firstError;
  String? _lastError;
  String? _roleError;
  bool _firstTouched = false;
  bool _lastTouched = false;

  bool get _canContinue =>
      _firstError == null &&
      _lastError == null &&
      _roleError == null &&
      firstNameController.text.trim().isNotEmpty &&
      lastNameController.text.trim().isNotEmpty &&
      role != null &&
      !_isSaving;

  void _runValidation({bool forceAll = false}) {
    final result = validateOnboarding(
      firstNameController.text,
      lastNameController.text,
      role,
    );
    setState(() {
      // Only show if field touched or forcing
      _firstError = (forceAll || _firstTouched) ? result.firstNameError : null;
      _lastError = (forceAll || _lastTouched) ? result.lastNameError : null;
      _roleError = (forceAll || role != null) ? result.roleError : null;
    });
  }

  Future<void> _completeOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
  if (user == null || role == null) return;

  final first = firstNameController.text.trim();
  final last = lastNameController.text.trim();
  final fullName = [first, last].where((e) => e.isNotEmpty).join(' ');
    _firstTouched = true; _lastTouched = true; // ensure errors show
    _runValidation(forceAll: true);
    if (_firstError != null || _lastError != null || _roleError != null) return;

    setState(() => _isSaving = true); // 🌀 Start spinner

    try {
      // Update Firebase Auth display name if provided
      if (fullName.isNotEmpty && user.displayName != fullName) {
        await user.updateDisplayName(fullName);
      }

      // Create / update backend user (API) with role + display name
      try {
        await ApiService().createUser(
          uid: user.uid,
          email: user.email ?? '',
          role: role!,
          displayName: fullName.isNotEmpty ? fullName : null,
        );
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('409') || msg.contains('Already') || msg.contains('already')) {
          debugPrint('Duplicate user on backend – proceeding.');
        } else {
          debugPrint('Backend createUser failed: $msg');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Server sync issue: $msg')),
            );
          }
        }
      }

      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await docRef.set({
        'name': fullName.isNotEmpty ? fullName : (user.displayName ?? ''),
        'email': user.email,
        'role': role,
        'onboarded': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Widget dashboard = switch (role) {
        'mentor' => const MentorDashboardNew(),
        'apprentice' => const ApprenticeDashboardNew(),
        _ => const Scaffold(body: Center(child: Text("Unknown role")))
      };

      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => dashboard));
    } catch (e) {
      // Optional: Show error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false); // ✅ End spinner
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          color: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/logo.png", height: 80),
                const SizedBox(height: 16),
                const Text(
                  "Welcome to T[root]H",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Enter your name and choose your role:",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: firstNameController,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    errorText: _firstError,
                  ),
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp("[a-zA-Z-' ]"))],
                  onChanged: (_) {
                    _firstTouched = true;
                    _runValidation();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    errorText: _lastError,
                  ),
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp("[a-zA-Z-' ]"))],
                  onChanged: (_) {
                    _lastTouched = true;
                    _runValidation();
                  },
                ),
                const SizedBox(height: 20),
                RadioListTile<String>(
                  title: const Text("Mentor", style: TextStyle(color: Colors.white)),
                  activeColor: Color(0xFFFFD700),
                  value: 'mentor',
                  groupValue: role,
                      onChanged: _isSaving ? null : (value) {
                        setState(() { role = value; });
                        _runValidation();
                      },
                ),
                RadioListTile<String>(
                  title: const Text("Apprentice", style: TextStyle(color: Colors.white)),
                  activeColor: Color(0xFFFFD700),
                  value: 'apprentice',
                  groupValue: role,
                  onChanged: _isSaving ? null : (value) {
                    setState(() { role = value; });
                    _runValidation();
                  },
                ),
                if (_roleError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_roleError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 24),
                _isSaving
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFFFD700)),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _canContinue ? _completeOnboarding : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                            textStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Continue"),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
