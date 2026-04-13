import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import 'app.dart';
import 'screens/config_error_screen.dart';
import 'services/auth_service.dart';
import 'services/app_config.dart';
import 'services/siri_shortcut_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bundled env: must match a path declared under flutter.assets (see pubspec assets/).
  await dotenv.load(fileName: 'assets/.env', isOptional: true);

  const urlFromDefineRaw =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const keyFromDefineRaw =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  final urlFromDefine = urlFromDefineRaw.trim();
  final keyFromDefine = keyFromDefineRaw.trim();
  final supabaseUrl = urlFromDefine.isNotEmpty
      ? urlFromDefine
      : (dotenv.env['SUPABASE_URL']?.trim() ?? '');
  final supabaseAnonKey = keyFromDefine.isNotEmpty
      ? keyFromDefine
      : (dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const ConfigErrorScreen());
    return;
  }

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (e, st) {
    debugPrint('Supabase.initialize failed: $e\n$st');
    runApp(ConfigErrorScreen(message: e.toString()));
    return;
  }

  await AppConfig.initialize();
  await SiriShortcutService.instance.initialize();
  runApp(const AncodeMobileApp());
}

class AncodeMobileApp extends StatelessWidget {
  const AncodeMobileApp({super.key});

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
        home: const AppShell(),
      ),
    );
  }
}
