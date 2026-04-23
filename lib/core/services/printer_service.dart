import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/terminal/data/models/cart_item.dart';
import '../../features/terminal/data/models/sale_model.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._();
  PrinterService._();

  static const double _pageWidth = 72 * PdfPageFormat.mm;

  Future<void> printReceipt({
    required String      saleId,
    required List<CartItem> items,
    required double      total,
    required OdemeTip    odemeTip,
    String?              customerName,
    String               businessName = 'Liqra Market',
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
    final fmt = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _pageWidth, PdfPageFormat.a4.height, marginAll: 4 * PdfPageFormat.mm),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(child: pw.Column(children: [
              pw.Text(businessName,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(now, style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Fiş: ${saleId.substring(0, 8).toUpperCase()}',
                style: const pw.TextStyle(fontSize: 8)),
            ])),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.5),
            ...items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(children: [
                pw.Expanded(flex: 5,
                  child: pw.Text(item.product.name,
                    style: const pw.TextStyle(fontSize: 9))),
                pw.Text('${item.quantity}x${fmt.format(item.product.price)}',
                  style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(width: 4),
                pw.Text(fmt.format(item.lineTotal),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ]),
            )),
            pw.Divider(thickness: 0.5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOPLAM',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(fmt.format(total),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(_paymentLabel(odemeTip, customerName),
              style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 12),
            pw.Center(child: pw.Text('Teşekkürler!',
              style: const pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text('- - - - - - - - - - - - - -',
              style: const pw.TextStyle(fontSize: 8))),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Fis_${saleId.substring(0, 8)}',
    );
  }

  String _paymentLabel(OdemeTip tip, String? customerName) => switch (tip) {
    OdemeTip.nakit      => 'Ödeme: Nakit',
    OdemeTip.krediKarti => 'Ödeme: Kredi Kartı',
    OdemeTip.veresiye   => 'Veresiye: ${customerName ?? 'Müşteri'}',
  };

  Future<Printer?> pickPrinter(BuildContext context) =>
      Printing.pickPrinter(context: context);
}
