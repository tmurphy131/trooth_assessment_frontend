import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? role; // 'mentor' or 'apprentice'
  bool _isSaving = false;

  Future<void> _completeOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || role == null) return;

    setState(() => _isSaving = true); // 🌀 Start spinner

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await docRef.set({
        'name': user.displayName ?? '',
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
                  "Choose your role to get started:",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                RadioListTile<String>(
                  title: const Text("Mentor", style: TextStyle(color: Colors.white)),
                  activeColor: Color(0xFFFFD700),
                  value: 'mentor',
                  groupValue: role,
                  onChanged: _isSaving ? null : (value) => setState(() => role = value),
                ),
                RadioListTile<String>(
                  title: const Text("Apprentice", style: TextStyle(color: Colors.white)),
                  activeColor: Color(0xFFFFD700),
                  value: 'apprentice',
                  groupValue: role,
                  onChanged: _isSaving ? null : (value) => setState(() => role = value),
                ),
                const SizedBox(height: 24),
                _isSaving
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFFFD700)),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: role != null ? _completeOnboarding : null,
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
