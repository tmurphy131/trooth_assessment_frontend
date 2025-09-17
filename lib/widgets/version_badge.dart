import 'package:flutter/material.dart';

/// Reusable badge for displaying a spiritual gifts template version.
/// Keeps visual consistency and allows future feature additions (tooltip, tap, etc.).
class VersionBadge extends StatelessWidget {
  final String versionLabel; // already formatted string like 'v3'
  final EdgeInsets padding;
  final double fontSize;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderOpacity;
  final double backgroundOpacity;
  final BorderRadius? borderRadius;

  const VersionBadge({
    super.key,
    required this.versionLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.fontSize = 12,
    this.backgroundColor,
    this.textColor,
    this.borderOpacity = 0.4,
    this.backgroundOpacity = 0.15,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Colors.amber;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (backgroundColor ?? Colors.amber).withOpacity(backgroundOpacity),
        borderRadius: borderRadius ?? BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(borderOpacity)),
      ),
      child: Text(
        versionLabel,
        style: TextStyle(
          color: color,
            fontFamily: 'Poppins',
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
