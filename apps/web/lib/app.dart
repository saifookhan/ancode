import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'services/auth_service.dart';

/// Public search works for logged-out users; restricted pages require login.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final auth = authService.state;
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Always show MainShell; individual screens handle auth for restricted actions
        return const MainShell();
      },
    );
  }
}

