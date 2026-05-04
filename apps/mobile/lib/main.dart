import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import 'app.dart';
import 'app_navigator_key.dart';
import 'screens/config_error_screen.dart';
import 'services/auth_service.dart';
import 'services/app_config.dart';
import 'services/siri_shortcut_service.dart';

/// Injected before `assets/.env` lines so `--dart-define=GEMINI_API_KEY=...`
/// works when the asset file is missing (CI) or dotfiles are omitted from the bundle.
Map<String, String> _geminiDartDefineMerge() {
  const g = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  final t = g.trim();
  return t.isNotEmpty ? <String, String>{'GEMINI_API_KEY': t} : const {};
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _MobileBootstrap());
}

class _MobileBootstrap extends StatefulWidget {
  const _MobileBootstrap();

  @override
  State<_MobileBootstrap> createState() => _MobileBootstrapState();
}

class _MobileBootstrapState extends State<_MobileBootstrap> {
  Widget _app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    home: const AncodeLoadingScreen(),
  );

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Bundled env: must match a path declared under flutter.assets (see pubspec assets/).
    await dotenv.load(
      fileName: 'assets/.env',
      isOptional: true,
      mergeWith: _geminiDartDefineMerge(),
    );

    const urlFromDefineRaw = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const keyFromDefineRaw = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    final urlFromDefine = urlFromDefineRaw.trim();
    final keyFromDefine = keyFromDefineRaw.trim();
    final supabaseUrl = urlFromDefine.isNotEmpty
        ? urlFromDefine
        : (dotenv.env['SUPABASE_URL']?.trim() ?? '');
    final supabaseAnonKey = keyFromDefine.isNotEmpty
        ? keyFromDefine
        : (dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '');

    if (!mounted) return;
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      setState(() => _app = const ConfigErrorScreen());
      return;
    }

    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    } catch (e, st) {
      debugPrint('Supabase.initialize failed: $e\n$st');
      if (!mounted) return;
      setState(() => _app = ConfigErrorScreen(message: e.toString()));
      return;
    }

    await AppConfig.initialize();
    await SiriShortcutService.instance.initialize();
    if (!mounted) return;
    setState(() => _app = const AncodeMobileApp(supabaseConfigured: true));
  }

  @override
  Widget build(BuildContext context) => _app;
}

class AncodeMobileApp extends StatelessWidget {
  const AncodeMobileApp({super.key, required this.supabaseConfigured});

  final bool supabaseConfigured;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthService(backendEnabled: supabaseConfigured),
        ),
      ],
      child: MaterialApp(
        title: 'ANCODE',
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const AppShell(),
      ),
    );
  }
}
