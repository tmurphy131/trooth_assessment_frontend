import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import 'agreement_preview_screen.dart';

class ApprenticeInvitesScreen extends StatefulWidget {
  final User? user;
  
  const ApprenticeInvitesScreen({super.key, this.user});

  @override
  State<ApprenticeInvitesScreen> createState() => _ApprenticeInvitesScreenState();
}

class _ApprenticeInvitesScreenState extends State<ApprenticeInvitesScreen> with SingleTickerProviderStateMixin {
  User? get user => widget.user ?? FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _pendingInvites = [];
  List<Map<String, dynamic>> _agreements = [];
  bool _isLoading = true;
  bool _loadingAgreements = true;
  String? _error;
  String? _agreementError;
  
  // Signing state
  bool _signing = false;
  final _signatureNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signatureNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      if (user != null) {
        final token = await user!.getIdToken();
        _apiService.bearerToken = token;
      }
      
      await Future.wait([
        _loadPendingInvites(),
        _loadAgreements(),
      ]);
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

  Future<void> _loadAgreements() async {
    try {
      setState(() {
        _loadingAgreements = true;
        _agreementError = null;
      });

      final agreements = await _apiService.listMyAgreements();
      
      setState(() {
        _agreements = agreements.cast<Map<String, dynamic>>();
        _loadingAgreements = false;
      });
    } catch (e) {
      setState(() {
        _agreementError = 'Failed to load agreements: $e';
        _loadingAgreements = false;
      });
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadPendingInvites(),
      _loadAgreements(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Count pending agreements that need action
    final pendingAgreementCount = _agreements.where((a) => a['status'] == 'awaiting_apprentice').length;
    
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
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.amber),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Invitations', icon: Icon(Icons.person_add, size: 20)),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description, size: 20),
                  const SizedBox(width: 6),
                  const Text('Agreements'),
                  if (pendingAgreementCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        pendingAgreementCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Invitations
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : _error != null
                  ? _buildErrorView(_error!, _loadPendingInvites)
                  : _buildInvitesList(),
          // Tab 2: Agreements
          _loadingAgreements
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : _agreementError != null
                  ? _buildErrorView(_agreementError!, _loadAgreements)
                  : _buildAgreementsList(),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
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
            error,
            style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: retry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
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
              'You have been invited to begin a mentoring relationship through the T[root]H Discipleship platform.',
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

  // ==================== AGREEMENTS TAB ====================

  Widget _buildAgreementsList() {
    if (_agreements.isEmpty) {
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
                Icon(Icons.description_outlined, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'No agreements yet',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'When your mentor sends a mentorship agreement, it will appear here for you to review and sign',
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

    // Sort: awaiting_apprentice first, then by date
    final sortedAgreements = List<Map<String, dynamic>>.from(_agreements);
    sortedAgreements.sort((a, b) {
      // Priority: awaiting_apprentice first
      if (a['status'] == 'awaiting_apprentice' && b['status'] != 'awaiting_apprentice') return -1;
      if (b['status'] == 'awaiting_apprentice' && a['status'] != 'awaiting_apprentice') return 1;
      // Then by date (newest first)
      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: sortedAgreements.length,
        itemBuilder: (context, index) {
          return _buildAgreementCard(sortedAgreements[index]);
        },
      ),
    );
  }

  Widget _buildAgreementCard(Map<String, dynamic> agreement) {
    final status = agreement['status'] ?? 'unknown';
    final mentorName = agreement['mentor_name'] ?? 'Your Mentor';
    final createdAt = agreement['created_at'] as String?;
    final needsAction = status == 'awaiting_apprentice';
    
    return Card(
      elevation: 2,
      color: needsAction ? Colors.orange.withOpacity(0.1) : Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: needsAction 
            ? const BorderSide(color: Colors.orange, width: 1.5)
            : BorderSide.none,
      ),
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
                    color: _statusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.description, color: _statusColor(status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mentorship Agreement',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From $mentorName',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            if (needsAction)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your signature is required to complete this agreement',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                _getStatusDescription(status),
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sent: ${_formatDateString(createdAt)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewAgreement(agreement),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Agreement', style: TextStyle(fontFamily: 'Poppins')),
                  ),
                ),
                if (needsAction) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showSignDialog(agreement),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Sign Now', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft': return Colors.grey;
      case 'awaiting_apprentice': return Colors.orange;
      case 'awaiting_parent': return Colors.purple;
      case 'fully_signed': return Colors.green;
      case 'revoked': return Colors.red;
      case 'expired': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'draft': return 'Draft';
      case 'awaiting_apprentice': return 'Action Required';
      case 'awaiting_parent': return 'Awaiting Parent';
      case 'fully_signed': return 'Signed';
      case 'revoked': return 'Revoked';
      case 'expired': return 'Expired';
      default: return status;
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'draft': return 'This agreement is still being prepared by your mentor.';
      case 'awaiting_parent': return 'You have signed this agreement. Waiting for parent signature.';
      case 'fully_signed': return 'This agreement has been fully signed by all parties.';
      case 'revoked': return 'This agreement has been revoked by your mentor.';
      case 'expired': return 'This agreement has expired.';
      default: return 'Mentorship agreement from your mentor.';
    }
  }

  void _viewAgreement(Map<String, dynamic> agreement) {
    final markdown = agreement['content_rendered'] ?? '# Agreement\n\nNo content available.';
    final status = agreement['status'] ?? 'unknown';
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AgreementPreviewScreen(
          markdown: markdown,
          apprenticeEmail: agreement['apprentice_email'],
          parentEmail: agreement['parent_email'],
          status: status,
        ),
      ),
    );
  }

  Future<void> _showSignDialog(Map<String, dynamic> agreement) async {
    _signatureNameCtrl.clear();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Sign Mentorship Agreement',
            style: TextStyle(
              color: Colors.amber,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By typing your name below, you agree to the terms of this mentorship agreement with ${agreement['mentor_name'] ?? 'your mentor'}.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Poppins',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _signatureNameCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  decoration: InputDecoration(
                    labelText: 'Type your full name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'e.g., John Smith',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.amber),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.amber, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.person, color: Colors.amber),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                Text(
                  'This serves as your electronic signature.',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
            ),
            ElevatedButton(
              onPressed: _signatureNameCtrl.text.trim().length >= 2
                  ? () => Navigator.pop(context, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                disabledBackgroundColor: Colors.grey[700],
              ),
              child: const Text('Sign Agreement', style: TextStyle(color: Colors.black, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    
    if (result == true) {
      await _signAgreement(agreement);
    }
  }

  Future<void> _signAgreement(Map<String, dynamic> agreement) async {
    final agreementId = agreement['id'];
    final typedName = _signatureNameCtrl.text.trim();
    
    if (agreementId == null || typedName.isEmpty) return;
    
    setState(() { _signing = true; });
    
    try {
      await _apiService.apprenticeSignAgreement(
        agreementId: agreementId,
        typedName: typedName,
      );
      
      await _loadAgreements();
      
      if (mounted) {
        _showMessage('Agreement signed successfully! ${agreement['parent_required'] == true ? 'Waiting for parent signature.' : 'Your mentorship is now official!'}');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to sign agreement: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() { _signing = false; });
      }
    }
  }

  // ==================== INVITATIONS TAB ====================

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
