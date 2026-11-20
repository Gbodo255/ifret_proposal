
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models.dart';
import 'device.dart';

/// Le PDF n'a pas l'espace fine : on la remplace par une espace simple.
String _plain(String s) => s.replaceAll(' ', ' ').replaceAll('→', '-');

/// Reçu d'une course, au format A5.
Future<Uint8List> buildReceipt(Course c) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/WorkSans-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/WorkSans-Bold.ttf'));
  final delivered = c.status == CourseStatus.delivered;
  final paid = delivered ? c.total : c.deposit;
  pw.Widget line(String label, String value, {bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text(label), pw.Text(_plain(value), style: strong ? pw.TextStyle(font: bold, fontSize: 13) : null)],
        ),
      );
  final doc = pw.Document(title: 'Reçu ${c.ref}', author: 'i-fret')
    ..addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFCC00), borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('i-fret · Reçu ${c.ref}', style: pw.TextStyle(font: bold, fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text(_plain(money(paid)), style: pw.TextStyle(font: bold, fontSize: 26)),
                  pw.Text(delivered ? 'Course livrée · ${c.date}' : 'Acompte payé · ${c.date}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Trajet', style: pw.TextStyle(font: bold)),
            line('Chargement', c.from.name),
            line('Livraison', c.to.name),
            line('Distance', '${c.km} km'),
            line('Véhicule', c.vehicle.name),
            line('Marchandise', c.cargo),
            if (c.carrier.isNotEmpty) line('Transporteur', '${c.carrier} · ${c.plate}'),
            pw.Divider(color: PdfColors.grey400),
            pw.Text('Paiement', style: pw.TextStyle(font: bold)),
            line('Prix de la course', money(c.price)),
            if (c.adjustment > 0) line('Frais imprévus validés par ILT', '+ ${money(c.adjustment)}'),
            line('Acompte', money(c.deposit)),
            if (delivered) line('Solde', money(c.balance)),
            pw.Divider(color: PdfColors.grey400),
            line('Total payé', money(paid), strong: true),
            line('Moyen de paiement', mobileMoney[c.operator] ?? c.operator),
            pw.Spacer(),
            pw.Text('i-fret, un service ILT', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
  return doc.save();
}

/// Ouvre le partage du téléphone avec le reçu en PDF.
Future<void> shareReceipt(BuildContext context, Course c) => _withPdf(context, c, (bytes) => Printing.sharePdf(bytes: bytes, filename: 'recu-${c.ref}.pdf'));

/// Ouvre la fenêtre du téléphone pour enregistrer ou imprimer le reçu.
Future<void> saveReceipt(BuildContext context, Course c) => _withPdf(context, c, (bytes) => Printing.layoutPdf(name: 'recu-${c.ref}', format: PdfPageFormat.a5, onLayout: (_) => bytes));

Future<void> _withPdf(BuildContext context, Course c, Future<Object?> Function(Uint8List) use) async {
  if (inTest) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await use(await buildReceipt(c));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Impossible de préparer le reçu. Réessaie dans un instant.')));
  }
}
