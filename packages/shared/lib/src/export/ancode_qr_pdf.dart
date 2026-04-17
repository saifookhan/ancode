import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';

/// Builds the printable QR + metadata PDF used by Download QR / Share flows.
class AncodeQrPdf {
  AncodeQrPdf._();

  static Future<Uint8List> build({
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

  static pw.Widget _pdfRow(String label, String value) {
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

  /// Same URL normalization used when opening links in an external browser.
  static Uri? normalizeHttpUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return parsed;
    return Uri.tryParse('https://$trimmed');
  }
}
