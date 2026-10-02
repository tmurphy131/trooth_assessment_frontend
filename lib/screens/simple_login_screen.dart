import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../firebase_options.dart';

import 'signup_screen.dart';
import 'role_selection_screen.dart';
import '../utils/role_cache.dart';
import '../utils/errors.dart';

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
    // Close the keyboard before the app switches screens; otherwise it can
    // stay up over the dashboard.
    FocusManager.instance.primaryFocus?.unfocus();
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
      if (role != null) await cacheRole(cred.user!.uid, role);
      // AuthGate (at /) routes by role, or to signup if the profile is missing.
      if (!mounted) return;
      context.go('/');
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

  /// Navigate to appropriate dashboard based on user role
  Future<void> _navigateBasedOnRole(User user, {bool isNewUser = false, String? displayName, String? email}) async {
    // If this is a brand new OAuth user, extract their info and go to role selection
    // (Firebase Auth account exists but Firestore profile doesn't)
    if (isNewUser) {
      // Extract display name and email from OAuth provider
      final name = displayName ?? user.displayName ?? '';
      final userEmail = email ?? user.email ?? '';
      
      if (!mounted) return;
      // Pushed (not replaced): /login is a router page.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoleSelectionScreen(
            displayName: name,
            email: userEmail,
          ),
        ),
      );
      return;
    }
    
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    final role = data?['role'] as String?;
    if (role != null) await cacheRole(user.uid, role);
    
    if (!mounted) return;
    
    // AuthGate (at /) routes by role, or to signup if the profile is missing.
    context.go('/');
  }

  /// Forgot Password - sends password reset email via Firebase
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address first')),
      );
      return;
    }
    
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      
      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Check Your Email',
            style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          ),
          content: Text(
            'We\'ve sent a password reset link to $email. Please check your inbox and follow the instructions to reset your password.',
            style: TextStyle(color: Colors.grey.shade300, fontFamily: 'Poppins'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.amber, fontFamily: 'Poppins'),
              ),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email address.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        default:
          message = e.message ?? 'Failed to send reset email. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static Future<void>? _googleInit;

  /// google_sign_in 7 must be initialized once before use. Android's
  /// Credential Manager needs the web OAuth client as serverClientId to issue
  /// an ID token Firebase accepts; iOS uses its own client ID.
  static Future<void> _initGoogleSignIn() => _googleInit ??= GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS ? DefaultFirebaseOptions.ios.iosClientId : null,
        serverClientId: Platform.isAndroid ? _googleWebClientId : null,
      );

  // client_type 3 in android/app/google-services.json
  static const _googleWebClientId =
      '557349072084-mrv2vcpgroue179src3hfd00emhvbo8a.apps.googleusercontent.com';

  /// Google Sign-In
  Future<void> _signInWithGoogle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    try {
      await _initGoogleSignIn();
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          if (mounted) setState(() => _isLoading = false);
          return; // user closed the sheet; not an error
        }
        rethrow;
      }

      // Firebase only needs the ID token.
      final credential = GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      
      // Check if this is a brand new user (OAuth creates Firebase Auth account automatically)
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      
      // Extract user info from Google
      final displayName = userCredential.user?.displayName ?? 
                         googleUser.displayName ?? 
                         googleUser.email.split('@').first;
      final email = userCredential.user?.email ?? googleUser.email;
      
      await _navigateBasedOnRole(
        userCredential.user!, 
        isNewUser: isNewUser,
        displayName: displayName,
        email: email,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Apple Sign-In
  Future<void> _signInWithApple() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    try {
      // Nonce binds Apple's identity token to this sign-in attempt so it
      // can't be replayed (Firebase verifies the SHA-256 of rawNonce).
      final rawNonce = _generateNonce();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      if (!mounted) return;
      
      // Check if this is a brand new user (OAuth creates Firebase Auth account automatically)
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      
      // Extract user info from Apple
      // Apple only provides name on FIRST sign-in, so we need to capture it here
      String displayName = userCredential.user?.displayName ?? '';
      if (displayName.isEmpty && appleCredential.givenName != null) {
        // Build name from Apple's givenName and familyName
        final parts = <String>[];
        if (appleCredential.givenName?.isNotEmpty == true) {
          parts.add(appleCredential.givenName!);
        }
        if (appleCredential.familyName?.isNotEmpty == true) {
          parts.add(appleCredential.familyName!);
        }
        displayName = parts.join(' ');
        
        // Update Firebase user's display name if we got it from Apple
        if (displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
        }
      }
      
      // Use fallback if still no name
      if (displayName.isEmpty) {
        displayName = userCredential.user?.email?.split('@').first ?? 'User';
      }
      
      final email = userCredential.user?.email ?? appleCredential.email ?? '';
      
      await _navigateBasedOnRole(
        userCredential.user!,
        isNewUser: isNewUser,
        displayName: displayName,
        email: email,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple sign-in failed: ${friendlyError(e)}')),
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
    final isVerySmall = size.height < 680;
    final isTablet = size.shortestSide >= 600;
    final maxFormWidth = isTablet ? 400.0 : double.infinity;
    final logoWidth = isTablet ? 350.0 : size.width - 48; // Constrain logo on tablet
    final sectionGap = isVerySmall ? 12.0 : (isSmall ? 16.0 : 24.0);
    final pagePadding = EdgeInsets.symmetric(horizontal: isSmall ? 16.0 : 24.0, vertical: 8.0);
    final titleFontSize = isSmall ? 24.0 : 28.0;
    final buttonHeight = isSmall ? 48.0 : 52.0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: pagePadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _LoginDebugBadge(),
                    // Logo - cropped version, nearly full width
                    Image.asset(
                      'assets/logo.png',
                      width: logoWidth,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if logo fails to load
                        return Container(
                          width: logoWidth,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.amber),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'T[root]H',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
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
                    const SizedBox(height: 4),
                    
                    // Subtitle
                    Text(
                      '#getrooted',
                      style: TextStyle(
                        color: Colors.amber.shade300,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: sectionGap),

                    // Email field
                    SizedBox(
                      height: 52,
                      child: TextFormField(
                        controller: _emailController,
                        decoration: _fieldDecoration('Email'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
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
                  ),
                  const SizedBox(height: 12),

                  // Password field
                  SizedBox(
                    height: 52,
                    child: TextFormField(
                      controller: _passwordController,
                      decoration: _fieldDecoration('Password'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 14,
                      ),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
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
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.amber.shade300,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: sectionGap),

                  // Divider with "or"
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade600)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontFamily: 'Poppins',
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade600)),
                    ],
                  ),
                  SizedBox(height: sectionGap),

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: Image.asset(
                        'assets/google_logo.png',
                        height: 20,
                        width: 20,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.g_mobiledata,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Apple Sign-In Button (only show on iOS)
                  if (Platform.isIOS)
                    SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithApple,
                        icon: const Icon(
                          Icons.apple,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'Sign in with Apple',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                if (Platform.isIOS) const SizedBox(height: 16),
                if (!Platform.isIOS) const SizedBox(height: 8),

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
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        child: const Text('LOGIN', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2)),
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
