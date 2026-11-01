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
        final selectedTheme =
            box.get('app_theme', defaultValue: 'green').toString();
        final themeMode =
            box.get('theme_mode', defaultValue: 'system').toString();
        final density =
            box.get('ui_density', defaultValue: 'comfortable').toString();
        final productView =
            box.get('product_view', defaultValue: 'list').toString();
        final textScale =
            (box.get('text_scale', defaultValue: 1.0) as num).toDouble();
        final radius =
            (box.get('corner_radius', defaultValue: 16.0) as num).toDouble();
        final lowStockThreshold =
            (box.get('low_stock_threshold', defaultValue: 10) as num)
                .toDouble();
        final navigationStyle =
            box.get('navigation_style', defaultValue: 'classic').toString();
        final navigationIconStyle = box
            .get('navigation_icon_style', defaultValue: 'outlined')
            .toString();
        final surfaceStyle =
            box.get('surface_style', defaultValue: 'outlined').toString();
        final appBarStyle =
            box.get('app_bar_style', defaultValue: 'surface').toString();
        final fontStyle =
            box.get('font_style', defaultValue: 'system').toString();
        final backgroundStyle =
            box.get('background_style', defaultValue: 'tinted').toString();
        final inputStyle =
            box.get('input_style', defaultValue: 'filled').toString();
        final buttonStyle =
            box.get('button_style', defaultValue: 'filled').toString();
        final navigationIconOverridesRaw = box
            .get('navigation_icon_overrides', defaultValue: <String, String>{});
        final navigationIconOverrides = navigationIconOverridesRaw is Map
            ? Map<String, String>.from(navigationIconOverridesRaw)
            : <String, String>{};
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
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(radius + 4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.palette_outlined,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            size: 30),
                        const SizedBox(height: 12),
                        Text(
                          'Make Billit yours',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_paletteNames[selectedTheme] ?? 'Garden Green'} · ${themeMode[0].toUpperCase()}${themeMode.substring(1)} mode',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(context, 'Colour theme',
                      'Choose an accent colour for navigation and controls.'),
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
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: selected ? 3 : 0,
                                  ),
                                ),
                                child: selected
                                    ? Icon(Icons.check,
                                        color: entry.value.computeLuminance() >
                                                0.55
                                            ? Colors.black87
                                            : Colors.white,
                                        size: 21)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Light and dark mode',
                      'Follow your device or set a mode manually.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'system',
                              icon: Icon(Icons.settings_brightness),
                              label: Text('System')),
                          ButtonSegment(
                              value: 'light',
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light')),
                          ButtonSegment(
                              value: 'dark',
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark')),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (values) =>
                            _save('theme_mode', values.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Navigation icon skin',
                      'Choose a neutral icon family for Overview, Billing, Inventory and Reports.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'outlined',
                            groupValue: navigationIconStyle,
                            title: const Text('Outlined'),
                            subtitle: const Text('Light, clean line icons.'),
                            secondary: const Icon(Icons.dashboard_outlined),
                            onChanged: (value) {
                              if (value != null) {
                                _save('navigation_icon_style', value);
                              }
                            },
                          ),
                          RadioListTile<String>(
                            value: 'rounded',
                            groupValue: navigationIconStyle,
                            title: const Text('Rounded'),
                            subtitle: const Text('Soft rounded icon shapes.'),
                            secondary: const Icon(Icons.dashboard_rounded),
                            onChanged: (value) {
                              if (value != null) {
                                _save('navigation_icon_style', value);
                              }
                            },
                          ),
                          RadioListTile<String>(
                            value: 'filled',
                            groupValue: navigationIconStyle,
                            title: const Text('Filled'),
                            subtitle: const Text('Bold solid icons.'),
                            secondary: const Icon(Icons.dashboard),
                            onChanged: (value) {
                              if (value != null) {
                                _save('navigation_icon_style', value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Individual navigation icons',
                      'Choose a separate icon for each destination. Changes apply immediately.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _navigationIconPicker(
                              context,
                              'Overview',
                              'overview',
                              Icons.dashboard_outlined,
                              navigationIconOverrides),
                          const Divider(height: 24),
                          _navigationIconPicker(
                              context,
                              'Billing',
                              'billing',
                              Icons.receipt_long_outlined,
                              navigationIconOverrides),
                          const Divider(height: 24),
                          _navigationIconPicker(
                              context,
                              'Inventory',
                              'inventory',
                              Icons.inventory_2_outlined,
                              navigationIconOverrides),
                          const Divider(height: 24),
                          _navigationIconPicker(
                              context,
                              'Reports',
                              'reports',
                              Icons.bar_chart_outlined,
                              navigationIconOverrides),
                          const Divider(height: 24),
                          _navigationIconPicker(context, 'Archive', 'archive',
                              Icons.archive_outlined, navigationIconOverrides),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _save(
                                  'navigation_icon_overrides',
                                  <String, String>{}),
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset custom icons'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _sectionTitle(context, 'Navigation bar style',
                      'Choose how the main navigation looks on phones and tablets.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'classic',
                            groupValue: navigationStyle,
                            title: const Text('Classic'),
                            subtitle:
                                const Text('Standard Material navigation bar.'),
                            secondary: const Icon(Icons.view_day_outlined),
                            onChanged: (value) {
                              if (value != null) {
                                _save('navigation_style', value);
                              }
                            },
                          ),
                          RadioListTile<String>(
                            value: 'floating',
                            groupValue: navigationStyle,
                            title: const Text('Floating'),
                            subtitle: const Text(
                                'Rounded bar with a selected-item highlight.'),
                            secondary:
                                const Icon(Icons.space_dashboard_outlined),
                            onChanged: (value) {
                              if (value != null) {
                                _save('navigation_style', value);
                              }
                            },
                          ),
                          RadioListTile<String>(
                            value: 'underline',
                            groupValue: navigationStyle,
                            title: const Text('Underline'),
                            subtitle: const Text(
                                'Clean layout with a slim active indicator.'),
                            secondary: const Icon(Icons.horizontal_rule),
                            onChanged: (value) {
                              if (value != null) {
                                _save('navigation_style', value);
                              }
                            },
                          ),
                          RadioListTile<String>(
                            value: 'minimal',
                            groupValue: navigationStyle,
                            title: const Text('Minimal'),
                            subtitle: const Text(
                                'Simple icons and labels without a selected background.'),
                            secondary: const Icon(Icons.more_horiz),
                            onChanged: (value) {
                              if (value != null) {
                                _save('navigation_style', value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'App bar appearance',
                      'Choose between a subtle surface header or a strong brand-colour header.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'surface',
                              icon: Icon(Icons.view_agenda_outlined),
                              label: Text('Surface')),
                          ButtonSegment(
                              value: 'brand',
                              icon: Icon(Icons.color_lens_outlined),
                              label: Text('Brand')),
                        ],
                        selected: {appBarStyle},
                        onSelectionChanged: (values) =>
                            _save('app_bar_style', values.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Card and panel style',
                      'Control the depth and borders used across the interface.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'outlined',
                            groupValue: surfaceStyle,
                            title: const Text('Outlined'),
                            subtitle: const Text(
                                'Defined panels with subtle borders.'),
                            secondary: const Icon(Icons.crop_square),
                            onChanged: (v) {
                              if (v != null) _save('surface_style', v);
                            },
                          ),
                          RadioListTile<String>(
                            value: 'elevated',
                            groupValue: surfaceStyle,
                            title: const Text('Elevated'),
                            subtitle:
                                const Text('Soft shadows and raised cards.'),
                            secondary: const Icon(Icons.layers_outlined),
                            onChanged: (v) {
                              if (v != null) _save('surface_style', v);
                            },
                          ),
                          RadioListTile<String>(
                            value: 'flat',
                            groupValue: surfaceStyle,
                            title: const Text('Flat'),
                            subtitle: const Text(
                                'Minimal surfaces without shadows or borders.'),
                            secondary: const Icon(Icons.rectangle_outlined),
                            onChanged: (v) {
                              if (v != null) _save('surface_style', v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Typography',
                      'Choose the overall typeface style used throughout the app.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'system', label: Text('System')),
                          ButtonSegment(value: 'serif', label: Text('Serif')),
                          ButtonSegment(
                              value: 'monospace', label: Text('Mono')),
                        ],
                        selected: {fontStyle},
                        onSelectionChanged: (values) =>
                            _save('font_style', values.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Page background',
                      'Choose the overall canvas behind cards and content.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'tinted',
                              icon: Icon(Icons.gradient),
                              label: Text('Tinted')),
                          ButtonSegment(
                              value: 'plain',
                              icon: Icon(Icons.crop_square),
                              label: Text('Plain')),
                        ],
                        selected: {backgroundStyle},
                        onSelectionChanged: (values) =>
                            _save('background_style', values.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Input field appearance',
                      'Choose filled fields or a cleaner transparent outlined style.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'filled',
                              icon: Icon(Icons.format_color_fill),
                              label: Text('Filled')),
                          ButtonSegment(
                              value: 'outlined',
                              icon: Icon(Icons.border_outer),
                              label: Text('Outlined')),
                        ],
                        selected: {inputStyle},
                        onSelectionChanged: (values) =>
                            _save('input_style', values.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Button appearance',
                      'Set the emphasis used by primary action buttons.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'filled',
                            groupValue: buttonStyle,
                            title: const Text('Filled'),
                            subtitle:
                                const Text('Strong accent-colour buttons.'),
                            secondary: const Icon(Icons.smart_button),
                            onChanged: (v) {
                              if (v != null) _save('button_style', v);
                            },
                          ),
                          RadioListTile<String>(
                            value: 'tonal',
                            groupValue: buttonStyle,
                            title: const Text('Tonal'),
                            subtitle:
                                const Text('Softer colour-filled buttons.'),
                            secondary: const Icon(Icons.rectangle_rounded),
                            onChanged: (v) {
                              if (v != null) _save('button_style', v);
                            },
                          ),
                          RadioListTile<String>(
                            value: 'minimal',
                            groupValue: buttonStyle,
                            title: const Text('Minimal'),
                            subtitle: const Text(
                                'Low-emphasis buttons with no elevation.'),
                            secondary: const Icon(Icons.border_clear),
                            onChanged: (v) {
                              if (v != null) _save('button_style', v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Display density',
                      'Choose a more compact view or extra breathing room.'),
                  Card(
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'comfortable',
                          groupValue: density,
                          title: const Text('Comfortable'),
                          subtitle: const Text(
                              'More spacing; easier to tap on phones.'),
                          secondary: const Icon(Icons.space_dashboard_outlined),
                          onChanged: (value) {
                            if (value != null) _save('ui_density', value);
                          },
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          value: 'compact',
                          groupValue: density,
                          title: const Text('Compact'),
                          subtitle:
                              const Text('Fits more rows on smaller screens.'),
                          secondary:
                              const Icon(Icons.view_compact_alt_outlined),
                          onChanged: (value) {
                            if (value != null) _save('ui_density', value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Product catalogue layout',
                      'Choose how inventory items are displayed.'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'list',
                              icon: Icon(Icons.view_list_outlined),
                              label: Text('List')),
                          ButtonSegment(
                              value: 'grid',
                              icon: Icon(Icons.grid_view_rounded),
                              label: Text('Grid')),
                        ],
                        selected: {productView},
                        onSelectionChanged: (values) =>
                            _save('product_view', values.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(
                      context, 'Text size', 'Adjust app text for readability.'),
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
                              Text('${(textScale * 100).round()}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold)),
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
                          const Text('Sample text · Invoice total ₹1,250.00',
                              style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Inventory alerts',
                      'Choose when a product should be flagged as low stock.'),
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
                              const Expanded(
                                  child: Text('Low-stock threshold')),
                              Text('${lowStockThreshold.round()} units',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            min: 1,
                            max: 100,
                            divisions: 99,
                            value:
                                lowStockThreshold.clamp(1.0, 100.0).toDouble(),
                            label: '${lowStockThreshold.round()}',
                            onChanged: (value) =>
                                _save('low_stock_threshold', value.round()),
                          ),
                          Text(
                            'Products at or below this stock level appear in the dashboard alerts.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Corner style',
                      'Set the roundness used by the app theme.'),
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
                              ButtonSegment(
                                  value: 24, label: Text('Pill-like')),
                            ],
                            selected: {radius},
                            onSelectionChanged: (values) =>
                                _save('corner_radius', values.first),
                            showSelectedIcon: false,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.6)),
                              borderRadius: BorderRadius.circular(radius),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long, color: color),
                                const SizedBox(width: 12),
                                const Expanded(
                                    child: Text('Preview card',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600))),
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
                      await _save('product_view', 'list');
                      await _save('navigation_style', 'classic');
                      await _save('navigation_icon_style', 'outlined');
                      await _save(
                          'navigation_icon_overrides', <String, String>{});
                      await _save('surface_style', 'outlined');
                      await _save('app_bar_style', 'surface');
                      await _save('font_style', 'system');
                      await _save('background_style', 'tinted');
                      await _save('input_style', 'filled');
                      await _save('button_style', 'filled');
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

  Widget _navigationIconPicker(
    BuildContext context,
    String label,
    String settingKey,
    IconData fallback,
    Map<String, String> overrides,
  ) {
    const choices = <String, String>{
      'default': 'Default',
      'home': 'Home',
      'dashboard': 'Dashboard',
      'grid': 'Grid',
      'receipt': 'Receipt',
      'cart': 'Shopping cart',
      'calculator': 'Calculator',
      'inventory': 'Inventory',
      'box': 'Boxes',
      'package': 'Package',
      'warehouse': 'Warehouse',
      'chart': 'Bar chart',
      'analytics': 'Analytics',
      'trending': 'Trending',
      'archive': 'Archive',
      'folder': 'Folder',
      'history': 'History',
    };
    const icons = <String, IconData>{
      'home': Icons.home_outlined,
      'dashboard': Icons.dashboard_outlined,
      'grid': Icons.grid_view_rounded,
      'receipt': Icons.receipt_long_outlined,
      'cart': Icons.shopping_cart_outlined,
      'calculator': Icons.calculate_outlined,
      'inventory': Icons.inventory_2_outlined,
      'box': Icons.widgets_outlined,
      'warehouse': Icons.warehouse_outlined,
      'chart': Icons.bar_chart_outlined,
      'analytics': Icons.analytics_outlined,
      'trending': Icons.trending_up_outlined,
      'archive': Icons.archive_outlined,
      'folder': Icons.folder_open_outlined,
      'history': Icons.history,
    };
    final selected = overrides[settingKey] ?? 'default';
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Row(
            children: [
              Icon(selected == 'default'
                  ? fallback
                  : icons[selected] ?? fallback),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: choices.containsKey(selected) ? selected : 'default',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Icon',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: choices.entries
                .map((entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Row(
                        children: [
                          if (entry.key != 'default') ...[
                            Icon(icons[entry.key], size: 19),
                            const SizedBox(width: 10),
                          ] else ...[
                            Icon(fallback, size: 19),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                              child: Text(entry.value,
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final updated = Map<String, String>.from(overrides);
              if (value == 'default') {
                updated.remove(settingKey);
              } else {
                updated[settingKey] = value;
              }
              _save('navigation_icon_overrides', updated);
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
