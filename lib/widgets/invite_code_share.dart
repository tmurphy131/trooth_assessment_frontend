import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme.dart';
import '../utils/invite_codes.dart';

/// An invite code with Copy and Share actions, for mentors (backend spec 006).
class InviteCodeShare extends StatelessWidget {
  const InviteCodeShare({super.key, required this.code, required this.mentorName, this.large = false});

  final String code;
  final String mentorName;
  final bool large;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
  }

  Future<void> _share(BuildContext context) async {
    // iPad needs an anchor for the share popover.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
    await Share.share(
      buildInviteShareMessage(mentorName: mentorName, code: code),
      subject: 'Your T[root]H invite code',
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            code,
            style: TextStyle(
              color: kPrimaryGold,
              fontFamily: 'monospace',
              fontSize: large ? 28 : 18,
              fontWeight: FontWeight.bold,
              letterSpacing: large ? 4 : 2,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          color: Colors.white,
          tooltip: 'Copy code',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => _copy(context),
        ),
        Builder(
          builder: (buttonContext) => IconButton(
            icon: const Icon(Icons.ios_share),
            color: Colors.white,
            tooltip: 'Share code',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _share(buttonContext),
          ),
        ),
      ],
    );
  }
}
