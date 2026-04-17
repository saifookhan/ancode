import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
                  try {
                    await Printing.layoutPdf(
                      onLayout: (format) => _buildQrPdf(
                        format: format,
                        ancode: a,
                        shortlink: shortlink,
                        expirationMessage: expirationMessage,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('QR export failed: $e')),
                    );
                  }
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
                    final pdfBytes = await _buildQrPdf(
                      format: PdfPageFormat.a4,
                      ancode: a,
                      shortlink: shortlink,
                      expirationMessage: expirationMessage,
                    );
                    await Printing.sharePdf(
                      bytes: pdfBytes,
                      filename: 'ancode_${a.code.toUpperCase()}.pdf',
                    );
                  } catch (_) {
                    final fallbackText = a.isLink ? (a.url ?? shortlink) : shortlink;
                    await Clipboard.setData(ClipboardData(text: fallbackText));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open share menu. Link copied instead.')),
                    );
                  }
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
                          final uri = _normalizedUri(directTarget);
                          if (uri != null) {
                            final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                            if (!opened && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open link')),
                              );
                            }
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid link format')),
                            );
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

  Future<Uint8List> _buildQrPdf({
    required PdfPageFormat format,
    required Ancode ancode,
    required String shortlink,
    required String expirationMessage,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'ANCODE Print Layout',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Scan to access this ANCODE',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 18),
                pw.Center(
                  child: pw.BarcodeWidget(
                    data: shortlink,
                    width: 150,
                    height: 150,
                    barcode: pw.Barcode.qrCode(),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.indigo900,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      ancode.code.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                _pdfRow('Type', ancode.isLink ? 'link' : 'text'),
                _pdfRow('Comune', ancode.municipality?.name ?? ancode.municipalityId),
                _pdfRow('Duration', expirationMessage),
                _pdfRow('Content', ancode.isLink ? (ancode.url ?? '') : (ancode.noteText ?? '')),
                pw.SizedBox(height: 14),
                _pdfRow('Short link', shortlink),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '—' : value,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Uri? _normalizedUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return parsed;
    return Uri.tryParse('https://$trimmed');
  }
}
