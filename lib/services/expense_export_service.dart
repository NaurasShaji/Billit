import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'expense_logic.dart';

/// Builds CSV / PDF files for a list of expenses and saves or shares them.
class ExpenseExportService {
  ExpenseExportService._();

  /// CSV with a UTF-8 marker so Excel shows non-English text correctly.
  static List<int> csvBytes(List<ExpenseLine> lines) =>
      utf8.encode('\uFEFF${ExpenseLogic.buildCsv(lines)}');

  static Future<Uint8List> pdfBytes({
    required List<ExpenseLine> lines,
    required String periodLabel,
    required String shopName,
  }) async {
    final money = NumberFormat('#,##0.00', 'en_IN');
    final dateFmt = DateFormat('dd MMM yyyy');
    final sorted = [...lines]..sort((a, b) => a.date.compareTo(b.date));
    final totals = ExpenseLogic.categoryTotals(sorted);
    final grand = ExpenseLogic.total(sorted);

    pw.Widget stat(String label, String value) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
                pw.SizedBox(height: 3),
                pw.Text(value,
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        );

    final headerStyle = pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    const cellStyle = pw.TextStyle(fontSize: 9);
    const padding = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5);
    final headerDecoration = const pw.BoxDecoration(color: PdfColors.grey800);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style:
                  const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (context) => [
          if (shopName.isNotEmpty)
            pw.Text(shopName,
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('Expense Report',
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text(periodLabel,
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              stat('Total expenses', 'Rs ${money.format(grand)}'),
              pw.SizedBox(width: 10),
              stat('Entries', '${sorted.length}'),
              pw.SizedBox(width: 10),
              stat('Categories', '${totals.length}'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('By category',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Entries', 'Amount (Rs)', 'Share'],
            data: [
              for (final c in totals)
                [
                  c.category,
                  '${c.count}',
                  money.format(c.total),
                  '${(c.share * 100).toStringAsFixed(1)}%',
                ],
            ],
            headerStyle: headerStyle,
            headerDecoration: headerDecoration,
            cellStyle: cellStyle,
            cellPadding: padding,
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          ),
          pw.SizedBox(height: 18),
          pw.Text('All expenses',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Description', 'Amount (Rs)'],
            data: [
              for (final e in sorted)
                [
                  dateFmt.format(e.date),
                  ExpenseLogic.categoryLabel(e.category),
                  e.description,
                  money.format(e.amount),
                ],
              ['', '', 'Total', money.format(grand)],
            ],
            headerStyle: headerStyle,
            headerDecoration: headerDecoration,
            cellStyle: cellStyle,
            cellPadding: padding,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(1.4),
            },
            cellAlignments: {3: pw.Alignment.centerRight},
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  /// Lets the user pick where to save. Returns false if they cancelled.
  static Future<bool> save(String filename, List<int> bytes) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save export',
      fileName: filename,
      bytes: Uint8List.fromList(bytes),
    );
    return path != null;
  }

  static Future<void> share(
      String filename, List<int> bytes, String mimeType) async {
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: mimeType,
          name: filename,
        ),
      ],
      subject: filename,
    );
  }
}
