import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AgreementPreviewScreen extends StatelessWidget {
  final String markdown;
  final String? apprenticeEmail;
  final String? parentEmail;
  final String status;

  const AgreementPreviewScreen({
    super.key,
    required this.markdown,
    required this.status,
    this.apprenticeEmail,
    this.parentEmail,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'draft': return Colors.grey;
      case 'awaiting_apprentice': return Colors.orange;
      case 'awaiting_parent': return Colors.purple;
      case 'fully_signed': return Colors.green;
      case 'revoked': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = _statusColor(status);
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Agreement Preview', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chipColor),
            ),
            child: Center(child: Text(status, style: TextStyle(color: chipColor, fontFamily: 'Poppins', fontWeight: FontWeight.w600))),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (apprenticeEmail != null || parentEmail != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16,16,16,4),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (apprenticeEmail != null)
                    Text('Apprentice: $apprenticeEmail', style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                  if (parentEmail != null)
                    Text('Parent: $parentEmail', style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                ],
              ),
            ),
          const Divider(height: 1, color: Colors.grey),
          Expanded(
            child: Markdown(
              data: markdown,
              selectable: true,
              padding: const EdgeInsets.all(16),
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14, height: 1.3),
                h1: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 26, fontWeight: FontWeight.bold),
                h2: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.bold),
                h3: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold),
                code: const TextStyle(fontFamily: 'monospace', color: Colors.lightBlueAccent),
                blockquote: TextStyle(color: Colors.grey[300], fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
