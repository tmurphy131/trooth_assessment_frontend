import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

class ApprenticeInviteScreen extends StatefulWidget {
  final User? user;
  final String? prefillName;
  final String? prefillEmail;
  
  const ApprenticeInviteScreen({super.key, this.user, this.prefillName, this.prefillEmail});

  @override
  State<ApprenticeInviteScreen> createState() => _ApprenticeInviteScreenState();
}

class _ApprenticeInviteScreenState extends State<ApprenticeInviteScreen> {
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
      
      await Future.wait([
        _loadPendingInvites(),
        _primeInactiveCount(),
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

      final invites = await _apiService.getPendingInvites();
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

  // Prime inactive apprentice count without showing dialog
  Future<void> _primeInactiveCount() async {
    try {
      final list = await _apiService.listInactiveApprentices();
      if (mounted) setState(() { _inactiveApprentices = list.cast<Map<String,dynamic>>(); });
    } catch (_) {
      // silent; badge just won't show
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Apprentice Invites',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _showInactiveApprenticesDialog,
            tooltip: 'View Inactive Apprentices',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.archive, color: Colors.amber),
                if (_inactiveApprentices.isNotEmpty) Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: Text(
                      _inactiveApprentices.length > 99 ? '99+' : _inactiveApprentices.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showInviteDialog,
            icon: const Icon(Icons.add, color: Colors.amber),
            tooltip: 'Send New Invite',
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
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteDialog,
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.mail_outline),
        label: const Text(
          'Send Invite',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
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
                  'No pending invites',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap Send Invite to invite an apprentice',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _showInviteDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Send First Invite',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
    final apprenticeName = invite['apprentice_name'] ?? 'Unknown';
    final apprenticeEmail = invite['apprentice_email'] ?? '';
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apprenticeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        apprenticeEmail,
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
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
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
                    onPressed: () => _copyInviteLink(invite['token'] ?? ''),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text(
                      'Copy Link',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _revokeInvite(invite),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text(
                      'Revoke',
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

  void _showInviteDialog() {
  final nameController = TextEditingController(text: widget.prefillName ?? '');
  final emailController = TextEditingController(text: widget.prefillEmail ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Send Apprentice Invite',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                labelText: 'Apprentice Name',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () => _sendInvite(nameController.text, emailController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text(
              'Send Invite',
              style: TextStyle(color: Colors.black, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvite(String name, String email) async {
    if (name.trim().isEmpty || email.trim().isEmpty) {
      _showMessage('Both name and email are required', isError: true);
      return;
    }

    Navigator.pop(context); // Close dialog
    
    try {
      final payload = {
        'apprentice_name': name.trim(),
        'apprentice_email': email.trim(),
      };

      await _apiService.sendInvite(payload);
      await _loadPendingInvites();
      _showMessage('Invitation sent successfully!');
      
    } catch (e) {
      _showMessage('Failed to send invitation: $e', isError: true);
    }
  }

  Future<void> _revokeInvite(Map<String, dynamic> invite) async {
    final confirmed = await _showConfirmDialog(
      'Revoke Invitation?',
      'Are you sure you want to revoke the invitation for ${invite['apprentice_name']}?',
    );
    
    if (!confirmed) return;

    try {
      await _apiService.revokeInvite(invite['id'] as String);
      await _loadPendingInvites();
      _showMessage('Invitation revoked successfully!');
    } catch (e) {
      _showMessage('Failed to revoke invitation: $e', isError: true);
    }
  }

  void _copyInviteLink(String token) {
    // For now, just show the token. In a real app, you'd copy the full invite URL
    _showMessage('Invite link: https://yourapp.com/accept-invite?token=$token');
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

  // Inactive apprentices relocation (moved from mentor dashboard)
  List<Map<String, dynamic>> _inactiveApprentices = [];
  bool _loadingInactive = false;

  Future<void> _loadInactiveApprentices() async {
    try {
      setState(() { _loadingInactive = true; });
      final list = await _apiService.listInactiveApprentices();
      setState(() {
        _inactiveApprentices = list.cast<Map<String, dynamic>>();
        _loadingInactive = false;
      });
    } catch (e) {
      setState(() { _loadingInactive = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load inactive: $e')));
      }
    }
  }

  void _showInactiveApprenticesDialog() async {
    await _loadInactiveApprentices();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
            title: Row(
              children: const [
                Icon(Icons.archive, color: Colors.amber),
                SizedBox(width: 8),
                Text('Inactive Apprentices', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: _loadingInactive
                  ? const SizedBox(height:120, child: Center(child: CircularProgressIndicator(color: Colors.amber)))
                  : _inactiveApprentices.isEmpty
                      ? Text('No inactive apprentices', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _inactiveApprentices.length,
                          itemBuilder: (context, index) {
                            final a = _inactiveApprentices[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_off, color: Colors.redAccent),
                              title: Text(a['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                              subtitle: Text(a['email'] ?? '', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')),
                              trailing: TextButton.icon(
                                onPressed: () async {
                                  Navigator.of(ctx).pop();
                                  await _confirmReinstateApprentice(a);
                                },
                                icon: const Icon(Icons.replay, color: Colors.amber, size: 18),
                                label: const Text('Reinstate', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close', style: TextStyle(color: Colors.amber)),
              ),
            ],
        );
      },
    );
  }

  Future<void> _confirmReinstateApprentice(Map<String, dynamic> apprentice) async {
    final apprenticeId = apprentice['id'];
    if (apprenticeId == null) return;

    final controller = TextEditingController();
    bool submitting = false;
    await showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Row(
              children: [
                const Icon(Icons.replay, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text('Reinstate ${apprentice['name'] ?? 'Apprentice'}', style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Optional message to apprentice:', style: TextStyle(color: Colors.grey[300], fontFamily: 'Poppins', fontSize: 13)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  decoration: InputDecoration(
                    hintText: 'Reason or welcome back note (optional)',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[700]!)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.email, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text('An email will be sent informing them of reinstatement.', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'Poppins')))
                  ],
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: submitting ? null : () async {
                  setLocalState(() => submitting = true);
                  try {
                    await _apiService.reinstateApprenticeship(apprenticeId, reason: controller.text.trim().isEmpty ? null : controller.text.trim());
                    if (!mounted) return; 
                    setLocalState(() { submitting = false; });
                    Navigator.of(ctx).pop();
                    // Update lists
                    setState(() { _inactiveApprentices.removeWhere((a) => a['id'] == apprenticeId); });
                    await _loadInactiveApprentices();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apprentice reinstated')));
                    }
                  } catch (e) {
                    setLocalState(() => submitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                },
                child: submitting
                    ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                    : const Text('Reinstate'),
              )
            ],
          ),
        );
      }
    );
  }
}
