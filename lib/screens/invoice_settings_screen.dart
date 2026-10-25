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
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _gstin;
  late final TextEditingController _rate;
  late bool _gstEnabled;
  late bool _gstInclusive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = Hive.box<dynamic>('app_settings');
    _name = TextEditingController(text: _settings.get('business_name', defaultValue: ''));
    _address = TextEditingController(text: _settings.get('business_address', defaultValue: ''));
    _phone = TextEditingController(text: _settings.get('business_phone', defaultValue: ''));
    _email = TextEditingController(text: _settings.get('business_email', defaultValue: ''));
    _gstin = TextEditingController(text: _settings.get('business_gstin', defaultValue: ''));
    _rate = TextEditingController(text: (_settings.get('gst_rate', defaultValue: 0.0) as num).toString());
    _gstEnabled = _settings.get('gst_enabled', defaultValue: false) as bool;
    _gstInclusive = _settings.get('gst_price_inclusive', defaultValue: false) as bool;
  }

  @override
  void dispose() {
    _name.dispose(); _address.dispose(); _phone.dispose();
    _email.dispose(); _gstin.dispose(); _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final rate = double.parse(_rate.text.trim());
    await _settings.putAll({
      'business_name': _name.text.trim(),
      'business_address': _address.text.trim(),
      'business_phone': _phone.text.trim(),
      'business_email': _email.text.trim(),
      'business_gstin': _gstin.text.trim().toUpperCase(),
      'gst_enabled': _gstEnabled,
      'gst_rate': rate,
      'gst_price_inclusive': _gstInclusive,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice and GST settings saved')),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice & GST Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
