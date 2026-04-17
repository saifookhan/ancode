import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';
import '../services/app_config.dart';
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
    final shortlink = AppConfig.shortlinkFor(a.normalizedCode);
    final directTarget = a.type == AncodeType.link ? (a.url ?? shortlink) : shortlink;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(title: const Text('ANCODE Print Layout'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: [
              const Text(
                'Print this page to share your code offline',
                style: TextStyle(color: Color(0xFF707684), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                width: 360,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E4E8)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 140,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE3E3E6)),
                      ),
                      child: Column(
                        children: [
                          QrImageView(data: shortlink, version: QrVersions.auto, size: 100),
                          const SizedBox(height: 4),
                          const Text('Scan to Access', style: TextStyle(fontSize: 10, color: Color(0xFF676E7C))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262D3A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        a.code.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _row('Type', a.isLink ? 'link' : 'text'),
                    _row('Comune', a.municipality?.name ?? a.municipalityId),
                    _row('Duration', expirationMessage),
                    _row('Content', a.isLink ? (a.url ?? '') : (a.noteText ?? '')),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              LimeRailPillButton(
                label: 'Download QR',
                height: 58,
                onPressed: () async {
                  await Printing.layoutPdf(
                    onLayout: (format) async {
                      final pdf = pw.Document();
                      pdf.addPage(
                        pw.Page(
                          pageFormat: format,
                          build: (ctx) => pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('*${a.code}', style: pw.TextStyle(fontSize: 24)),
                              pw.SizedBox(height: 16),
                              pw.Text(shortlink, style: const pw.TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                      return pdf.save();
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              WhiteLimePillButton(
                label: 'Copy',
                height: 52,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: shortlink));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                  }
                },
              ),
              const SizedBox(height: 8),
              WhiteLimePillButton(
                label: 'Share',
                height: 52,
                onPressed: () async {
                  try {
                    await SharePlus.instance.share(ShareParams(text: shortlink));
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 8),
              if (a.isLink && a.url != null)
                WhiteLimePillButton(
                  label: 'Test link',
                  height: 52,
                  onPressed: a.status == AncodeStatus.grace
                      ? null
                      : () async {
                          Supabase.instance.client.from('clicks').insert({'ancode_id': a.id});
                          final uri = Uri.tryParse(directTarget);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text('$label:', style: const TextStyle(fontSize: 12, color: Color(0xFF6C7381))),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF2A3140)),
            ),
          ),
        ],
      ),
    );
  }
}
