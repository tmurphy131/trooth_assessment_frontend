import 'package:flutter/material.dart';

/// Picks one of the mentor's current apprentices, or "Someone else" (value `null`)
/// to enter an email instead (spec 005 US1).
class ApprenticePicker extends StatelessWidget {
  const ApprenticePicker({
    super.key,
    required this.apprentices,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<Map<String, dynamic>> apprentices;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  static const someoneElseLabel = 'Someone else (enter email)';

  static String labelFor(Map<String, dynamic> apprentice) {
    final name = (apprentice['name'] as String?)?.trim() ?? '';
    return name.isNotEmpty ? name : (apprentice['email'] as String? ?? '');
  }

  @override
  Widget build(BuildContext context) {
    // Sort a copy: the shared list's order matters elsewhere (free-tier index 0).
    final sorted = [...apprentices]
      ..sort((a, b) => labelFor(a).toLowerCase().compareTo(labelFor(b).toLowerCase()));
    const textStyle = TextStyle(color: Colors.white, fontFamily: 'Poppins');

    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: Colors.grey[850],
      style: textStyle,
      decoration: const InputDecoration(
        labelText: 'Apprentice',
        labelStyle: TextStyle(color: Colors.white70),
      ),
      items: [
        for (final a in sorted)
          DropdownMenuItem<String?>(
            value: a['id'] as String?,
            child: Text(labelFor(a), overflow: TextOverflow.ellipsis, style: textStyle),
          ),
        const DropdownMenuItem<String?>(
          value: null,
          child: Text(someoneElseLabel, overflow: TextOverflow.ellipsis, style: textStyle),
        ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
