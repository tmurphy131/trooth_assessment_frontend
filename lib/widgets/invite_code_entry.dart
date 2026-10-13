import 'package:flutter/material.dart';

import '../models/invite_redemption.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/invite_codes.dart';

/// "Have an invite code?" card: an apprentice types their mentor's code and joins
/// (backend spec 006). Used on the invitations screen and the apprentice dashboard.
class InviteCodeEntry extends StatefulWidget {
  const InviteCodeEntry({super.key, required this.onRedeemed, this.redeem});

  final void Function(InviteRedemption redemption) onRedeemed;

  /// Defaults to [ApiService.redeemInviteCode]; injectable for tests.
  final Future<InviteRedemption> Function(String code)? redeem;

  @override
  State<InviteCodeEntry> createState() => _InviteCodeEntryState();
}

class _InviteCodeEntryState extends State<InviteCodeEntry> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_submitting && _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final redeem = widget.redeem ?? ApiService().redeemInviteCode;
    try {
      final result = await redeem(_controller.text.trim());
      if (!mounted) return;
      _controller.clear();
      setState(() => _submitting = false);
      widget.onRedeemed(result);
    } catch (e) {
      if (!mounted) return;
      // Keep what they typed so they can fix it.
      setState(() {
        _submitting = false;
        _error = inviteCodeErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: kPrimaryGold.withValues(alpha: 0.5)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Have an invite code?',
              style: TextStyle(color: kPrimaryGold, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the code your mentor shared with you.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('inviteCodeField'),
                    controller: _controller,
                    inputFormatters: [UpperCaseTextFormatter()],
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 32,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'XXXX-XXXX',
                      hintStyle: TextStyle(color: Colors.grey[500], letterSpacing: 2),
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
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    key: const Key('inviteCodeJoin'),
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryGold,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(72, 48),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('Join', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontFamily: 'Poppins')),
            ],
          ],
        ),
      ),
    );
  }
}
