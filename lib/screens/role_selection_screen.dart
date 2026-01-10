import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';

/// Screen shown to OAuth users after authentication to select their role
/// This screen does NOT ask for name/email since that's already provided by OAuth
class RoleSelectionScreen extends StatefulWidget {
  final String displayName;
  final String email;
  
  const RoleSelectionScreen({
    super.key,
    required this.displayName,
    required this.email,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoading = false;
  bool _acceptedPrivacy = false;
  bool _acceptedTerms = false;

  Future<void> _completeSetup() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role')),
      );
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
      final currentUser = FirebaseAuth.instance.currentUser!;
      
      // Split display name into first/last
      final parts = widget.displayName.split(' ');
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      
      // Create backend user
      try {
        await ApiService().createUser(
          uid: currentUser.uid,
          email: widget.email,
          role: _selectedRole!,
          displayName: widget.displayName.isNotEmpty ? widget.displayName : null,
        );
      } catch (e) {
        final msg = e.toString();
        // Ignore duplicate user errors (409 conflict)
        if (!(msg.contains('409') || msg.contains('exist') || msg.contains('Already'))) {
          debugPrint('createUser backend error: $msg');
        }
      }

      // Create Firestore profile
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
        'name': widget.displayName,
        'first_name': firstName,
        'last_name': lastName,
        'email': widget.email,
        'role': _selectedRole,
        'onboarded': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      // Navigate to appropriate dashboard
      final destination = _selectedRole == 'mentor'
          ? const MentorDashboardNew()
          : const ApprenticeDashboardNew();
          
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final maxWidth = isTablet ? 500.0 : double.infinity;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text(
          'Complete Setup',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome message
                  Text(
                    'Welcome, ${widget.displayName.split(' ').first}!',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'One more step: Choose your role',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Role selection cards
                  _buildRoleCard(
                    role: 'mentor',
                    title: 'Mentor',
                    description: 'Guide and support apprentices in their spiritual journey',
                    icon: Icons.school,
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    role: 'apprentice',
                    title: 'Apprentice',
                    description: 'Learn and grow under the guidance of a mentor',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 32),
                  
                  // Privacy Policy consent
                  CheckboxListTile(
                    value: _acceptedPrivacy,
                    onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFFD4AF37),
                    title: Wrap(
                      children: [
                        Text(
                          'I have read and agree to the ',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.grey[300],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse('https://onlyblv.com/privacy.html'),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFFD4AF37),
                              decoration: TextDecoration.underline,
                            ),
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
                    activeColor: const Color(0xFFD4AF37),
                    title: Wrap(
                      children: [
                        Text(
                          'I have read and agree to the ',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.grey[300],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse('https://onlyblv.com/terms.html'),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: const Text(
                            'Terms of Service',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFFD4AF37),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (!_acceptedPrivacy || !_acceptedTerms)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Text(
                        'You must accept both to continue',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.red[400],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Continue button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _completeSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A2A) : const Color(0xFF212121),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[800]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFD4AF37).withOpacity(0.2)
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[400],
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFD4AF37),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
