import 'package:flutter/material.dart';

/// Shown when SUPABASE_URL / SUPABASE_ANON_KEY are missing (e.g. live deploy or Android without .env).
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Mancano SUPABASE_URL e SUPABASE_ANON_KEY.\n\n'
                  '• Web locale: copia .env in apps/web/assets/.env oppure avvia con --dart-define.\n\n'
                  '• Per Vercel: imposta le variabili d’ambiente nel progetto Vercel e ricompila con dart-define o usa un build che le inietta.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
