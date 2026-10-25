import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  static const _palettes = <String, Color>{
    'green': Color(0xFF25855A),
    'blue': Color(0xFF2864C5),
    'purple': Color(0xFF7651B5),
    'amber': Color(0xFFB77916),
    'teal': Color(0xFF168A8A),
    'rose': Color(0xFFB83280),
    'indigo': Color(0xFF4F46B8),
    'slate': Color(0xFF475569),
    'coral': Color(0xFFD45D45),
    'ocean': Color(0xFF087EAA),
  };

  static const _paletteNames = <String, String>{
    'green': 'Garden Green',
    'blue': 'Classic Blue',
    'purple': 'Royal Purple',
    'amber': 'Warm Amber',
    'teal': 'Calm Teal',
    'rose': 'Rose',
    'indigo': 'Indigo',
    'slate': 'Slate',
    'coral': 'Coral',
    'ocean': 'Ocean',
  };

  Future<void> _save(String key, dynamic value) async {
    await Hive.box<dynamic>('app_settings').put(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Hive.box<dynamic>('app_settings');
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: settings.listenable(),
      builder: (context, box, _) {
        final selectedTheme = box.get('app_theme', defaultValue: 'green').toString();
        final themeMode = box.get('theme_mode', defaultValue: 'system').toString();
        final density = box.get('ui_density', defaultValue: 'comfortable').toString();
        final textScale = (box.get('text_scale', defaultValue: 1.0) as num).toDouble();
        final radius = (box.get('corner_radius', defaultValue: 16.0) as num).toDouble();
        final lowStockThreshold = (box.get('low_stock_threshold', defaultValue: 10) as num).toDouble();
        final color = _palettes[selectedTheme] ?? _palettes['green']!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Appearance & Personalisation'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.72)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(radius + 4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.palette_outlined, color: Colors.white, size: 30),
                        const SizedBox(height: 12),
                        const Text(
                          'Make Floral Bill yours',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_paletteNames[selectedTheme] ?? 'Garden Green'} · ${themeMode[0].toUpperCase()}${themeMode.substring(1)} mode',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(context, 'Colour theme', 'Choose an accent colour for navigation and controls.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _palettes.entries.map((entry) {
                          final selected = entry.key == selectedTheme;
                          return Tooltip(
                            message: _paletteNames[entry.key]!,
                            child: InkWell(
                              onTap: () => _save('app_theme', entry.key),
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: entry.value,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                                    width: selected ? 3 : 0,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(Icons.check, color: Colors.white, size: 21)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Light and dark mode', 'Follow your device or set a mode manually.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'system', icon: Icon(Icons.settings_brightness), label: Text('System')),
                          ButtonSegment(value: 'light', icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                          ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (values) => _save('theme_mode', values.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Display density', 'Choose a more compact view or extra breathing room.'),
                  Card(
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'comfortable',
                          groupValue: density,
                          title: const Text('Comfortable'),
                          subtitle: const Text('More spacing; easier to tap on phones.'),
                          secondary: const Icon(Icons.space_dashboard_outlined),
                          onChanged: (value) { if (value != null) _save('ui_density', value); },
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          value: 'compact',
                          groupValue: density,
                          title: const Text('Compact'),
                          subtitle: const Text('Fits more rows on smaller screens.'),
                          secondary: const Icon(Icons.view_compact_alt_outlined),
                          onChanged: (value) { if (value != null) _save('ui_density', value); },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Text size', 'Adjust app text for readability.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Small'),
                              const Spacer(),
                              Text('${(textScale * 100).round()}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              const Text('Large'),
                            ],
                          ),
                          Slider(
                            min: 0.9,
                            max: 1.2,
                            divisions: 6,
                            value: textScale.clamp(0.9, 1.2).toDouble(),
                            label: '${(textScale * 100).round()}%',
                            onChanged: (value) => _save('text_scale', value),
                          ),
                          Text('Sample text · Invoice total ₹1,250.00', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Inventory alerts', 'Choose when a product should be flagged as low stock.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('Low-stock threshold')),
                              Text('${lowStockThreshold.round()} units', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            min: 1,
                            max: 100,
                            divisions: 99,
                            value: lowStockThreshold.clamp(1.0, 100.0).toDouble(),
                            label: '${lowStockThreshold.round()}',
                            onChanged: (value) => _save('low_stock_threshold', value.round()),
                          ),
                          Text(
                            'Products at or below this stock level appear in the dashboard alerts.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Corner style', 'Set the roundness used by the app theme.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SegmentedButton<double>(
                            segments: const [
                              ButtonSegment(value: 8, label: Text('Sharp')),
                              ButtonSegment(value: 16, label: Text('Rounded')),
                              ButtonSegment(value: 24, label: Text('Pill-like')),
                            ],
                            selected: {radius},
                            onSelectionChanged: (values) => _save('corner_radius', values.first),
                            showSelectedIcon: false,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.10),
                              border: Border.all(color: color.withOpacity(0.6)),
                              borderRadius: BorderRadius.circular(radius),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long, color: color),
                                const SizedBox(width: 12),
                                const Expanded(child: Text('Preview card', style: TextStyle(fontWeight: FontWeight.w600))),
                                Icon(Icons.check_circle, color: color),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _save('app_theme', 'green');
                      await _save('theme_mode', 'system');
                      await _save('ui_density', 'comfortable');
                      await _save('text_scale', 1.0);
                      await _save('corner_radius', 16.0);
                      await _save('low_stock_threshold', 10);
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset appearance'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
