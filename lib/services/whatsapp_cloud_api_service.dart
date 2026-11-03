import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WhatsappCloudApiService {
  Future<String> sendInvoice({
    required String backendUrl, required String apiKey, required String phone,
    required String invoiceId, required Uint8List pdfBytes, required String filename,
    String? caption,
  }) async {
    final base = backendUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty || apiKey.trim().isEmpty) throw Exception('Configure the WhatsApp backend URL and API key in Invoice Settings.');
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty || (!kDebugMode && uri.scheme != 'https')) throw Exception('Enter a valid HTTPS WhatsApp backend URL.');
    if (phone.trim().isEmpty) throw Exception('Customer phone number is missing.');
    final request = http.MultipartRequest('POST', Uri.parse('$base/api/whatsapp/send-invoice'))
      ..headers['x-billit-api-key'] = apiKey.trim()
      ..fields['phone'] = phone.trim()
      ..fields['invoiceId'] = invoiceId
      ..fields['caption'] = caption ?? 'Thank you for your purchase. Invoice $invoiceId is attached.'
      ..files.add(http.MultipartFile.fromBytes('invoice', pdfBytes, filename: filename));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic> payload = {};
    try { payload = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(payload['error']?.toString() ?? 'WhatsApp send failed (' + response.statusCode.toString() + ').');
    return payload['messageId']?.toString() ?? 'accepted';
  }
}