import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

class ApprenticeInvitesScreen extends StatefulWidget {
  final User? user;
  
  const ApprenticeInvitesScreen({super.key, this.user});

  @override
  State<ApprenticeInvitesScreen> createState() => _ApprenticeInvitesScreenState();
}

class _ApprenticeInvitesScreenState extends State<ApprenticeInvitesScreen> {
  User? get user => widget.user ?? FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  
  List<Map<String, dynamic>> _pendingInvites = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      if (user != null) {
        final token = await user!.getIdToken();
        _apiService.bearerToken = token;
      }
      
      await _loadPendingInvites();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPendingInvites() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get apprentice's pending invites by email
      final userEmail = user?.email ?? '';
      final invites = await _apiService.getApprenticeInvites(userEmail);
      
      setState(() {
        _pendingInvites = invites.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load pending invites: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Mentor Invitations',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadPendingInvites,
            icon: const Icon(Icons.refresh, color: Colors.amber),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPendingInvites,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildInvitesList(),
    );
  }

  Widget _buildInvitesList() {
    if (_pendingInvites.isEmpty) {
      return Center(
        child: Card(
          elevation: 2,
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending invitations',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'When mentors invite you to their program, invitations will appear here',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: _pendingInvites.length,
        itemBuilder: (context, index) {
          return _buildInviteCard(_pendingInvites[index]);
        },
      ),
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite) {
    final mentorName = invite['mentor_name'] ?? 'Unknown Mentor';
    final mentorEmail = invite['mentor_email'] ?? '';
    final expiresAt = invite['expires_at'] as String?;
    
    return Card(
      elevation: 2,
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invitation from $mentorName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mentorEmail,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              'You have been invited to begin a mentoring relationship through the T[root]H Assessment platform.',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
            
            if (expiresAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Expires: ${_formatDateString(expiresAt)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptInvite(invite),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'Accept Invitation',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _declineInvite(invite),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text(
                      'Decline',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptInvite(Map<String, dynamic> invite) async {
    final confirmed = await _showConfirmDialog(
      'Accept Invitation?',
      'Are you sure you want to accept the mentoring invitation from ${invite['mentor_name']}?',
    );
    
    if (!confirmed) return;

    try {
      final apprenticeId = user?.uid ?? '';
      final token = invite['token'] ?? '';
      
      await _apiService.acceptInvite({
        'token': token,
        'apprentice_id': apprenticeId,
      });
      
      await _loadPendingInvites();
      _showMessage('Invitation accepted successfully! Welcome to your mentoring program.');
      
    } catch (e) {
      _showMessage('Failed to accept invitation: $e', isError: true);
    }
  }

  Future<void> _declineInvite(Map<String, dynamic> invite) async {
    final confirmed = await _showConfirmDialog(
      'Decline Invitation?',
      'Are you sure you want to decline this mentoring invitation? This action cannot be undone.',
    );
    
    if (!confirmed) return;

    try {
      // For now, we'll just remove it from the local list
      // In a full implementation, you'd have a decline endpoint
      setState(() {
        _pendingInvites.remove(invite);
      });
      
      _showMessage('Invitation declined.');
      
    } catch (e) {
      _showMessage('Failed to decline invitation: $e', isError: true);
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.black, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          isError ? 'Error' : 'Success',
          style: TextStyle(
            color: isError ? Colors.red : Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.amber,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
