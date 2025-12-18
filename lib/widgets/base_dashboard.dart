import 'package:flutter/material.dart';
import '../utils/logout_util.dart';

class BaseDashboard extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? bottom;
  final List<Widget>? additionalActions;
  /// Height of the logo in the center of the AppBar. Default is 32.
  final double logoHeight;
  /// Optional explicit width for the logo (if wider than tall). If null, uses height * 3.2 (logo aspect ratio).
  final double? logoWidth;

  const BaseDashboard({
    super.key,
    required this.body,
    this.bottom,
    this.additionalActions,
    this.logoHeight = 32,
    this.logoWidth,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLogoWidth = logoWidth ?? (logoHeight * 3.2); // Match logo aspect ratio (625:193)
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 4,
        toolbarHeight: logoHeight + 16, // add vertical padding
        title: SizedBox(
          height: logoHeight,
          width: effectiveLogoWidth,
          child: Image.asset(
            "assets/logo.png",
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        actions: [
          if (additionalActions != null) ...additionalActions!,
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFFD700)),
            onPressed: () => logoutAndRedirect(context),
            tooltip: 'Logout',
          ),
        ],
        bottom: bottom,
      ),
      body: body,
    );
  }
}
