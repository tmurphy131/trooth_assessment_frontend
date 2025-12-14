import 'package:flutter/material.dart';

class BarRow extends StatelessWidget {
  final String label;
  final int value; // 0..100
  const BarRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 100);
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label)),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(children: [
              Container(height: 10, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6))),
              FractionallySizedBox(
                widthFactor: clamped / 100.0,
                child: Container(height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text('$clamped%')),
        ],
      ),
    );
  }
}
