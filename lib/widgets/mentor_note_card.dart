import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mentor_note.dart';
import '../theme.dart';

/// Card widget displaying a single mentor note
class MentorNoteCard extends StatelessWidget {
  final MentorNote note;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showActions;

  const MentorNoteCard({
    super.key,
    required this.note,
    this.onEdit,
    this.onDelete,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: note.isShared
              ? troothGold.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with timestamp and sharing status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Timestamp
                Icon(
                  Icons.access_time,
                  color: Colors.grey[500],
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimestamp(note.displayTimestamp),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                // Edited indicator
                if (note.wasEdited) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(edited)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const Spacer(),
                // Shared indicator
                if (note.isShared) ...[
                  Icon(
                    Icons.visibility,
                    color: troothGold,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Shared',
                    style: TextStyle(
                      color: troothGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.visibility_off,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Private',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Note content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              note.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          // Actions
          if (showActions && (onEdit != null || onDelete != null))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[300],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }
}
