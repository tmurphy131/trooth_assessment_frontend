import 'package:flutter/material.dart';
import '../theme.dart';

/// Dialog for adding or editing a mentor note
class AddEditNoteDialog extends StatefulWidget {
  final String? initialNoteText;
  final bool initialShared;
  final bool isEditing;

  const AddEditNoteDialog({
    super.key,
    this.initialNoteText,
    this.initialShared = false,
    this.isEditing = false,
  });

  @override
  State<AddEditNoteDialog> createState() => _AddEditNoteDialogState();
}

class _AddEditNoteDialogState extends State<AddEditNoteDialog> {
  late final TextEditingController _noteController;
  late bool _isPrivate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNoteText ?? '');
    _isPrivate = !widget.initialShared; // initialShared=true means isPrivate=false
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, {
        'content': _noteController.text.trim(),
        'is_private': _isPrivate,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  widget.isEditing ? 'Edit Note' : 'Add Note',
                  style: TextStyle(
                    color: troothGold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Note text field
                TextFormField(
                  controller: _noteController,
                  maxLines: 6,
                  minLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Write your note here...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: troothGold),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a note';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Share toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: !_isPrivate
                        ? troothGold.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_isPrivate
                          ? troothGold.withValues(alpha: 0.5)
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        !_isPrivate
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: !_isPrivate
                            ? troothGold
                            : Colors.grey[500],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share with Apprentice',
                              style: TextStyle(
                                color: !_isPrivate
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              !_isPrivate
                                  ? 'Apprentice can see this note'
                                  : 'Only you can see this note',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: !_isPrivate,
                        onChanged: (value) {
                          setState(() => _isPrivate = !value);
                        },
                        activeColor: troothGold,
                        activeTrackColor: troothGold.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: troothGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.isEditing ? 'Save Changes' : 'Add Note',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
