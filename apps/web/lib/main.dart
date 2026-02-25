import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'theme/app_theme.dart';
import 'screens/code_resolve_screen.dart';
import 'services/auth_service.dart';
import 'services/app_config.dart';
import 'services/ancode_service.dart';
import 'utils/url_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
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
