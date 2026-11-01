import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/responsive_page.dart';

class GstSettingsScreen extends StatefulWidget {
  const GstSettingsScreen({super.key});

  @override
  State<GstSettingsScreen> createState() => _GstSettingsScreenState();
}

class _GstSettingsScreenState extends State<GstSettingsScreen> {
  late final Box<dynamic> _settings;
  late bool _gstEnabled;
  late bool _gstInclusive;
  late bool _defaultInterstate;
  late String _registrationType;
  late String _stateCode;
  late final TextEditingController _defaultRate;
  bool _saving = false;

  static const _states = <String, String>{
    '01': 'Jammu and Kashmir',
    '02': 'Himachal Pradesh',
    '03': 'Punjab',
    '04': 'Chandigarh',
    '05': 'Uttarakhand',
    '06': 'Haryana',
    '07': 'Delhi',
    '08': 'Rajasthan',
    '09': 'Uttar Pradesh',
    '10': 'Bihar',
    '11': 'Sikkim',
    '12': 'Arunachal Pradesh',
    '13': 'Nagaland',
    '14': 'Manipur',
    '15': 'Mizoram',
    '16': 'Tripura',
    '17': 'Meghalaya',
    '18': 'Assam',
    '19': 'West Bengal',
    '20': 'Jharkhand',
    '21': 'Odisha',
    '22': 'Chhattisgarh',
    '23': 'Madhya Pradesh',
    '24': 'Gujarat',
    '26': 'Dadra and Nagar Haveli and Daman and Diu',
    '27': 'Maharashtra',
    '28': 'Andhra Pradesh (old code)',
    '29': 'Karnataka',
    '30': 'Goa',
    '31': 'Lakshadweep',
    '32': 'Kerala',
    '33': 'Tamil Nadu',
    '34': 'Puducherry',
    '35': 'Andaman and Nicobar Islands',
    '36': 'Telangana',
    '37': 'Andhra Pradesh',
    '38': 'Ladakh',
  };

  @override
  void initState() {
    super.initState();
    _settings = Hive.box<dynamic>('app_settings');
    _registrationType = _settings
        .get('gst_registration_type', defaultValue: 'regular')
        .toString();
    if (!const ['regular', 'composition', 'unregistered']
        .contains(_registrationType)) {
      _registrationType = 'regular';
    }
    _gstEnabled = _settings.get('gst_enabled', defaultValue: false) as bool;
    _gstInclusive =
        _settings.get('gst_price_inclusive', defaultValue: false) as bool;
    _defaultInterstate = _settings.get('gst_default_interstate_sale',
        defaultValue: false) as bool;
    _stateCode =
        _settings.get('business_state_code', defaultValue: '32').toString();
    if (!_states.containsKey(_stateCode)) _stateCode = '32';
    if (_registrationType != 'regular') _gstEnabled = false;
    _defaultRate = TextEditingController(
      text: (_settings.get('gst_rate', defaultValue: 0.0) as num).toString(),
    );
  }

  @override
  void dispose() {
    _defaultRate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rate = double.tryParse(_defaultRate.text.trim());
    if (rate == null || rate < 0 || rate > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a valid default GST rate from 0 to 100.')),
      );
      return;
    }
    if (_registrationType != 'regular' && _gstEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'GST collection through tax invoices is available only for regular registration.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _settings.putAll({
        'gst_registration_type': _registrationType,
        'gst_enabled': _registrationType == 'regular' && _gstEnabled,
        'gst_price_inclusive': _gstInclusive,
        'gst_rate': rate,
        'business_state_code': _stateCode,
        'gst_default_interstate_sale': _defaultInterstate,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'GST settings saved. Review these settings with your accountant before issuing invoices.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final isRegular = _registrationType == 'regular';
    return Scaffold(
      appBar: AppBar(title: const Text('GST Settings')),
      body: ResponsivePage(
        maxWidth: 850,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.receipt_long_outlined),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text('GST configuration',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'These settings are separate from Appearance & Personalisation. Product-specific GST rates and HSN codes remain editable in Product Management.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: _registrationType,
                      decoration: _decoration(
                          'GST registration type', Icons.business_outlined),
                      items: const [
                        DropdownMenuItem(
                            value: 'regular',
                            child: Text('Regular GST taxpayer')),
                        DropdownMenuItem(
                            value: 'composition',
                            child: Text('Composition scheme')),
                        DropdownMenuItem(
                            value: 'unregistered',
                            child: Text('Not GST registered')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _registrationType = value;
                          if (value != 'regular') _gstEnabled = false;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _stateCode,
                      decoration: _decoration(
                          'Business state / UT', Icons.location_on_outlined),
                      items: _states.entries
                          .map((entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text('${entry.key} — ${entry.value}'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _stateCode = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seller GSTIN is configured under App & Invoice Settings. Check that its state code matches the selected state.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable GST calculations in billing'),
                    subtitle: Text(isRegular
                        ? 'Allows the cashier to apply GST to a bill.'
                        : 'Disabled for composition and unregistered profiles. Do not use this app to collect GST under these profiles.'),
                    value: _gstEnabled && isRegular,
                    onChanged: isRegular
                        ? (value) => setState(() => _gstEnabled = value)
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title:
                        const Text('Catalogue prices include GST by default'),
                    subtitle: const Text(
                        'Cashiers can still change this on an individual bill.'),
                    value: _gstInclusive,
                    onChanged: (value) => setState(() => _gstInclusive = value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Default to interstate sale (IGST)'),
                    subtitle: const Text(
                        'Sets the initial billing choice; verify the place of supply for each transaction.'),
                    value: _defaultInterstate,
                    onChanged: (value) =>
                        setState(() => _defaultInterstate = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tax defaults',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _defaultRate,
                      enabled: _gstEnabled && isRegular,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          _decoration('Fallback GST rate (%)', Icons.percent),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Used only when a product has no individual GST rate. Confirm the correct rate and HSN classification for each product; GST rates are not interchangeable across goods.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Important: Floral Bill is a billing and record-keeping tool, not a GST compliance certification or filing service. Composition taxpayers must not collect GST separately. Verify invoice rules, HSN/SAC, rates, place of supply, e-invoicing/e-way bill applicability and return reporting with a qualified tax professional.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save GST settings'),
            ),
          ],
        ),
      ),
    );
  }
}
