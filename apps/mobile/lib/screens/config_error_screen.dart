import 'package:flutter/material.dart';

/// Shown when Supabase env is missing or init failed (web or mobile build).
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key, this.message});

  /// Optional detail (e.g. Supabase init failure).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      useMaterial3: true,
    );
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.settings_suggest, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  'App non configurato',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Manca la configurazione Supabase per questa build.\n\n'
                  '• Mobile: apps/mobile/assets/.env (vedi .env.example) oppure --dart-define.\n'
                  '• Web: apps/web/assets/.env oppure variabili su Vercel / --dart-define.\n'
                  '• CI: imposta SUPABASE_URL e SUPABASE_ANON_KEY nel workflow.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
