import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';
import 'signup_screen.dart';

class SimpleLoginScreen extends StatefulWidget {
  const SimpleLoginScreen({super.key});

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).get();
      final data = doc.data();
      final role = data?['role'] as String?; // could be null for legacy users
      if (role == 'mentor') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MentorDashboardNew()),
        );
      } else if (role == 'apprentice') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ApprenticeDashboardNew()),
        );
      } else {
        // Legacy user missing profile; send to signup to complete
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignupScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Login failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Login] build');
    // Responsive tweaks: shrink spacing/logo on smaller screens
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 750;
    final logoHeight = isSmall ? 200.0 : 300.0; // was 400 (too tall)
    final sectionGap = isSmall ? 20.0 : 32.0;  // reduce gaps on small screens
    final pagePadding = EdgeInsets.all(isSmall ? 16.0 : 24.0);
    final titleFontSize = isSmall ? 28.0 : 32.0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: pagePadding,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _LoginDebugBadge(),
                // Logo
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.asset(
                    'assets/logo.png',
                    height: logoHeight,
                    width: logoHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if logo fails to load
                      return Container(
                        height: logoHeight,
                        width: logoHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.amber),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'T[root]H',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: sectionGap),

                // Title
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  '#getrooted',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: sectionGap),

                // Extra fields for sign up
                // (Sign up fields removed; dedicated signup screen now handles account creation.)

                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: _fieldDecoration('Email'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: _fieldDecoration('Password'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Sign In',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Toggle button
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  ),
                  child: Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontFamily: 'Poppins',
                    ),
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

class _LoginDebugBadge extends StatefulWidget {
  const _LoginDebugBadge();
  @override
  State<_LoginDebugBadge> createState() => _LoginDebugBadgeState();
}

class _LoginDebugBadgeState extends State<_LoginDebugBadge> {
  bool _frameLogged = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_frameLogged) {
        _frameLogged = true;
        debugPrint('[Login] first frame rendered');
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.blueGrey.shade800, borderRadius: BorderRadius.circular(6)),
        child: const Text('LOGIN', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
      ),
    );
  }
}

// Shared decoration builder
InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: Colors.grey.shade300,
      fontFamily: 'Poppins',
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade600),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.amber, width: 2),
    ),
    filled: true,
    fillColor: Colors.grey.shade900,
  );
}
