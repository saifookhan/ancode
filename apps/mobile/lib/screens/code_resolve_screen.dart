import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';
import '../services/plan_mode_service.dart';

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
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentPlan = PlanModeService.currentPlan(currentUser);
    final subscriptionEnd = PlanModeService.subscriptionEnd(currentUser);
    final expirationMessage = PlanModeService.expirationLabel(
      code: a,
      plan: currentPlan,
      subscriptionEndDate: subscriptionEnd,
    );
    return Scaffold(
      appBar: AppBar(title: Text('*$code')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Code details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _row('Code', a.code),
              _row('Type', a.isLink ? 'Link' : 'Text / Note'),
              _row('Area', a.municipality?.name ?? a.municipalityId),
              _row('Scadenza', expirationMessage),
              const SizedBox(height: 14),
              Text(
                a.isLink ? (a.url ?? 'Contenuto non disponibile') : (a.noteText ?? 'Contenuto non disponibile'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (a.status == AncodeStatus.grace) ...[
                const SizedBox(height: 10),
                const Text(
                  'Codice in GRACE period: non cliccabile fino a riattivazione.',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                ),
              ],
              if (a.isLink && a.url != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: a.status == AncodeStatus.grace
                      ? null
                      : () async {
                          Supabase.instance.client.from('clicks').insert({'ancode_id': a.id});
                          await launchUrl(Uri.parse(a.url!), mode: LaunchMode.externalApplication);
                        },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open link'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
