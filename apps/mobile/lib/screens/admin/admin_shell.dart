import 'package:flutter/material.dart';

import 'admin_overview_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin *ANCODE'),
      ),
      body: const AdminOverviewScreen(),
    );
  }
}
