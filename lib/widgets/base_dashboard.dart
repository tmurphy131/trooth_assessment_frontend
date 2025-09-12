import 'package:flutter/material.dart';
import '../utils/logout_util.dart';

class BaseDashboard extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? bottom;
  final List<Widget>? additionalActions;
  /// Height of the logo in the center of the AppBar. Default is 40.
  final double logoHeight;
  /// Optional explicit width for the logo (if wider than tall). If null, uses height.
  final double? logoWidth;

  const BaseDashboard({
    super.key,
    required this.body,
    this.bottom,
    this.additionalActions,
  this.logoHeight = 20,
  this.logoWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 4,
        toolbarHeight: logoHeight + 10, // add a little vertical padding
        title: SizedBox(
          height: logoHeight,
          width: logoWidth ?? logoHeight,
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
