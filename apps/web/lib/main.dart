import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'screens/config_error_screen.dart';
import 'theme/app_theme.dart';
import 'screens/code_resolve_screen.dart';
import 'services/auth_service.dart';
import 'services/app_config.dart';
import 'services/ancode_service.dart';
import 'utils/url_handler.dart';

/// Fetches public config from Vercel /api/config (reads env vars set in Vercel only).
Future<Map<String, dynamic>?> _fetchConfig(Uri uri) async {
  final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('timeout'),
      );
  if (response.statusCode != 200) return null;
  final map = jsonDecode(response.body) as Map<String, dynamic>?;
  return map;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String supabaseUrl = '';
  String supabaseAnonKey = '';
  bool loaded = false;
  if (kIsWeb) {
    try {
      await dotenv.load(fileName: 'assets/.env');
      supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
      loaded = true;
    } catch (_) {}
  }
  if (!loaded) {
    try {
      await dotenv.load(fileName: '.env');
      supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    } catch (_) {
      // .env missing or not in bundle (web) – use dart-define or show config screen
    }
  }
  if (supabaseUrl.isEmpty) {
    supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  }
  if (supabaseAnonKey.isEmpty) {
    supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  }

  // On web, if still empty (e.g. deployed on Vercel with env vars only in Vercel), fetch from /api/config
  Map<String, dynamic>? apiConfig;
  if (kIsWeb && (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty)) {
    try {
      final uri = Uri.parse('${Uri.base.origin}/api/config');
      apiConfig = await _fetchConfig(uri);
      if (apiConfig != null) {
        supabaseUrl = apiConfig['supabaseUrl']?.toString().trim() ?? '';
        supabaseAnonKey = apiConfig['supabaseAnonKey']?.toString().trim() ?? '';
      }
    } catch (_) {}
  }

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const ConfigErrorScreen());
    return;
  }

  if (apiConfig != null) {
    final stripe = apiConfig['stripePublishableKey']?.toString();
    if (stripe != null && stripe.isNotEmpty) {
      AppConfig.setFromApi(stripePublishableKey: stripe);
    }
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await AppConfig.initialize();
  runApp(const AncodeApp());
}

class AncodeApp extends StatelessWidget {
  const AncodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: '*ANCODE',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: _buildInitialRoute(),
      ),
    );
  }

  static Widget _buildInitialRoute() {
    final code = getInitialResolveCode();
    if (code != null && code.isNotEmpty) {
      return FutureBuilder<dynamic>(
        future: AncodeService.search(code),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final r = snap.data as AncodeSearchResult;
          if (r.uniqueMatch != null) {
            return CodeResolveScreen(code: code, ancode: r.uniqueMatch);
          }
          return const AppShell();
        },
      );
    }
    return const AppShell();
  }
}
