import 'dart:html' as html;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/main_shell.dart';
import 'services/auth_service.dart';

/// Public search works for logged-out users; restricted pages require login.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleStripeCheckoutReturn());
  }

  Future<void> _handleStripeCheckoutReturn() async {
    if (!kIsWeb) return;
    final uri = Uri.base;
    final checkout = uri.queryParameters['checkout'];
    if (checkout != 'success' && checkout != 'cancel') return;

    _stripCheckoutQueryFromBrowserUrl(uri);

    if (checkout == 'success') {
      await _refreshPlanAfterPayment();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pagamento completato. Piano aggiornato.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pagamento annullato. Il piano non è stato modificato.')),
        );
      }
    }
  }

  void _stripCheckoutQueryFromBrowserUrl(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    html.window.history.replaceState(null, html.document.title, path);
  }

  Future<void> _refreshPlanAfterPayment() async {
    for (var i = 0; i < 6; i++) {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
      if (!mounted) return;
      try {
        await context.read<AuthService>().refreshProfile();
      } catch (_) {}
      final plan =
          (Supabase.instance.client.auth.currentUser?.userMetadata?['plan'] ?? '').toString().toLowerCase();
      if (plan == 'pro' || plan == 'business') return;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

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
        return const MainShell();
      },
    );
  }
}
