part of 'simple_login_screen.dart';

// Builders for _SimpleLoginScreenState (spec 004 US3). Sign-in logic stays in simple_login_screen.dart.
extension _SimpleLoginScreenStateWidgets on _SimpleLoginScreenState {
  /// Apple (iOS only) first, then Google, then the way to the email form.
  Widget _buildSocialOptions({required double buttonHeight}) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Column(
      key: const ValueKey('social'),
      children: [
        if (isIOS) ...[
          SizedBox(
            width: double.infinity,
            child: SignInWithAppleButton(
              style: SignInWithAppleButtonStyle.white,
              height: buttonHeight,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              // The package requires a callback; ignore taps while signing in.
              onPressed: _isLoading ? () {} : _signInWithApple,
            ),
          ),
          const SizedBox(height: 12),
        ],
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
        if (_isLoading) ...[
          const SizedBox(height: 16),
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : _openEmailForm,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(
            'Continue with email',
            style: TextStyle(
              color: Colors.amber.shade300,
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// The existing email and password sign-in, moved unchanged behind "Continue with email".
  Widget _buildEmailForm({required double buttonHeight, required double sectionGap}) {
    return Column(
      key: const ValueKey('email'),
      children: [
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
                : const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
          ),
        ),
        SizedBox(height: sectionGap),

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
        TextButton.icon(
          onPressed: _isLoading ? null : _closeEmailForm,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: Icon(Icons.arrow_back, size: 18, color: Colors.grey.shade400),
          label: Text(
            'Back to sign-in options',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontFamily: 'Poppins',
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
