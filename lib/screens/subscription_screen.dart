// lib/screens/subscription_screen.dart
//
// Subscription management screen for T[root]H
// Shows current subscription status and upgrade options
// ─────────────────────────────────────────────────────────────

import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../services/api_service.dart';
import 'mentor_gift_seats_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final ApiService _apiService = ApiService();
  Offerings? _offerings;
  bool _isLoading = true;
  String? _error;
  bool _isPurchasing = false;
  String? _userRole; // 'mentor' or 'apprentice'
  bool _isPremiumFromApi = false; // Additional check from API

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  String _debugStatus = 'Loading...';
  String _detailedDebug = '';
  
  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _debugStatus = 'Starting...';
      _detailedDebug = '';
    });

    final debugLog = StringBuffer();
    void addDebug(String msg) {
      dev.log('SubscriptionScreen: $msg');
      debugLog.writeln(msg);
      if (mounted) setState(() => _detailedDebug = debugLog.toString());
    }

    try {
      // Get user role from Firestore
      final user = FirebaseAuth.instance.currentUser;
      addDebug('Firebase UID: ${user?.uid ?? "null"}');
      
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        _userRole = doc.data()?['role'] as String?;
        addDebug('User role: $_userRole');
      }
      
      // Check SDK configuration status
      final isConfigured = await Purchases.isConfigured;
      addDebug('SDK configured: $isConfigured');
      
      if (!isConfigured) {
        addDebug('SDK not configured! Initializing...');
        await _subscriptionService.initialize(user?.uid ?? 'anonymous');
        final nowConfigured = await Purchases.isConfigured;
        addDebug('After init, SDK configured: $nowConfigured');
      }
      
      // Direct call to Purchases.getOfferings() for diagnostics
      addDebug('Calling Purchases.getOfferings() directly...');
      try {
        final directOfferings = await Purchases.getOfferings();
        addDebug('Direct call result:');
        addDebug('  - current: ${directOfferings.current?.identifier ?? "NULL"}');
        addDebug('  - all.keys: ${directOfferings.all.keys.toList()}');
        addDebug('  - all.length: ${directOfferings.all.length}');
        
        if (directOfferings.current != null) {
          addDebug('  - current.packages: ${directOfferings.current!.availablePackages.length}');
          for (final pkg in directOfferings.current!.availablePackages) {
            addDebug('    * ${pkg.identifier}: ${pkg.storeProduct.identifier} @ ${pkg.storeProduct.priceString}');
          }
        }
        
        // Also check each offering in all
        for (final entry in directOfferings.all.entries) {
          addDebug('  Offering "${entry.key}": ${entry.value.availablePackages.length} packages');
        }
        
        _offerings = directOfferings;
      } catch (e, stack) {
        addDebug('ERROR fetching offerings: $e');
        addDebug('Stack: ${stack.toString().split('\n').take(3).join('\n')}');
      }
      
      // Try to get customer info
      addDebug('Getting customer info...');
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        addDebug('Customer ID: ${customerInfo.originalAppUserId}');
        addDebug('Entitlements: ${customerInfo.entitlements.all.keys.toList()}');
        addDebug('Active: ${customerInfo.entitlements.active.keys.toList()}');
      } catch (e) {
        addDebug('Customer info error: $e');
      }
      
      await _subscriptionService.refreshStatus();
      
      // Log final state
      final pkgCount = _offerings?.current?.availablePackages.length ?? 
                       _offerings?.all['default']?.availablePackages.length ?? 0;
      final allKeys = _offerings?.all.keys.toList() ?? [];
      setState(() => _debugStatus = 'current=${_offerings?.current != null}, pkgs=$pkgCount, keys=$allKeys');
      
      // Also check premium status from API (more reliable after purchase)
      _isPremiumFromApi = await _apiService.isPremiumUser();
    } catch (e, stack) {
      _error = 'Failed to load subscription options: $e';
      addDebug('FATAL ERROR: $e');
      addDebug('Stack: ${stack.toString().split('\n').take(5).join('\n')}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isPurchasing = true);

    try {
      final success = await _subscriptionService.purchasePackage(package);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Welcome to Premium!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    try {
      final success = await _subscriptionService.restorePurchases();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No previous purchases found.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _openUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Subscription',
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
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
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
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: _loadOfferings,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final status = _subscriptionService.status;
    
    // Combined premium check - either subscription service OR API says premium
    final isPremium = status.isPremium || _isPremiumFromApi;
    
    // Check if user is on a monthly plan (could upgrade to annual)
    final isMonthlySubscriber = isPremium && _isMonthlySubscription();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current status card
          _buildCurrentStatusCard(status),
          const SizedBox(height: 24),

          // If already premium, show status details
          if (isPremium) ...[
            _buildPremiumDetailsCard(status),
            // Show gift seats card for premium mentors
            if (_userRole == 'mentor') ...[
              const SizedBox(height: 16),
              _buildGiftSeatsCard(),
            ],
            // Show upgrade to annual option for monthly subscribers
            if (isMonthlySubscriber) ...[
              const SizedBox(height: 24),
              _buildUpgradeToAnnualSection(),
            ],
          ] else ...[
            // Show upgrade options
            _buildUpgradeHeader(),
            const SizedBox(height: 16),
            _buildFeaturesList(),
            const SizedBox(height: 24),
            _buildPricingOptions(),
          ],

          const SizedBox(height: 24),
          // Restore purchases button
          TextButton(
            onPressed: _restorePurchases,
            child: const Text(
              'Restore Purchases',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'Poppins',
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          
          // Legal links
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openUrl('https://onlyblv.com/terms.html#7-subscription-terms'),
                child: Text(
                  'Terms of Service',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(
                '  •  ',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              GestureDetector(
                onTap: () => _openUrl('https://onlyblv.com/privacy.html'),
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Payment will be charged to your Apple/Google account.\nSubscription automatically renews unless cancelled.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'Poppins',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard(SubscriptionStatus status) {
    // Use combined premium check
    final isPremium = status.isPremium || _isPremiumFromApi;
    
    // Determine display name - if API says premium but status doesn't, show appropriate tier
    String displayName = status.tierDisplayName;
    if (_isPremiumFromApi && !status.isPremium) {
      displayName = _userRole == 'mentor' ? 'Mentor Premium' : 'Apprentice Premium';
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPremium
            ? const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPremium ? null : Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? Colors.amber : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isPremium ? Icons.star : Icons.account_circle,
            size: 48,
            color: isPremium ? Colors.white : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: TextStyle(
              color: isPremium ? Colors.white : Colors.grey[400],
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          if (isPremium && status.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Expires: ${_formatDate(status.expiresAt!)}',
              style: TextStyle(
                color: status.isExpiringSoon ? Colors.red[200] : Colors.white70,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumDetailsCard(SubscriptionStatus status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Premium Benefits',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 16),
          _buildBenefitRow(Icons.check_circle, 'All assessment templates'),
          _buildBenefitRow(Icons.check_circle, 'Detailed AI insights'),
          _buildBenefitRow(Icons.check_circle, 'Full progress reports'),
          _buildBenefitRow(Icons.check_circle, 'Priority support'),

          if (status.tier == SubscriptionTier.mentorPremium &&
              status.availableSeats != null) ...[
            const Divider(color: Colors.grey, height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gift Seats',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  '${status.usedSeats ?? 0} / ${status.availableSeats} used',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],

          if (status.tier == SubscriptionTier.mentorGifted &&
              status.giftedByMentorName != null) ...[
            const Divider(color: Colors.grey, height: 32),
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Gifted by ${status.giftedByMentorName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGiftSeatsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MentorGiftSeatsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.card_giftcard,
                color: Color(0xFFD4AF37),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gift Premium to Apprentices',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Purchase gift seats to give your apprentices premium access',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFD4AF37),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Check if user has a monthly subscription (could upgrade to annual)
  bool _isMonthlySubscription() {
    // Check RevenueCat for active subscription type
    // For now, we'll check if offerings have an annual plan available
    // that's different from current subscription
    // This is a simplified check - in production you'd check the actual subscription period
    if (_offerings?.current != null) {
      // If user has premium and there's an annual plan, assume they might be on monthly
      // A more accurate implementation would check the actual subscription period from RevenueCat
      final hasAnnualPlan = _offerings!.current!.availablePackages.any((pkg) {
        final productId = pkg.storeProduct.identifier.toLowerCase();
        return productId.contains('annual') && 
               ((_userRole == 'mentor' && productId.contains('mentor')) ||
                (_userRole == 'apprentice' && productId.contains('apprentice')));
      });
      return hasAnnualPlan;
    }
    return false;
  }

  Widget _buildUpgradeToAnnualSection() {
    final isMentor = _userRole == 'mentor';
    
    // Find the annual package for the user's role
    Package? annualPackage;
    if (_offerings?.current != null) {
      for (final pkg in _offerings!.current!.availablePackages) {
        final productId = pkg.storeProduct.identifier.toLowerCase();
        final isAnnual = productId.contains('annual');
        final matchesRole = isMentor 
            ? productId.contains('mentor') && !productId.contains('gift')
            : productId.contains('apprentice');
        if (isAnnual && matchesRole) {
          annualPackage = pkg;
          break;
        }
      }
    }

    if (annualPackage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Save with Annual',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SAVE 17%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Switch to annual billing and save! Your current subscription will be prorated.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isPurchasing ? null : () => _purchasePackage(annualPackage!),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isPurchasing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Upgrade to Annual - ${annualPackage.storeProduct.priceString}/year',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeHeader() {
    final isMentor = _userRole == 'mentor';
    return Column(
      children: [
        const Text(
          'Upgrade to Premium',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isMentor
              ? 'Unlock powerful tools to guide your apprentices'
              : 'Access all assessments and deepen your spiritual journey',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesList() {
    final isMentor = _userRole == 'mentor';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMentor) ...[
            // Mentor-specific benefits
            _buildFeatureRowExpanded(
              Icons.psychology,
              'Enhanced AI Reports',
              'Get comprehensive AI-powered insights for each apprentice. '
              'Free reports show basic category scores, while Premium unlocks '
              'detailed question-by-question feedback, personalized recommendations, '
              'and actionable growth plans tailored to each apprentice.',
            ),
            const Divider(color: Colors.grey, height: 24),
            _buildFeatureRowExpanded(
              Icons.people,
              'Unlimited Apprentices',
              'Mentor as many apprentices as you want. Free mentors are limited '
              'to 1 apprentice, but Premium lets you guide your entire youth group, '
              'Bible study, or ministry team.',
            ),
            const Divider(color: Colors.grey, height: 24),
            _buildFeatureRowExpanded(
              Icons.edit_document,
              'Custom Assessment Templates',
              'Create your own assessment templates tailored to your ministry. '
              'Design questions that address the specific spiritual needs of your '
              'apprentices and track their growth in areas you care about.',
            ),
            const Divider(color: Colors.grey, height: 24),
            _buildFeatureRowExpanded(
              Icons.support_agent,
              'Priority Support',
              'Get faster responses when you need help. Our team is here to '
              'support your mentorship journey.',
            ),
          ] else ...[
            // Apprentice-specific benefits
            _buildFeatureRowExpanded(
              Icons.assignment,
              'Access All Assessments',
              'Go beyond the Master T[root]H Assessment and Spiritual Gifts Assessment. '
              'Premium unlocks access to all assessment templates your mentor assigns, '
              'plus any future assessments added to the platform.',
            ),
            const Divider(color: Colors.grey, height: 24),
            _buildFeatureRowExpanded(
              Icons.insights,
              'Detailed AI Insights',
              'Receive comprehensive feedback on your assessments with specific '
              'recommendations for spiritual growth in each area of your life.',
            ),
            const Divider(color: Colors.grey, height: 24),
            _buildFeatureRowExpanded(
              Icons.support_agent,
              'Priority Support',
              'Get faster responses when you need help on your spiritual journey.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
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

  Widget _buildFeatureRowExpanded(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Text(
              description,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontFamily: 'Poppins',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingOptions() {
    final isMentor = _userRole == 'mentor';
    
    // If RevenueCat offerings are available, show them filtered by role
    // Try current first, then fall back to 'default' offering
    final activeOffering = _offerings?.current ?? _offerings?.all['default'];
    
    if (activeOffering != null) {
      // Filter packages based on user role
      final filteredPackages = activeOffering.availablePackages.where((package) {
        final productId = package.storeProduct.identifier.toLowerCase();
        
        // Don't show gift seat packages in regular subscription screen
        if (productId.contains('gift_seat')) {
          return false;
        }
        
        // Show only packages matching the user's role
        if (isMentor) {
          return productId.contains('mentor');
        } else {
          return productId.contains('apprentice');
        }
      }).toList();
      
      // Sort packages: annual first (best value), then monthly
      filteredPackages.sort((a, b) {
        final aIsAnnual = a.packageType == PackageType.annual || 
                          a.storeProduct.identifier.toLowerCase().contains('annual');
        final bIsAnnual = b.packageType == PackageType.annual || 
                          b.storeProduct.identifier.toLowerCase().contains('annual');
        if (aIsAnnual && !bIsAnnual) return -1;
        if (!aIsAnnual && bIsAnnual) return 1;
        return 0;
      });
      
      if (filteredPackages.isEmpty) {
        return Center(
          child: Text(
            'No subscription options available for your account type.',
            style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'),
            textAlign: TextAlign.center,
          ),
        );
      }
      
      return Column(
        children: filteredPackages.map((package) {
          return _buildPackageCard(package);
        }).toList(),
      );
    }

    // Fallback: show placeholder pricing based on role
    // This means RevenueCat offerings failed to load (API key issue or network error)
    dev.log('SubscriptionScreen: Showing fallback UI - offerings not loaded');
    final annualPrice = isMentor ? '\$49.99/year' : '\$49.99/year';
    final monthlyPrice = isMentor ? '\$4.99/month' : '\$4.99/month';
    final roleLabel = isMentor ? 'Mentor' : 'Apprentice';
    
    // Build debug info string
    String debugInfo = _debugStatus;
    
    return Column(
      children: [
        // TEMPORARY DEBUG INFO - REMOVE BEFORE RELEASE
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚠️ RevenueCat Debug',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Status: $debugInfo',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              if (_detailedDebug.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      _detailedDebug,
                      style: const TextStyle(color: Colors.white60, fontSize: 9, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  setState(() {
                    _debugStatus = 'Retrying...';
                    _detailedDebug = '';
                  });
                  await _loadOfferings();
                },
                child: const Text('Retry', style: TextStyle(color: Colors.amber)),
              ),
            ],
          ),
        ),
        _buildPricingCard(
          title: '$roleLabel Premium Annual',
          price: annualPrice,
          description: 'Save with annual billing - Best value!',
          isPopular: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to connect to store. Please try again later.'),
                backgroundColor: Colors.orange,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildPricingCard(
          title: '$roleLabel Premium Monthly',
          price: monthlyPrice,
          description: 'Billed monthly, cancel anytime',
          isPopular: false,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to connect to store. Please try again later.'),
                backgroundColor: Colors.orange,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPackageCard(Package package) {
    final product = package.storeProduct;
    final productId = product.identifier.toLowerCase();
    
    // Determine if annual based on package type OR product identifier
    final isAnnual = package.packageType == PackageType.annual || 
                     productId.contains('annual');
    
    // Build a cleaner title that shows the billing period
    String displayTitle;
    if (productId.contains('mentor')) {
      displayTitle = isAnnual ? 'Mentor Premium Annual' : 'Mentor Premium Monthly';
    } else if (productId.contains('apprentice')) {
      displayTitle = isAnnual ? 'Apprentice Premium Annual' : 'Apprentice Premium Monthly';
    } else {
      // Fallback to product title but append billing period if not present
      displayTitle = product.title;
      if (!displayTitle.toLowerCase().contains('annual') && 
          !displayTitle.toLowerCase().contains('monthly')) {
        displayTitle += isAnnual ? ' (Annual)' : ' (Monthly)';
      }
    }

    return GestureDetector(
      onTap: _isPurchasing ? null : () => _purchasePackage(package),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAnnual ? Colors.amber : Colors.grey[700]!,
            width: isAnnual ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      if (isAnnual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'BEST VALUE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              product.priceString,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String description,
    required bool isPopular,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPopular ? Colors.amber : Colors.grey[700]!,
            width: isPopular ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'BEST VALUE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
