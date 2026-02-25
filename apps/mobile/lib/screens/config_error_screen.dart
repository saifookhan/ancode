import 'package:flutter/material.dart';

/// Shown when .env is missing (e.g. Android release without env in assets).
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
                  'File .env mancante o credenziali Supabase assenti.\n\n'
                  'Crea apps/mobile/.env con SUPABASE_URL e SUPABASE_ANON_KEY (copia da .env.example), poi riesegui.',
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
