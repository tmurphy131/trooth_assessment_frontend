import 'package:flutter/material.dart';

class LevelBadge extends StatelessWidget {
  final String level;
  const LevelBadge({super.key, required this.level});

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'seedling':
      case 'low':
        return Colors.orange;
      case 'growing':
      case 'medium':
        return Colors.blue;
      case 'mature':
      case 'high':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _levelColor(level).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(level, style: TextStyle(color: _levelColor(level))),
    );
  }
}
