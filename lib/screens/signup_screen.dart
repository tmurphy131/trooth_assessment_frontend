import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding_screen.dart';


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool showPassword = false;
  String? error;

  Future<void> _signUp() async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await credential.user?.updateDisplayName(nameController.text.trim());

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Create Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
            const SizedBox(height: 12),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => showPassword = !showPassword),
                ),
              ),
              obscureText: !showPassword,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _signUp, child: const Text("Sign Up")),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Already have an account? Log in"),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
