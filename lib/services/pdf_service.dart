import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import './boxes.dart';

class PdfService {
  // Thermal printer configurations
  static const double thermalWidth58mm = 164.0; // 58mm width
  static const double thermalWidth80mm = 227.0; // 80mm width

  static Future<void> generateInvoice(
    Sale sale, {
    ThermalSize thermalSize = ThermalSize.mm80,
    bool includeHeader = true,
    bool includeFooter = true,
    bool includeGST = true,
    bool fullPage = true,
  }) async {
    final doc = pw.Document();
    final qrImage = await _loadPaymentQrImage();

    if (fullPage) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildFullPageInvoice(
            sale,
            includeHeader: includeHeader,
            includeFooter: includeFooter,
            includeGST: includeGST,
            qrImage: qrImage,
          ),
        ),
      );
    } else {
      final double pageWidth =
          thermalSize == ThermalSize.mm58 ? thermalWidth58mm : thermalWidth80mm;
            doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            pageWidth,
            double.infinity,
            marginLeft: 4,
            marginRight: 4,
            marginTop: 6,
            marginBottom: 6,
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: _buildThermalReceipt(
              sale, thermalSize, qrImage, includeHeader, includeFooter,
            ),
          ),
        ),
      );
    }

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${includeGST && sale.gstEnabled ? 'gst_invoice' : 'invoice'}_${sale.id}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
  }

  static List<pw.Widget> _buildFullPageInvoice(
    Sale sale, {
    required bool includeHeader,
    required bool includeFooter,
    required bool includeGST,
    pw.ImageProvider? qrImage,
  }) {
    final settings = Hive.box<dynamic>('app_settings');
    final businessName = settings.get('business_name', defaultValue: 'Business Name').toString();
    final businessAddress = settings.get('business_address', defaultValue: '').toString();
    final businessPhone = settings.get('business_phone', defaultValue: '').toString();
    final businessEmail = settings.get('business_email', defaultValue: '').toString();
    final businessGstin = settings.get('business_gstin', defaultValue: '').toString();
    pw.ImageProvider? businessLogo;
    final logoBase64 = settings.get('business_logo_base64') as String?;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try { businessLogo = pw.MemoryImage(base64Decode(logoBase64)); } catch (_) { businessLogo = null; }
    }
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final subtotal = sale.items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final taxable = sale.gstEnabled
        ? sale.taxableAmount
        : (subtotal - sale.discount).clamp(0.0, double.infinity).toDouble();
    final taxTotal = sale.cgstAmount + sale.sgstAmount + sale.igstAmount;
    final displayGst = includeGST && sale.gstEnabled;
    final productsBox = Hive.box<Product>(Boxes.products);
    final itemRows = <List<String>>[
      if (displayGst)
        ['#', 'Description', 'HSN/SAC', 'Qty', 'Rate', 'Taxable', 'GST %', 'Tax', 'Line total']
      else
        ['#', 'Description', 'Qty', 'Rate', 'Amount'],
      for (var i = 0; i < sale.items.length; i++)
        if (displayGst)
          [
            '${i + 1}',
            productsBox.get(sale.items[i].productId)?.name ?? 'Unknown Product',
            sale.items[i].hsnCode.isNotEmpty ? sale.items[i].hsnCode : (productsBox.get(sale.items[i].productId)?.hsnCode ?? '-'),
            '${sale.items[i].qty} ${sale.items[i].unitLabel}',
            currency.format(sale.items[i].sellingPrice),
            currency.format(sale.items[i].taxableAmount),
            '${(sale.items[i].gstRate ?? 0.0).toStringAsFixed(2)}%',
            currency.format(sale.items[i].cgstAmount + sale.items[i].sgstAmount + sale.items[i].igstAmount),
            currency.format(sale.items[i].taxableAmount + sale.items[i].cgstAmount + sale.items[i].sgstAmount + sale.items[i].igstAmount),
          ]
        else
          [
            '${i + 1}',
            productsBox.get(sale.items[i].productId)?.name ?? 'Unknown Product',
            '${sale.items[i].qty} ${sale.items[i].unitLabel}',
            currency.format(sale.items[i].sellingPrice),
            currency.format(sale.items[i].subtotal),
          ],
    ];

    return [
      if (includeHeader) ...[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (businessLogo != null) ...[
                    pw.Container(width: 110, height: 60, alignment: pw.Alignment.centerLeft, child: pw.Image(businessLogo, fit: pw.BoxFit.contain)),
                    pw.SizedBox(height: 6),
                  ],
                  pw.Text(businessName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  if (businessAddress.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text(businessAddress)),
                  if (businessPhone.isNotEmpty) pw.Text('Phone: $businessPhone'),
                  if (businessEmail.isNotEmpty) pw.Text('Email: $businessEmail'),
                  if (businessGstin.isNotEmpty) pw.Text('GSTIN: $businessGstin', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(displayGst ? 'TAX INVOICE' : 'INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text('Invoice: ${sale.id}'),
                  pw.Text('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(sale.date.toLocal())}'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Divider(color: PdfColors.grey600),
      ],
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BILL TO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 5),
            pw.Text(sale.customerName.isEmpty ? 'Walk-in customer' : sale.customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            if (sale.customerPhone.isNotEmpty) pw.Text('Phone: ${sale.customerPhone}'),
            if (sale.customerGstin.isNotEmpty) pw.Text('Customer GSTIN: ${sale.customerGstin}'),
          ],
        ),
      ),
      pw.SizedBox(height: 18),
      pw.Table.fromTextArray(
        headers: itemRows.first,
        data: itemRows.skip(1).toList(),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: displayGst
            ? {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(3.5),
                2: const pw.FlexColumnWidth(1.6),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(1.7),
                5: const pw.FlexColumnWidth(1.8),
                6: const pw.FlexColumnWidth(1.2),
                7: const pw.FlexColumnWidth(1.7),
                8: const pw.FlexColumnWidth(1.8),
              }
            : {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FlexColumnWidth(2),
              },
        cellAlignments: displayGst
            ? {
                0: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
              }
            : {
                0: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
      ),
      pw.SizedBox(height: 18),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Payment method: ${sale.payment.name.toUpperCase()}'),
                if (displayGst) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('GST rates are shown against each invoice line.'),
                  pw.Text(sale.interstateSale ? 'Tax type: IGST (interstate)' : 'Tax type: CGST + SGST (intrastate)'),
                ],
                if (includeFooter) ...[
                  pw.SizedBox(height: 18),
                  pw.Text('Thank you for your business.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('This invoice is generated electronically.'),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 24),
          pw.SizedBox(
            width: 230,
            child: pw.Column(
              children: [
                _fullPageTotalRow('Subtotal', currency.format(subtotal)),
                if (sale.discount > 0) _fullPageTotalRow('Discount', '-${currency.format(sale.discount)}'),
                if (displayGst) _fullPageTotalRow('Taxable value', currency.format(taxable)),
                if (displayGst && !sale.interstateSale) _fullPageTotalRow('CGST', currency.format(sale.cgstAmount)),
                if (displayGst && !sale.interstateSale) _fullPageTotalRow('SGST', currency.format(sale.sgstAmount)),
                if (displayGst && sale.interstateSale) _fullPageTotalRow('IGST', currency.format(sale.igstAmount)),
                if (displayGst) _fullPageTotalRow('Total GST', currency.format(taxTotal)),
                pw.Divider(color: PdfColors.grey700, thickness: 1),
                _fullPageTotalRow('GRAND TOTAL', currency.format(sale.totalAmount), bold: true),
              ],
            ),
          ),
        ],
      ),
      if (qrImage != null) ...[
        pw.SizedBox(height: 18),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              children: [
                pw.Text('SCAN & PAY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Image(qrImage, width: 82, height: 82, fit: pw.BoxFit.contain),
              ],
            ),
          ],
        ),
      ],
      pw.SizedBox(height: 24),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          'Amount in words: ${_amountInWords(sale.totalAmount)}',
          style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
        ),
      ),
    ];
  }

  static Future<pw.ImageProvider?> _loadPaymentQrImage() async {
    try {
      final settings = Hive.box<dynamic>('app_settings');
      final savedQr = settings.get('payment_qr_base64') as String?;
      if (savedQr != null && savedQr.isNotEmpty) {
        return pw.MemoryImage(base64Decode(savedQr));
      }
    } catch (_) {
      // Fall back to the bundled QR asset when settings are not available.
    }
    try {
      final data = await rootBundle.load('assets/tap_and_pay_qr.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static String _amountInWords(double amount) {
    final paiseTotal = (amount * 100).round();
    final rupees = paiseTotal ~/ 100;
    final paise = paiseTotal % 100;
    final parts = <String>['${_convertToWords(rupees)} Rupees'];
    if (paise > 0) parts.add('${_convertToWords(paise)} Paise');
    return '${parts.join(" and ")} Only';
  }

  static pw.Widget _fullPageTotalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.SizedBox(width: 8),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildThermalReceipt(
    Sale sale,
    ThermalSize thermalSize,
    pw.ImageProvider? qrImage,
    bool includeHeader,
    bool includeFooter,
  ) {
    final bool is58mm = thermalSize == ThermalSize.mm58;
    final double contentWidth = is58mm ? 156 : 219;
    final double itemWidth = is58mm ? 78 : 106;
    final double qtyWidth = is58mm ? 18 : 22;
    final double rateWidth = is58mm ? 30 : 45;
    final double amountWidth = is58mm ? 30 : 46;
    final double fontSize = is58mm ? 6.5 : 8;
    final subtotal = sale.items.fold(0.0, (sum, item) => sum + item.subtotal);
    final settings = Hive.box<dynamic>('app_settings');
    final businessName = settings.get('business_name', defaultValue: 'Business Name').toString();
    final businessAddress = settings.get('business_address', defaultValue: '').toString();
    final businessPhone = settings.get('business_phone', defaultValue: '').toString();
    final businessGstin = settings.get('business_gstin', defaultValue: '').toString();

    return [
      if (includeHeader) ...[
        pw.Text(businessName,
            style: pw.TextStyle(
                fontSize: fontSize + 4, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        if (businessAddress.isNotEmpty) pw.Text(businessAddress, style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.center),
        if (businessPhone.isNotEmpty) pw.Text(businessPhone, style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.center),
        if (businessGstin.isNotEmpty) pw.Text('GSTIN: $businessGstin', style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.center),
        pw.Text('INVOICE',
            style: pw.TextStyle(
                fontSize: fontSize + 1, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 4),
      ],
      _thermalInfoRow('ID:', sale.id, fontSize),
      _thermalInfoRow('Date:',
          DateFormat('dd/MM/yyyy HH:mm').format(sale.date.toLocal()), fontSize),
      if (sale.customerName.isNotEmpty)
        _thermalInfoRow('Customer:',
            _truncateText(sale.customerName, is58mm ? 15 : 32), fontSize),
      if (sale.customerPhone.isNotEmpty)
        _thermalInfoRow('Phone:', sale.customerPhone, fontSize),
      _thermalInfoRow('Payment:', sale.payment.name.toUpperCase(), fontSize),
      _thermalSeparator(contentWidth),
      _thermalTableRow('ITEM', 'PRICE', 'QTY', 'AMT', itemWidth, rateWidth,
          qtyWidth, amountWidth, fontSize,
          bold: true),
      _thermalSeparator(contentWidth),
      ...sale.items.asMap().entries.expand((entry) {
        final itemNumber = entry.key + 1;
        final item = entry.value;
        final product = Hive.box<Product>(Boxes.products).get(item.productId);
        final productName = _truncateText(
            '$itemNumber. ${product?.name ?? 'Unknown Product'}',
            is58mm ? 15 : 24);
        final qty =
            item.qty.toStringAsFixed(product?.unit == UnitType.kg ? 1 : 0);
        final unitLabel = item.unitLabel.isNotEmpty
            ? item.unitLabel
            : (product?.unit.name ?? '');
        return <pw.Widget>[
          _thermalTableRow(
            productName,
            'Rs.${item.sellingPrice.toStringAsFixed(2)}',
            qty,
            'Rs.${item.subtotal.toStringAsFixed(2)}',
            itemWidth,
            rateWidth,
            qtyWidth,
            amountWidth,
            fontSize,
          ),
          if (unitLabel.isNotEmpty)
            pw.Text('  Unit: $unitLabel',
                style: pw.TextStyle(fontSize: fontSize - 1)),
        ];
      }),
      _thermalSeparator(contentWidth),
      _thermalTotalRow(
          'Subtotal:', 'Rs.${subtotal.toStringAsFixed(2)}', contentWidth, fontSize),
      if (sale.discount > 0)
        _thermalTotalRow('Discount:', '-Rs.${sale.discount.toStringAsFixed(2)}',
            contentWidth, fontSize),
      if (sale.gstEnabled) ...[
        _thermalTotalRow('Taxable value:', 'Rs.${sale.taxableAmount.toStringAsFixed(2)}', contentWidth, fontSize),
        if (sale.interstateSale)
          _thermalTotalRow('IGST:', 'Rs.${sale.igstAmount.toStringAsFixed(2)}', contentWidth, fontSize)
        else ...[
          _thermalTotalRow('CGST:', 'Rs.${sale.cgstAmount.toStringAsFixed(2)}', contentWidth, fontSize),
          _thermalTotalRow('SGST:', 'Rs.${sale.sgstAmount.toStringAsFixed(2)}', contentWidth, fontSize),
        ],
      ],
      _thermalSeparator(contentWidth, doubleLine: true),
      _thermalTotalRow('TOTAL:', 'Rs.${sale.totalAmount.toStringAsFixed(2)}',
          contentWidth, fontSize + 3,
          bold: true),
      if (qrImage != null) ...[
        pw.SizedBox(height: 5),
        pw.Text(
          'SCAN & PAY',
          style: pw.TextStyle(
            fontSize: fontSize + 1,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.Center(child: pw.Image(qrImage, width: is58mm ? 80 : 100)),
      ],
      if (includeFooter) ...[
        pw.SizedBox(height: 5),
        pw.Text('THANK YOU!',
            style: pw.TextStyle(
                fontSize: fontSize + 1, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
      ],
    ];
  }

  static pw.Widget _thermalInfoRow(
      String label, String value, double fontSize) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
            width: 56,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: fontSize))),
      ],
    );
  }

  static pw.Widget _thermalTableRow(
    String item,
    String qty,
    String rate,
    String amount,
    double itemWidth,
    double qtyWidth,
    double rateWidth,
    double amountWidth,
    double fontSize, {
    bool bold = false,
  }) {
    final style = pw.TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
            width: itemWidth, child: pw.Text(item, style: style, maxLines: 1)),
        pw.SizedBox(
            width: rateWidth,
            child: pw.Text(rate, style: style, textAlign: pw.TextAlign.right)),
        pw.SizedBox(
            width: qtyWidth,
            child: pw.Text(qty, style: style, textAlign: pw.TextAlign.right)),
        pw.SizedBox(
            width: amountWidth,
            child:
                pw.Text(amount, style: style, textAlign: pw.TextAlign.right)),
      ],
    );
  }

  static pw.Widget _thermalTotalRow(
      String label, String value, double width, double fontSize,
      {bool bold = false}) {
    final style = pw.TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.max,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: style), pw.Text(value, style: style)],
    );
  }

  static pw.Widget _thermalSeparator(double width, {bool doubleLine = false}) {
    return pw.Container(
      width: width,
      height: doubleLine ? 1.2 : 0.7,
      color: PdfColors.black,
      margin: const pw.EdgeInsets.symmetric(vertical: 1),
    );
  }

  // Header Section optimized for both sizes
  static List<pw.Widget> _buildHeader(
      ThermalSize thermalSize, pw.ImageProvider? logoImage) {
    final bool isWide = thermalSize == ThermalSize.mm80;
    final bool is58mm = thermalSize == ThermalSize.mm58;

    return [
      // Company Logo container with proper aspect ratio
      pw.Container(
        width: double.infinity,
        height: is58mm
            ? 100
            : (isWide ? 140 : 120), // Taller box for better logo display
        padding: pw.EdgeInsets.symmetric(
          horizontal: is58mm ? 4 : 6,
          vertical: is58mm ? 8 : 10,
        ), // Asymmetric padding for better fit
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 2),
          borderRadius: pw.BorderRadius.circular(8),
          color: PdfColors.white,
        ),
        child: pw.Center(
          child: logoImage != null
              ? pw.Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: pw.Image(
                    logoImage,
                    fit: pw.BoxFit
                        .contain, // Changed from fill to contain for better aspect ratio
                    alignment: pw.Alignment.center,
                  ),
                )
              : pw.Container(
                  constraints: pw.BoxConstraints(
                    maxWidth: double.infinity,
                    maxHeight: is58mm ? 40 : (isWide ? 65 : 50),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Royal',
                        style: pw.TextStyle(
                          fontSize: is58mm ? 16 : (isWide ? 24 : 20),
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        'garden',
                        style: pw.TextStyle(
                          fontSize: is58mm ? 14 : (isWide ? 20 : 17),
                          fontWeight: pw.FontWeight.normal,
                          letterSpacing: 1.5,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      if (!is58mm) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'TANGERANG',
                          style: pw.TextStyle(
                            fontSize: isWide ? 8 : 7,
                            fontWeight: pw.FontWeight.normal,
                            letterSpacing: 1.0,
                            color: PdfColors.grey700,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
      pw.SizedBox(height: is58mm ? 6 : 10),
    ];
  }

  // Invoice Information Section optimized for 58mm
  static List<pw.Widget> _buildInvoiceInfo(Sale sale, ThermalSize thermalSize) {
    final bool isWide = thermalSize == ThermalSize.mm80;
    final bool is58mm = thermalSize == ThermalSize.mm58;

    return [
      // Invoice Title
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.symmetric(
            vertical: is58mm ? 4 : 6, horizontal: is58mm ? 8 : 12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          'INVOICE',
          style: pw.TextStyle(
            fontSize: is58mm ? 10 : (isWide ? 14 : 12),
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
      pw.SizedBox(height: is58mm ? 4 : 8),

      // Invoice Details - always use column layout for 58mm
      pw.Container(
        width: double.infinity,
        child: is58mm || !isWide
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('ID:', sale.id, thermalSize),
                  _buildInfoRow(
                      'Date:',
                      DateFormat('dd/MM/yyyy HH:mm')
                          .format(sale.date.toLocal()),
                      thermalSize),
                  if (sale.customerName.isNotEmpty)
                    _buildInfoRow(
                        'Customer:',
                        _truncateText(sale.customerName, is58mm ? 15 : 20),
                        thermalSize),
                  if (sale.customerPhone.isNotEmpty)
                    _buildInfoRow('Phone:', sale.customerPhone, thermalSize),
                  _buildInfoRow(
                      'Payment:', sale.payment.name.toUpperCase(), thermalSize),
                ],
              )
            : pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Invoice ID:', sale.id, thermalSize),
                        _buildInfoRow(
                            'Date:',
                            DateFormat('dd/MM/yyyy')
                                .format(sale.date.toLocal()),
                            thermalSize),
                        _buildInfoRow(
                            'Time:',
                            DateFormat('HH:mm:ss').format(sale.date.toLocal()),
                            thermalSize),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (sale.customerName.isNotEmpty)
                          _buildInfoRow(
                              'Customer:', sale.customerName, thermalSize),
                        if (sale.customerPhone.isNotEmpty)
                          _buildInfoRow(
                              'Phone:', sale.customerPhone, thermalSize),
                        _buildInfoRow('Payment:',
                            sale.payment.name.toUpperCase(), thermalSize),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      pw.SizedBox(height: is58mm ? 6 : 10),
    ];
  }

  // Items Section optimized for long item names and 58mm
  static List<pw.Widget> _buildItemsSection(
      Sale sale, ThermalSize thermalSize) {
    final bool isWide = thermalSize == ThermalSize.mm80;
    final bool is58mm = thermalSize == ThermalSize.mm58;
    final double fontSize = is58mm ? 7 : (isWide ? 9 : 8);
    final double headerFontSize = is58mm ? 8 : (isWide ? 10 : 9);

    return [
      // Items Header
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey800,
          borderRadius: pw.BorderRadius.circular(2),
        ),
        padding: pw.EdgeInsets.symmetric(
            vertical: is58mm ? 3 : 4, horizontal: is58mm ? 4 : 6),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: is58mm ? 3 : (isWide ? 6 : 4),
              child: pw.Text(
                'ITEM',
                style: pw.TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.Container(
              width: is58mm ? 20 : (isWide ? 30 : 25),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'QTY',
                style: pw.TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Container(
              width: is58mm ? 30 : (isWide ? 40 : 35),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'RATE',
                style: pw.TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Container(
              width: is58mm ? 35 : (isWide ? 45 : 40),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'AMT',
                style: pw.TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ),

      // Items List
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Column(
          children: [
            ...sale.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildItemRow(item, index, thermalSize);
            }).toList(),
          ],
        ),
      ),
      pw.SizedBox(height: is58mm ? 4 : 8),
    ];
  }

  // Individual Item Row optimized for 58mm and long names
  static pw.Widget _buildItemRow(
      SaleItem item, int index, ThermalSize thermalSize) {
    final bool isWide = thermalSize == ThermalSize.mm80;
    final bool is58mm = thermalSize == ThermalSize.mm58;
    final product = Hive.box<Product>(Boxes.products).get(item.productId);
    final productName = product?.name ?? 'Unknown Product';
    final qty = item.qty.toStringAsFixed(product?.unit == UnitType.kg ? 1 : 0);
    final unitLabel =
        item.unitLabel.isNotEmpty ? item.unitLabel : (product?.unit.name ?? '');

    // Force 15 character limit per line
    String firstLine = '';
    String secondLine = '';

    if (productName.length <= 15) {
      firstLine = productName;
    } else {
      firstLine = productName.substring(0, 15);
      if (productName.length > 30) {
        secondLine = productName.substring(15, 30) + '..';
      } else {
        secondLine = productName.substring(15);
      }
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: index % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.3),
        ),
      ),
      padding: pw.EdgeInsets.symmetric(
          vertical: secondLine.isNotEmpty ? (is58mm ? 4 : 8) : (is58mm ? 3 : 6),
          horizontal: is58mm ? 4 : 6),
      child: is58mm
          ?
          // 58mm: Two-line layout for better readability
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Product name line
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        firstLine +
                            (secondLine.isNotEmpty ? '\n' + secondLine : ''),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        maxLines: 2,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 1),
                // Quantity, rate, amount line
                pw.Row(
                  children: [
                    if (unitLabel.isNotEmpty) ...[
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          unitLabel,
                          style: pw.TextStyle(
                            fontSize: 6,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                    ] else
                      pw.Expanded(flex: 2, child: pw.Container()),
                    pw.Container(
                      width: 20,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        qty,
                        style: pw.TextStyle(fontSize: 7),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      width: 30,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '${item.sellingPrice.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 7),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Container(
                      width: 35,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '${item.subtotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            )
          :
          // 80mm: Single-line layout
          pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: isWide ? 6 : 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        firstLine,
                        style: pw.TextStyle(
                          fontSize: isWide ? 9 : 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (secondLine.isNotEmpty)
                        pw.Text(
                          secondLine,
                          style: pw.TextStyle(
                            fontSize: isWide ? 9 : 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (unitLabel.isNotEmpty) ...[
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'Unit: $unitLabel',
                          style: pw.TextStyle(
                            fontSize: isWide ? 7 : 6,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Container(
                  width: isWide ? 30 : 25,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    qty,
                    style: pw.TextStyle(fontSize: isWide ? 9 : 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  width: isWide ? 40 : 35,
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Rs.${item.sellingPrice.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: isWide ? 9 : 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: isWide ? 45 : 40,
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Rs.${item.subtotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: isWide ? 9 : 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
    );
  }

  // Totals Section optimized for 58mm
  static List<pw.Widget> _buildTotalsSection(
      Sale sale, ThermalSize thermalSize, bool includeGST) {
    final bool isWide = thermalSize == ThermalSize.mm80;
    final bool is58mm = thermalSize == ThermalSize.mm58;
    final subtotal = sale.items.fold(0.0, (a, b) => a + b.subtotal);
    final gstAmount = includeGST && sale.gstEnabled ? sale.cgstAmount + sale.sgstAmount + sale.igstAmount : 0.0;

    // Font sizes based on printer width
    final double normalFontSize = is58mm ? 8 : (isWide ? 10 : 9);
    final double totalFontSize = is58mm ? 9 : (isWide ? 12 : 10);

    return [
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        padding: pw.EdgeInsets.all(is58mm ? 4 : 8),
        child: pw.Column(
          children: [
            // Subtotal
            _buildCompactTotalRow(
                'Subtotal:', subtotal.toStringAsFixed(2), normalFontSize),

            if (sale.discount > 0) ...[
              pw.SizedBox(height: is58mm ? 1 : 2),
              _buildCompactTotalRow('Discount:',
                  '-${sale.discount.toStringAsFixed(2)}', normalFontSize,
                  valueColor: PdfColors.red),
            ],

            if (includeGST && sale.gstEnabled) ...[
              pw.SizedBox(height: is58mm ? 1 : 2),
              _buildCompactTotalRow('Taxable value:', sale.taxableAmount.toStringAsFixed(2), normalFontSize),
              if (sale.interstateSale)
                _buildCompactTotalRow('IGST:', sale.igstAmount.toStringAsFixed(2), normalFontSize)
              else ...[
                _buildCompactTotalRow('CGST:', sale.cgstAmount.toStringAsFixed(2), normalFontSize),
                _buildCompactTotalRow('SGST:', sale.sgstAmount.toStringAsFixed(2), normalFontSize),
              ],
              _buildCompactTotalRow('Total GST:', gstAmount.toStringAsFixed(2), normalFontSize),
            ],

            pw.SizedBox(height: is58mm ? 2 : 4),
            pw.Container(
              width: double.infinity,
              height: 0.5,
              color: PdfColors.grey600,
            ),
            pw.SizedBox(height: is58mm ? 2 : 4),

            // Total amount - optimized for small width
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  is58mm ? 'TOTAL:' : 'TOTAL AMOUNT:',
                  style: pw.TextStyle(
                    fontSize: totalFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.Text(
                  'Rs.${sale.totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: totalFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),

            // Amount in words - only for wider printers
            if (isWide) ...[
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                child: pw.Text(
                  'Amount in Words: ${_convertToWords(sale.totalAmount.toInt())} Rupees Only',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ],
        ),
      ),
      pw.SizedBox(height: is58mm ? 6 : 10),
    ];
  }

  // Footer Section optimized for 58mm
  static List<pw.Widget> _buildFooter(ThermalSize thermalSize) {
    final bool isWide = thermalSize == ThermalSize.mm80;
    final bool is58mm = thermalSize == ThermalSize.mm58;

    return [
      // Thank you message
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.symmetric(vertical: is58mm ? 4 : 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              is58mm ? 'THANK YOU!' : 'THANK YOU FOR YOUR BUSINESS!',
              style: pw.TextStyle(
                fontSize: is58mm ? 8 : (isWide ? 10 : 9),
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (isWide) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'Visit us again for fresh flowers and plants',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ],
        ),
      ),

      pw.SizedBox(height: is58mm ? 4 : 8),

      // Timestamp
      pw.Text(
        'Printed: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now().toLocal())}',
        style: pw.TextStyle(
            fontSize: is58mm ? 5 : (isWide ? 7 : 6), color: PdfColors.grey600),
        textAlign: pw.TextAlign.center,
      ),

      pw.SizedBox(height: is58mm ? 6 : 10),
    ];
  }

  // Helper Methods
  static pw.Widget _buildInfoRow(
      String label, String value, ThermalSize thermalSize) {
    final bool isWide = thermalSize == ThermalSize.mm80;
    final bool is58mm = thermalSize == ThermalSize.mm58;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: is58mm ? 40 : (isWide ? 70 : 50),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: is58mm ? 7 : (isWide ? 9 : 8),
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: is58mm ? 7 : (isWide ? 9 : 8),
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact total row helper
  static pw.Widget _buildCompactTotalRow(
      String label, String value, double fontSize,
      {PdfColor? valueColor}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(
          'Rs.$value',
          style: pw.TextStyle(
            fontSize: fontSize,
            color: valueColor ?? PdfColors.black,
            fontWeight: pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // Text truncation helper
  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Simple number to words converter (for amounts)
  static String _convertToWords(int amount) {
    if (amount == 0) return 'Zero';
    if (amount < 0) return 'Minus ${_convertToWords(-amount)}';

    final parts = <String>[];
    if (amount >= 10000000) {
      parts.add('${_convertToWords(amount ~/ 10000000)} Crore');
      amount %= 10000000;
    }
    if (amount >= 100000) {
      parts.add('${_convertToWords(amount ~/ 100000)} Lakh');
      amount %= 100000;
    }
    if (amount >= 1000) {
      parts.add('${_convertToWords(amount ~/ 1000)} Thousand');
      amount %= 1000;
    }
    if (amount >= 100) {
      parts.add('${_convertToWords(amount ~/ 100)} Hundred');
      amount %= 100;
    }
    if (amount > 0) parts.add(_convertUnderHundred(amount));
    return parts.join(' ');
  }

  static String _convertUnderHundred(int amount) {
    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
    const teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    if (amount < 10) return ones[amount];
    if (amount < 20) return teens[amount - 10];
    final ten = tens[amount ~/ 10];
    final one = amount % 10;
    return one == 0 ? ten : '$ten ${ones[one]}';
  }
}

// Enum for thermal printer sizes
enum ThermalSize {
  mm58,
  mm80,
}

// Usage function
Future<void> generateInvoicePdf(Sale sale) async {
  await PdfService.generateInvoice(
    sale,
    thermalSize: ThermalSize.mm80,
    includeHeader: true,
    includeFooter: true,
    includeGST: true,
  );
}
