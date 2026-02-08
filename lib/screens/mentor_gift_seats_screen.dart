// lib/screens/mentor_gift_seats_screen.dart
//
// Screen for premium mentors to manage gift seats for apprentices
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/subscription_service.dart';
import '../services/api_service.dart';
import 'subscription_screen.dart';

class MentorGiftSeatsScreen extends StatefulWidget {
  const MentorGiftSeatsScreen({super.key});

  @override
  State<MentorGiftSeatsScreen> createState() => _MentorGiftSeatsScreenState();
}

class _MentorGiftSeatsScreenState extends State<MentorGiftSeatsScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final ApiService _apiService = ApiService();
  List<MentorGiftSeat> _seats = [];
  List<dynamic> _apprentices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _subscriptionService.refreshStatus();
      final results = await Future.wait([
        _subscriptionService.getGiftSeats(),
        _apiService.listApprentices(),
      ]);
      if (mounted) {
        setState(() {
          _seats = results[0] as List<MentorGiftSeat>;
          _apprentices = results[1] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchaseGiftSeat() async {
    // Show create seat dialog to get apprentice info first
    final result = await _showCreateSeatDialog();
    if (result == null || !mounted) return;
    
    setState(() => _isLoading = true);
    
    // Determine display name for success message
    final displayName = result['name']?.isNotEmpty == true 
        ? result['name']! 
        : result['email'] ?? 'apprentice';
    
    try {
      // Purchase through IAP and create seat with apprentice info
      final seat = await _subscriptionService.purchaseGiftSeat(
        apprenticeEmail: result['email'],
        apprenticeName: result['name']?.isNotEmpty == true ? result['name'] : null,
        apprenticeId: result['apprentice_id'],  // Direct assignment by ID if selected from dropdown
      );
      
      if (seat != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gift seat purchased for $displayName!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = _subscriptionService.error;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
        // If error is null, user cancelled - no message needed
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to purchase gift seat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    await _loadData();
  }

  /// Legacy method for creating gift seats (for mentors with bundled seats)
  Future<void> _createGiftSeat() async {
    final status = _subscriptionService.status;
    
    // Check if mentor is premium
    if (!status.isPremium) {
      _showUpgradePrompt();
      return;
    }

    // Check if they have available seats
    final available = (status.availableSeats ?? 0) - (status.usedSeats ?? 0);
    if (available <= 0) {
      _showNoSeatsDialog();
      return;
    }

    // Show create seat dialog
    final result = await _showCreateSeatDialog();
    if (result != null && mounted) {
      setState(() => _isLoading = true);
      
      final seat = await _subscriptionService.createGiftSeat(
        apprenticeEmail: result['email']!,
        apprenticeName: result['name'],
      );
      
      if (seat != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gift seat created for ${result['email']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_subscriptionService.error ?? 'Failed to create gift seat'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      await _loadData();
    }
  }

  Future<void> _revokeSeat(MentorGiftSeat seat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Revoke Gift Seat?',
          style: TextStyle(color: Colors.amber, fontFamily: 'Poppins'),
        ),
        content: Text(
          'This will remove premium access for ${seat.apprenticeName ?? seat.apprenticeEmail}. They will need to purchase their own subscription to continue using premium features.',
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      
      final success = await _subscriptionService.revokeGiftSeat(seat.id);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gift seat revoked'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_subscriptionService.error ?? 'Failed to revoke seat'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      await _loadData();
    }
  }

  /// Assign an unassigned seat to an apprentice
  Future<void> _assignSeat(MentorGiftSeat seat) async {
    // Show dialog to select apprentice
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _GiftSeatDialog(apprentices: _getAvailableApprentices()),
    );
    
    if (result == null || !mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _apiService.assignMentorGiftSeat(
        seatId: seat.id,
        apprenticeId: result['apprentice_id'],
        apprenticeEmail: result['email'],
        apprenticeName: result['name'],
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gift seat assigned to ${result['name'] ?? result['email']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign seat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    await _loadData();
  }

  /// Filter out apprentices who already have an active gift seat from this mentor
  /// or who already have a premium subscription
  List<dynamic> _getAvailableApprentices() {
    // Get IDs of apprentices who already have a gift seat from this mentor
    final giftedIds = _seats
        .where((s) => s.apprenticeId != null && s.isActive)
        .map((s) => s.apprenticeId)
        .toSet();
    
    return _apprentices.where((a) {
      final id = a['id']?.toString();
      // Exclude if already has a gift seat
      if (giftedIds.contains(id)) return false;
      // Exclude if already has premium (from their own subscription or other source)
      final hasPremium = a['has_premium'] == true;
      if (hasPremium) return false;
      return true;
    }).toList();
  }

  Future<Map<String, String>?> _showCreateSeatDialog() async {
    final availableApprentices = _getAvailableApprentices();
    
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _GiftSeatDialog(
        apprentices: availableApprentices,
      ),
    );
  }

  void _showUpgradePrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: const [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Premium Required',
              style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'You need a premium subscription to gift premium access to your apprentices.',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: const Text('Upgrade Now', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNoSeatsDialog() {
    final status = _subscriptionService.status;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'No Seats Available',
          style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You\'ve used all ${status.availableSeats ?? 0} of your gift seats. Revoke an existing seat to gift premium to someone else.',
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _subscriptionService.status;
    // With per-seat IAP, we just count active seats
    final activeSeats = _seats.where((s) => s.isActive).length;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Gift Seats',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: _loadData,
          ),
        ],
      ),
      // Always show FAB - per-seat IAP allows unlimited purchases
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _purchaseGiftSeat,
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.add_card, color: Colors.black),
        label: const Text(
          'Buy Gift Seat',
          style: TextStyle(color: Colors.black, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? _buildErrorState()
              : _buildContent(status, activeSeats),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SubscriptionStatus status, int activeSeats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card about gift seats
          _buildInfoCard(activeSeats),
          const SizedBox(height: 24),

          // Seats list header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Gift Seats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              if (activeSeats > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$activeSeats active',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_seats.isEmpty)
            _buildEmptyState()
          else
            ..._seats.map((seat) => _buildSeatCard(seat)).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoCard(int activeSeats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.card_giftcard, size: 32, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Gift Premium Access',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Purchase gift seats to give your apprentices full premium access. '
            'Each seat is \$4.99/month and can be cancelled anytime.',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
          if (activeSeats > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'You have $activeSeats active seat${activeSeats == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(SubscriptionStatus status, int availableSeats, int usedSeats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: status.isPremium
            ? const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: status.isPremium ? null : Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            status.isPremium ? Icons.star : Icons.star_border,
            size: 40,
            color: status.isPremium ? Colors.white : Colors.grey,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.tierDisplayName,
                  style: TextStyle(
                    color: status.isPremium ? Colors.white : Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (status.isPremium)
                  Text(
                    '${availableSeats - usedSeats} gift seats available',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.amber, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Gift Premium to Your Apprentices',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upgrade to Mentor Premium to gift premium access to your apprentices. They\'ll get full access to all assessments and AI insights.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: const Text(
              'Upgrade to Premium',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.card_giftcard, color: Colors.grey[600], size: 48),
          const SizedBox(height: 16),
          Text(
            'No gift seats yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to gift premium access to an apprentice.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'Poppins',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatCard(MentorGiftSeat seat) {
    final hasApprentice = seat.apprenticeEmail != null;
    final statusColor = seat.isRedeemed 
        ? Colors.green 
        : (hasApprentice ? Colors.orange : Colors.blue);
    final statusText = seat.isRedeemed 
        ? 'Active' 
        : (hasApprentice ? 'Pending' : 'Unassigned');
    final statusIcon = seat.isRedeemed 
        ? Icons.check 
        : (hasApprentice ? Icons.mail_outline : Icons.person_add);
    
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.2),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seat.displayName,
                    style: TextStyle(
                      color: hasApprentice ? Colors.white : Colors.grey[400],
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      fontStyle: hasApprentice ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  if (seat.apprenticeName != null && seat.apprenticeEmail != null)
                    Text(
                      seat.apprenticeEmail!,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  // Show redemption code for unassigned seats
                  if (!hasApprentice && seat.redemptionCode != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _copyRedemptionCode(seat.redemptionCode!),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            seat.redemptionCode!,
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, size: 14, color: Colors.amber),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons based on seat status
            if (!hasApprentice) ...[
              // Unassigned seat: show Assign button
              IconButton(
                icon: const Icon(Icons.person_add, color: Colors.amber),
                tooltip: 'Assign to apprentice',
                onPressed: () => _assignSeat(seat),
              ),
            ],
            // Always show revoke/cancel button  
            IconButton(
              icon: Icon(
                hasApprentice ? Icons.person_remove : Icons.delete_outline, 
                color: Colors.red,
              ),
              tooltip: hasApprentice ? 'Revoke from apprentice' : 'Cancel subscription',
              onPressed: () => _revokeSeat(seat),
            ),
          ],
        ),
      ),
    );
  }
  
  void _copyRedemptionCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redemption code copied!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}


/// Dialog for selecting an apprentice to gift premium to
/// Shows dropdown of existing apprentices with fallback to manual email entry
class _GiftSeatDialog extends StatefulWidget {
  final List<dynamic> apprentices;
  
  const _GiftSeatDialog({required this.apprentices});
  
  @override
  State<_GiftSeatDialog> createState() => _GiftSeatDialogState();
}

class _GiftSeatDialogState extends State<_GiftSeatDialog> {
  String? _selectedApprenticeId;
  bool _showManualEntry = false;
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Gift Premium to Apprentice',
        style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show apprentice dropdown if there are linked apprentices
              if (widget.apprentices.isNotEmpty && !_showManualEntry) ...[
                const Text(
                  'Select an apprentice to gift premium access:',
                  style: TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedApprenticeId,
                      isExpanded: true,
                      dropdownColor: Colors.grey[850],
                      hint: const Text(
                        'Choose apprentice...',
                        style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
                      ),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                      items: widget.apprentices.map<DropdownMenuItem<String>>((a) {
                        final id = a['id']?.toString() ?? '';
                        final name = a['name']?.toString() ?? 'Unnamed';
                        final email = a['email']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
                              ),
                              Text(
                                email,
                                style: TextStyle(color: Colors.grey[500], fontFamily: 'Poppins', fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedApprenticeId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Option to gift to someone not in the list
                GestureDetector(
                  onTap: () => setState(() => _showManualEntry = true),
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1, color: Colors.amber.withOpacity(0.8), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Gift to someone not listed',
                        style: TextStyle(
                          color: Colors.amber.withOpacity(0.8),
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Manual email entry (shown if no apprentices or user chose "not listed")
              if (widget.apprentices.isEmpty || _showManualEntry) ...[
                if (_showManualEntry && widget.apprentices.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => setState(() {
                      _showManualEntry = false;
                      _emailController.clear();
                      _nameController.clear();
                    }),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back, color: Colors.grey, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Back to apprentice list',
                          style: TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  widget.apprentices.isEmpty
                      ? 'Enter the email of the person you want to gift premium access to. They will receive a code to redeem.'
                      : 'Enter their email address. They\'ll receive a redemption code.',
                  style: const TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  decoration: InputDecoration(
                    labelText: 'Name (optional)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: _canSubmit() ? _submit : null,
          child: const Text('Gift Premium', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
  
  bool _canSubmit() {
    if (_showManualEntry || widget.apprentices.isEmpty) {
      return _emailController.text.trim().isNotEmpty;
    }
    return _selectedApprenticeId != null;
  }
  
  void _submit() {
    // If using dropdown selection
    if (!_showManualEntry && widget.apprentices.isNotEmpty && _selectedApprenticeId != null) {
      final selected = widget.apprentices.firstWhere(
        (a) => a['id']?.toString() == _selectedApprenticeId,
        orElse: () => null,
      );
      if (selected != null) {
        Navigator.pop(context, {
          'email': selected['email']?.toString() ?? '',
          'name': selected['name']?.toString() ?? '',
          'apprentice_id': _selectedApprenticeId!,
        });
        return;
      }
    }
    
    // Manual email entry
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
      });
    }
  }
}
