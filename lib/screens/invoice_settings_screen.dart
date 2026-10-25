import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Box<dynamic> _settings;
  late final TextEditingController _appName;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _gstin;
  late final TextEditingController _rate;
  late final TextEditingController _invoicePrefix;
  late final TextEditingController _nextInvoiceNumber;
  late final TextEditingController _upiId;
  late final TextEditingController _upiPayeeName;
  late final TextEditingController _upiNotePrefix;
  late String _appTheme;

  Uint8List? _appLogoBytes;
  Uint8List? _invoiceLogoBytes;
  Uint8List? _paymentQrBytes;
  bool _clearAppLogo = false;
  bool _clearInvoiceLogo = false;
  bool _clearPaymentQr = false;
  late bool _gstEnabled;
  late bool _gstInclusive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = Hive.box<dynamic>('app_settings');
    _appName = TextEditingController(text: _settings.get('app_name', defaultValue: 'Floral Bill').toString());
    _name = TextEditingController(text: _settings.get('business_name', defaultValue: '').toString());
    _address = TextEditingController(text: _settings.get('business_address', defaultValue: '').toString());
    _phone = TextEditingController(text: _settings.get('business_phone', defaultValue: '').toString());
    _email = TextEditingController(text: _settings.get('business_email', defaultValue: '').toString());
    _gstin = TextEditingController(text: _settings.get('business_gstin', defaultValue: '').toString());
    _rate = TextEditingController(text: (_settings.get('gst_rate', defaultValue: 0.0) as num).toString());
    _gstEnabled = _settings.get('gst_enabled', defaultValue: false) as bool;
    _gstInclusive = _settings.get('gst_price_inclusive', defaultValue: false) as bool;
    _invoicePrefix = TextEditingController(text: _settings.get('invoice_prefix', defaultValue: 'INV').toString());
    _nextInvoiceNumber = TextEditingController(text: (_settings.get('next_invoice_number', defaultValue: 1) as num).toInt().toString());
    _upiId = TextEditingController(text: _settings.get('upi_id', defaultValue: '').toString());
    _upiPayeeName = TextEditingController(text: _settings.get('upi_payee_name', defaultValue: '').toString());
    _upiNotePrefix = TextEditingController(text: _settings.get('upi_note_prefix', defaultValue: 'Invoice').toString());
    _appTheme = _settings.get('app_theme', defaultValue: 'green').toString();
    if (!const ['green', 'blue', 'purple', 'teal', 'amber', 'rose', 'dark'].contains(_appTheme)) _appTheme = 'green';
    _appLogoBytes = _decodeImage('app_logo_base64');
    _invoiceLogoBytes = _decodeImage('business_logo_base64');
    _paymentQrBytes = _decodeImage('payment_qr_base64');
  }

  Uint8List? _decodeImage(String key) {
    final saved = _settings.get(key) as String?;
    if (saved == null || saved.isEmpty) return null;
    try { return base64Decode(saved); } catch (_) { return null; }
  }

  @override
  void dispose() {
    _appName.dispose(); _name.dispose(); _address.dispose(); _phone.dispose();
    _email.dispose(); _gstin.dispose(); _rate.dispose();
    _invoicePrefix.dispose(); _nextInvoiceNumber.dispose();
    _upiId.dispose(); _upiPayeeName.dispose(); _upiNotePrefix.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String key) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    setState(() {
      if (key == 'app') {
        _appLogoBytes = bytes;
        _clearAppLogo = false;
      } else if (key == 'invoice') {
        _invoiceLogoBytes = bytes;
        _clearInvoiceLogo = false;
      } else {
        _paymentQrBytes = bytes;
        _clearPaymentQr = false;
      }
    });
  }

  void _removeImage(String key) {
    setState(() {
      if (key == 'app') {
        _appLogoBytes = null;
        _clearAppLogo = true;
      } else if (key == 'invoice') {
        _invoiceLogoBytes = null;
        _clearInvoiceLogo = true;
      } else {
        _paymentQrBytes = null;
        _clearPaymentQr = true;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final nextInvoiceNumber = int.tryParse(_nextInvoiceNumber.text.trim());
    if (nextInvoiceNumber == null || nextInvoiceNumber < 1) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Next invoice number must be a positive integer.')),
      );
      return;
    }

    await _settings.putAll({
      'app_name': _appName.text.trim(),
      'app_theme': _appTheme,
      'upi_id': _upiId.text.trim(),
      'upi_payee_name': _upiPayeeName.text.trim(),
      'upi_note_prefix': _upiNotePrefix.text.trim().isEmpty ? 'Invoice' : _upiNotePrefix.text.trim(),
      'business_name': _name.text.trim(),
      'business_address': _address.text.trim(),
      'business_phone': _phone.text.trim(),
      'business_email': _email.text.trim(),
      'business_gstin': _gstin.text.trim().toUpperCase(),
      'gst_enabled': _gstEnabled,
      'gst_rate': double.parse(_rate.text.trim()),
      'gst_price_inclusive': _gstInclusive,
      'invoice_prefix': _invoicePrefix.text.trim().isEmpty ? 'INV' : _invoicePrefix.text.trim().toUpperCase(),
      'next_invoice_number': nextInvoiceNumber,
    });
    await _saveImage('app_logo_base64', _appLogoBytes, _clearAppLogo);
    await _saveImage('business_logo_base64', _invoiceLogoBytes, _clearInvoiceLogo);
    await _saveImage('payment_qr_base64', _paymentQrBytes, _clearPaymentQr);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App, theme, UPI, invoice and GST settings saved')),
    );
  }

  Future<void> _saveImage(String key, Uint8List? bytes, bool shouldClear) async {
    if (bytes != null) {
      await _settings.put(key, base64Encode(bytes));
    } else if (shouldClear) {
      if (key == 'payment_qr_base64') {
        await _settings.put(key, '');
      } else {
        await _settings.delete(key);
      }
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: const OutlineInputBorder(),
  );

  Widget _imageSetting({
    required String title,
    required String description,
    required String key,
    required Uint8List? bytes,
    required IconData placeholderIcon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 84,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: bytes == null
                      ? Icon(placeholderIcon, size: 32)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(bytes, width: 82, height: 70, fit: BoxFit.contain),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(bytes == null ? 'No image selected' : 'Image selected')),
                IconButton(tooltip: 'Choose image', onPressed: () => _pickImage(key), icon: const Icon(Icons.upload_file)),
                IconButton(tooltip: 'Remove image', onPressed: bytes == null ? null : () => _removeImage(key), icon: const Icon(Icons.delete_outline)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App & Invoice Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Application', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _appName,
              decoration: _decoration('App name', Icons.apps),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter an app name' : null,
            ),
            const SizedBox(height: 8),
            const Text('This name is used inside the app and as its application title. Changing the Android launcher label requires a new app build.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            _imageSetting(
              title: 'Application logo',
              description: 'Logo shown in the app UI. This is separate from the invoice logo.',
              key: 'app',
              bytes: _appLogoBytes,
              placeholderIcon: Icons.apps,
            ),
            const SizedBox(height: 20),
            const Text('App theme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Choose the accent colour used throughout the app. The dark theme uses a dark colour scheme.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _appTheme,
              decoration: _decoration('Colour theme', Icons.palette_outlined),
              items: const [
                DropdownMenuItem(value: 'green', child: Text('Garden Green')),
                DropdownMenuItem(value: 'blue', child: Text('Classic Blue')),
                DropdownMenuItem(value: 'purple', child: Text('Royal Purple')),
                DropdownMenuItem(value: 'teal', child: Text('Calm Teal')),
                DropdownMenuItem(value: 'amber', child: Text('Warm Amber')),
                DropdownMenuItem(value: 'rose', child: Text('Rose')),
                DropdownMenuItem(value: 'dark', child: Text('Dark Blue-Grey')),
              ],
              onChanged: (value) { if (value != null) setState(() => _appTheme = value); },
            ),
            const SizedBox(height: 20),
            const Text('Business details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(controller: _name, decoration: _decoration('Business / shop name', Icons.store), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter business name' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _address, maxLines: 2, decoration: _decoration('Business address', Icons.location_on_outlined)),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: _decoration('Phone number', Icons.phone_outlined)),
            const SizedBox(height: 12),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: _decoration('Email (optional)', Icons.email_outlined)),
            const SizedBox(height: 12),
            TextFormField(controller: _gstin, textCapitalization: TextCapitalization.characters, decoration: _decoration('Business GSTIN (optional)', Icons.verified_outlined)),
            const SizedBox(height: 8),
            _imageSetting(
              title: 'Invoice / bill logo',
              description: 'Printed at the top of your normal and GST PDF invoices.',
              key: 'invoice',
              bytes: _invoiceLogoBytes,
              placeholderIcon: Icons.receipt_long,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 20),
            const Text('Dynamic UPI payment QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Configure your UPI details once. Each new bill will get a QR containing that invoice ID and the exact bill total in INR. A compatible UPI app is required to pay.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _upiId,
              decoration: _decoration('UPI ID / VPA (e.g. shop@bank)', Icons.account_balance_wallet_outlined),
              validator: (value) {
                final upi = value?.trim() ?? '';
                if (upi.isNotEmpty && (!upi.contains('@') || upi.contains(' '))) return 'Enter a valid UPI ID or leave it blank';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _upiPayeeName,
              decoration: _decoration('Payee / business name', Icons.storefront_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _upiNotePrefix,
              decoration: _decoration('Payment note prefix', Icons.notes_outlined),
              maxLength: 30,
            ),
            const SizedBox(height: 8),
            const Text('The QR is generated locally from the saved UPI ID and bill total. No payment is processed by Floral Bill, and payment completion must be verified in your UPI app/bank.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            _imageSetting(
              title: 'Static payment QR fallback (optional)',
              description: 'Used only when no UPI ID is configured. A dynamic invoice QR takes priority when the UPI ID is set.',
              key: 'qr',
              bytes: _paymentQrBytes,
              placeholderIcon: Icons.qr_code_2,
            ),
            const SizedBox(height: 20),
            const Text('Invoice numbering', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(controller: _invoicePrefix, textCapitalization: TextCapitalization.characters, decoration: _decoration('Invoice number prefix', Icons.tag)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nextInvoiceNumber,
              keyboardType: TextInputType.number,
              decoration: _decoration('Next invoice number', Icons.format_list_numbered),
              validator: (value) {
                final number = int.tryParse(value?.trim() ?? '');
                if (number == null || number < 1) return 'Enter a positive integer';
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text('GST settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable GST for billing'),
              subtitle: const Text('When enabled, GST can be applied to an individual bill.'),
              value: _gstEnabled,
              onChanged: (value) => setState(() => _gstEnabled = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Product prices include GST by default'),
              subtitle: const Text('Enable if catalogue prices are tax-inclusive. This can be overridden for each bill.'),
              value: _gstInclusive,
              onChanged: _gstEnabled ? (value) => setState(() => _gstInclusive = value) : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _rate,
              enabled: _gstEnabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _decoration('Default GST rate (%)', Icons.percent),
              validator: (value) {
                final rate = double.tryParse(value?.trim() ?? '');
                if (rate == null || rate < 0 || rate > 100) return 'Enter a rate from 0 to 100';
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text('Set rates according to the goods sold and your tax treatment. A single default rate is applied only when you enable GST on a bill; it is not a substitute for item-specific GST classification or tax advice.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
  }
}
