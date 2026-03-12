import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

class CodeResolveScreen extends StatelessWidget {
  const CodeResolveScreen({
    super.key,
    required this.code,
    this.ancode,
  });

  final String code;
  final Ancode? ancode;

  @override
  Widget build(BuildContext context) {
    if (ancode == null) {
      return Scaffold(
        appBar: AppBar(title: Text('*$code')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final a = ancode!;
    if (a.isLink && a.url != null) {
      Supabase.instance.client.from('clicks').insert({'ancode_id': a.id});
      launchUrl(Uri.parse(a.url!));
      return Scaffold(
        appBar: AppBar(title: Text('*$code')),
        body: const Center(child: Text('Apertura link...')),
      );
    }
    if (a.isNote && a.noteText != null) {
      return Scaffold(
        appBar: AppBar(title: Text('*$code')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  a.noteText!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('*$code')),
      body: const Center(child: Text('Contenuto non disponibile')),
    );
  }
}
