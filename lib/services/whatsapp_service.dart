import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import 'pdf_service.dart';

/// On an explicit WhatsApp action, create and save the invoice PDF, then
/// open the customer's WhatsApp chat with the configured message prefilled.
class WhatsAppService {
  WhatsAppService._();

  static const String defaultTemplate =
      'Hi {name}, thank you for purchasing with {shop}! Here is your invoice {invoice} for {total}.';

  static Box<dynamic> get _settings => Hive.box<dynamic>('app_settings');

  static String get template {
    final value = _settings.get('whatsapp_message_template', defaultValue: '').toString();
    return value.trim().isEmpty ? defaultTemplate : value;
  }

  static String get countryCode {
    final value = _settings.get('whatsapp_country_code', defaultValue: '91').toString();
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? '91' : digits;
  }

  static String get _shopName {
    final name = _settings.get('business_name', defaultValue: '').toString().trim();
    if (name.isNotEmpty) return name;
    return _settings.get('app_name', defaultValue: 'Billit').toString();
  }

  static String? normalizePhone(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final hasPlus = value.startsWith('+');
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (!hasPlus) {
      digits = digits.replaceFirst(RegExp(r'^0+'), '');
      if (digits.length == 10) digits = '$countryCode$digits';
    }
    return digits.length >= 8 && digits.length <= 15 ? digits : null;
  }

  static String renderTemplate(
    String messageTemplate, {
    required String name,
    required String shop,
    required String invoice,
    required String total,
    required String date,
  }) {
    return messageTemplate
        .replaceAll('{name}', name.trim().isEmpty ? 'there' : name.trim())
        .replaceAll('{shop}', shop)
        .replaceAll('{invoice}', invoice)
        .replaceAll('{total}', total)
        .replaceAll('{date}', date);
  }

  static String buildMessage(Sale sale) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return renderTemplate(
      template,
      name: sale.customerName,
      shop: _shopName,
      invoice: sale.id,
      total: money.format(sale.totalAmount),
      date: DateFormat('d MMM yyyy').format(sale.date),
    );
  }

  static Uri chatUri(String phoneDigits, String message) => Uri.https(
        'wa.me',
        '/$phoneDigits',
        {'text': message},
      );

  /// Called only by an explicit WhatsApp icon tap. Sale completion never
  /// generates or downloads an invoice PDF.
  static Future<void> sendInvoice(BuildContext context, Sale sale) async {
    final messenger = ScaffoldMessenger.of(context);
    void showMessage(String message) {
      messenger.showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
    }

    final phone = normalizePhone(sale.customerPhone);
    if (phone == null) {
      showMessage('Add a valid customer phone number with country code before sharing.');
      return;
    }

    try {
      final pdf = await PdfService.buildInvoicePdf(sale);
      if (!context.mounted) return;

      final filename = 'Invoice_${sale.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
        await FileSaver.instance.saveFile(
          name: filename,
          bytes: pdf.bytes,
          fileExtension: 'pdf',
          mimeType: MimeType.pdf,
        );
      } else {
        await FileSaver.instance.saveToDownloads(
          name: filename,
          bytes: pdf.bytes,
          fileExtension: 'pdf',
          mimeType: MimeType.pdf,
          subfolder: 'Billit Invoices',
        );
      }

      if (!context.mounted) return;
      final opened = await launchUrl(
        chatUri(phone, buildMessage(sale)),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        showMessage('Invoice saved, but WhatsApp could not be opened.');
        return;
      }
      showMessage('Invoice saved in Downloads / Billit Invoices. Attach it in WhatsApp using the paperclip.');
    } catch (error) {
      if (context.mounted) {
        showMessage('Could not prepare the WhatsApp invoice: $error');
      }
    }
  }
}
