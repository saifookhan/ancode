import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_navigator_key.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/stripe_checkout_links.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  StreamSubscription<Uri>? _linkSub;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    unawaited(_initStripeReturnLinks());
  }

  Future<void> _initStripeReturnLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null && StripeCheckoutLinks.isPaymentCallback(initial)) {
        await _handleStripeReturnUri(initial);
      }
    } catch (_) {}
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (StripeCheckoutLinks.isPaymentCallback(uri)) {
          unawaited(_handleStripeReturnUri(uri));
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _handleStripeReturnUri(Uri uri) async {
    final checkout = uri.queryParameters['checkout'];
    if (checkout == 'success') {
      await _refreshPlanAfterPayment();
    }
    final messengerContext = appNavigatorKey.currentContext;
    if (messengerContext != null && messengerContext.mounted) {
      final nav = Navigator.of(messengerContext, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }
      final message = checkout == 'success'
          ? 'Pagamento completato. Piano aggiornato.'
          : checkout == 'cancel'
              ? 'Pagamento annullato. Il piano non è stato modificato.'
              : null;
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = appNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
          }
        });
      }
    }
  }

  Future<void> _refreshPlanAfterPayment() async {
    for (var i = 0; i < 6; i++) {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        try {
          await Provider.of<AuthService>(ctx, listen: false).refreshProfile();
        } catch (_) {}
      }
      final plan =
          (Supabase.instance.client.auth.currentUser?.userMetadata?['plan'] ?? '').toString().toLowerCase();
      if (plan == 'pro' || plan == 'business') return;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
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
