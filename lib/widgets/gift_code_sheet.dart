import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import '../models/gift_code_redemption.dart';
import '../services/api_service.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/gift_codes.dart';

/// Opens the "Have a gift code from your mentor?" sheet (spec 005 US2).
/// Returns true when a code was redeemed and Premium status refreshed.
Future<bool> showGiftCodeSheet(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showModalBottomSheet<GiftCodeRedemption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: GiftCodeForm(onRedeemed: (r) => Navigator.of(sheetContext).pop(r)),
        ),
      ),
    ),
  );
  if (result == null) return false;

  // Unlock Premium features without a restart.
  await SubscriptionService().refreshStatus();
  final mentor = result.mentorName?.trim() ?? '';
  messenger.showSnackBar(SnackBar(
    content: Text(mentor.isNotEmpty ? 'Premium access activated! Gifted by $mentor.' : 'Premium access activated!'),
    backgroundColor: Colors.green,
  ));
  return true;
}

/// Gift-code entry: normalizes the code, redeems it, and shows inline errors.
class GiftCodeForm extends StatefulWidget {
  const GiftCodeForm({super.key, required this.onRedeemed, this.redeem, this.reportError});

  final void Function(GiftCodeRedemption redemption) onRedeemed;

  /// Defaults to [ApiService.redeemGiftCode]; injectable for tests.
  final Future<GiftCodeRedemption> Function(String code)? redeem;

  /// Defaults to Crashlytics; injectable for tests. Never receives the code.
  final void Function(Object error, StackTrace stack)? reportError;

  @override
  State<GiftCodeForm> createState() => _GiftCodeFormState();
}

class _GiftCodeFormState extends State<GiftCodeForm> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final code = normalizeGiftCode(_controller.text);
    if (code == null) {
      setState(() => _error = 'That code looks incomplete.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final redeem = widget.redeem ?? ApiService().redeemGiftCode;
    try {
      final result = await redeem(code);
      if (!mounted) return;
      setState(() => _submitting = false);
      if (result.success) {
        widget.onRedeemed(result);
      } else {
        // Shown as-is; what to do is decided by `success`, not the text (Principle XII).
        setState(() => _error = result.message);
      }
    } catch (e, st) {
      if (!mounted) return;
      final String message;
      if (e is ApiException && e.statusCode == 403) {
        message = 'Gift codes are for apprentice accounts.';
      } else {
        message = friendlyError(e);
        // Premium-granting flow: report unexpected failures (Principle IV).
        (widget.reportError ??
            (err, stack) => FirebaseCrashlytics.instance.recordError(err, stack, reason: 'Gift code redeem failed'))(e, st);
      }
      setState(() {
        _submitting = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Have a gift code from your mentor?',
          style: TextStyle(color: kPrimaryGold, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter it to unlock Premium.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('giftCodeField'),
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 24,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace', letterSpacing: 1.5),
          decoration: InputDecoration(
            hintText: 'TROOTH-XXXX-XXXX',
            hintStyle: TextStyle(color: Colors.grey[500]),
            counterText: '',
            filled: true,
            fillColor: Colors.grey[850],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: kPrimaryGold),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontFamily: 'Poppins')),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            key: const Key('giftCodeRedeem'),
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGold, foregroundColor: Colors.black),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('Redeem', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
