import 'package:flutter/material.dart';
import '../utils/logout_util.dart';

class BaseDashboard extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? bottom;

  const BaseDashboard({
    super.key,
    required this.body,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 4,
        title: Image.asset(
          "assets/logo.png",
          height: 40,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFFD700)),
            onPressed: () => logoutAndRedirect(context),
          ),
        ],
        bottom: bottom,
      ),
      body: body,
    );
  }
}
