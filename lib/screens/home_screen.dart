import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'tabs/billing_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/products_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/archive_tab.dart';
import 'settings_screen.dart';
import '../widgets/responsive_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  late AuthService _authService; // Declare AuthService

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>(); // Initialize AuthService
  }

  void _showHelpFaqDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Help & FAQ'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showHelpDialog();
                },
                child: const Text('Help'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showFaqDialog();
                },
                child: const Text('FAQ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // REPLACE THIS METHOD WITH THE ENHANCED VERSION
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.support_agent,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 12),
            const Text('Help & Support'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to Floral Bill Help Center',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildHelpOption(
                Icons.receipt_long,
                'Billing Guide',
                'Learn how to create, edit, and manage bills efficiently',
              ),
              const SizedBox(height: 12),
              _buildHelpOption(
                Icons.inventory_2_outlined,
                'Product Management',
                'Understand how to add, edit, and track your floral inventory',
              ),
              const SizedBox(height: 12),
              _buildHelpOption(
                Icons.bar_chart,
                'Reports & Analytics',
                'Get insights on generating and understanding sales reports',
              ),
              const SizedBox(height: 12),
              _buildHelpOption(
                Icons.settings,
                'System Settings',
                'Configure app settings, manage users, and handle backups',
              ),
              const SizedBox(height: 12),
              _buildHelpOption(
                Icons.contact_support,
                'Technical Support',
                'Contact our support team for technical assistance',
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Quick Tips:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Use keyboard shortcuts (e.g., Enter to confirm)\n'
                '• Regular backups are recommended\n'
                '• Check stock levels regularly\n'
                '• Generate reports at day end\n'
                '• Contact admin for user permissions',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showFaqDialog();
            },
            child: const Text('View FAQ'),
          ),
        ],
      ),
    );
  }

  // REPLACE THIS METHOD WITH THE ENHANCED VERSION
  void _showFaqDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Help & FAQ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Subtitle
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              
              // FAQ Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFaqItem(
                        'How do I create a new bill?',
                        'Go to the Billing tab, select products from the list, add quantities, choose payment method, and click "Generate Bill".',
                      ),
                      const SizedBox(height: 16),
                      _buildFaqItem(
                        'How do I add or edit products?',
                        'Navigate to the Products tab, click "Add Product" to create new ones, or click on an existing product to edit its details.',
                      ),
                      const SizedBox(height: 16),
                      _buildFaqItem(
                        'How do I view sales reports?',
                        'Use the Reports tab to view daily, monthly, and yearly sales reports. You can also filter by date ranges and export reports.',
                      ),
                      const SizedBox(height: 16),
                      _buildFaqItem(
                        'How do I manage inventory?',
                        'In the Products tab, you can track stock levels. The system automatically updates inventory when bills are generated.',
                      ),
                      const SizedBox(height: 16),
                      _buildFaqItem(
                        'Can I edit or void a bill?',
                        'Yes, in the Billing tab, you can find recent bills and edit them. Only admin users can void bills from the archive.',
                      ),
                      const SizedBox(height: 16),
                      _buildFaqItem(
                        'How do I handle product units (pcs/kg)?',
                        'When adding products, you can specify the unit type. The billing system will automatically handle calculations based on the unit.',
                      ),
                      const SizedBox(height: 16),
                      _buildFaqItem(
                        'How do I change my password?',
                        'Go to Settings > Change Password and enter your current password followed by your new password.',
                      ),
                      const SizedBox(height: 16),
                      _buildFaqItem(
                        'How do I backup my data?',
                        'Admin users can access backup options in the Archive tab. Regular backups are recommended to prevent data loss.',
                      ),
                      
                      
                    ],
                  ),
                ),
              ),
              
              // Close button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ADD THESE HELPER METHODS AT THE END OF THE CLASS (before the build method)
  Widget _buildFaqItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Q: $question',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A: $answer',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildHelpOption(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<IconData> _navigationIcons({
    required bool isAdmin,
    required String style,
  }) {
    final isFilled = style == 'filled';
    final isRounded = style == 'rounded';

    final overview = isFilled
        ? Icons.dashboard
        : isRounded
            ? Icons.dashboard_rounded
            : Icons.dashboard_outlined;
    final billing = isFilled
        ? Icons.receipt
        : isRounded
            ? Icons.receipt_rounded
            : Icons.receipt_long_outlined;
    final inventory = isFilled
        ? Icons.inventory
        : isRounded
            ? Icons.inventory_2_rounded
            : Icons.inventory_2_outlined;
    final reports = isFilled
        ? Icons.bar_chart
        : isRounded
            ? Icons.bar_chart_rounded
            : Icons.bar_chart_outlined;
    final archive = isFilled
        ? Icons.archive
        : isRounded
            ? Icons.archive_rounded
            : Icons.archive_outlined;

    return isAdmin
        ? [overview, billing, inventory, reports, archive]
        : [overview, billing, inventory, reports];
  }

  IconData _iconFromChoice(String choice, IconData fallback) {
    switch (choice) {
      case 'home': return Icons.home_outlined;
      case 'dashboard': return Icons.dashboard_outlined;
      case 'grid': return Icons.grid_view_rounded;
      case 'receipt': return Icons.receipt_long_outlined;
      case 'cart': return Icons.shopping_cart_outlined;
      case 'calculator': return Icons.calculate_outlined;
      case 'inventory': return Icons.inventory_2_outlined;
      case 'box': return Icons.widgets_outlined;
      case 'package': return Icons.inventory_2_outlined;
      case 'warehouse': return Icons.warehouse_outlined;
      case 'chart': return Icons.bar_chart_outlined;
      case 'analytics': return Icons.analytics_outlined;
      case 'trending': return Icons.trending_up_outlined;
      case 'archive': return Icons.archive_outlined;
      case 'folder': return Icons.folder_open_outlined;
      case 'history': return Icons.history;
      default: return fallback;
    }
  }

  List<IconData> _applyCustomNavigationIcons(
    List<IconData> defaults,
    List<String> keys,
    Map<dynamic, dynamic> overrides,
  ) {
    return List<IconData>.generate(defaults.length, (index) {
      final key = keys[index];
      return _iconFromChoice(overrides[key]?.toString() ?? '', defaults[index]);
    });
  }

  Widget _buildBottomNavigation({
    required List<String> labels,
    required List<IconData> icons,
    required int selectedIndex,
    required String style,
    required ValueChanged<int> onSelect,
  }) {
    if (style == 'classic') {
      return NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelect,
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final floating = style == 'floating';
    return Container(
      margin: floating ? const EdgeInsets.fromLTRB(12, 0, 12, 10) : EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(8, floating ? 8 : 4, 8, MediaQuery.paddingOf(context).bottom > 0 ? 4 : 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(floating ? 24 : 0),
        boxShadow: floating
            ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 4))]
            : null,
        border: style == 'underline'
            ? Border(top: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)))
            : null,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
                  decoration: BoxDecoration(
                    color: style == 'floating' && i == selectedIndex
                        ? scheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[i],
                        size: 23,
                        color: i == selectedIndex ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                          color: i == selectedIndex ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (style == 'underline')
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(top: 4),
                          height: 3,
                          width: i == selectedIndex ? 22 : 0,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _authService.isAdmin;

    final List<String> labels = isAdmin
        ? ['Overview', 'Billing', 'Inventory', 'Reports', 'Archive']
        : ['Overview', 'Billing', 'Inventory', 'Reports'];

    final settingsBox = Hive.box<dynamic>('app_settings');
    final navigationIconStyle =
        settingsBox.get('navigation_icon_style', defaultValue: 'outlined').toString();

    final List<IconData> defaultIcons = _navigationIcons(
      isAdmin: isAdmin,
      style: navigationIconStyle,
    );
    final navigationKeys = isAdmin
        ? ['overview', 'billing', 'inventory', 'reports', 'archive']
        : ['overview', 'billing', 'inventory', 'reports'];
    final rawOverrides = settingsBox.get('navigation_icon_overrides', defaultValue: <String, String>{});
    final navigationOverrides = rawOverrides is Map ? rawOverrides : <String, String>{};
    final List<IconData> icons = _applyCustomNavigationIcons(
      defaultIcons,
      navigationKeys,
      navigationOverrides,
    );

    final List<Widget> tabs = [
      DashboardTab(
        showFinancials: isAdmin,
        onOpenBilling: () => setState(() => _index = 1),
        onOpenProducts: () => setState(() => _index = 2),
        onOpenReports: () => setState(() => _index = 3),
      ),
      const BillingTab(),
      const ProductsTab(),
      const ReportsTab(),
      if (isAdmin) const ArchiveTab(),
    ];

    // Ensure _index is within bounds for worker
    if (!isAdmin && _index >= tabs.length) {
      _index = 0; // Default to Billing tab for worker if current index is out of bounds
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: ValueListenableBuilder<Box<dynamic>>(
          valueListenable: Hive.box<dynamic>('app_settings').listenable(),
          builder: (context, settings, _) {
            final appName = settings.get('app_name', defaultValue: 'Floral Bill').toString();
            final logoBase64 = settings.get('app_logo_base64') as String?;
            Widget? logo;
            if (logoBase64 != null && logoBase64.isNotEmpty) {
              try {
                logo = ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(base64Decode(logoBase64), width: 32, height: 32, fit: BoxFit.contain),
                );
              } catch (_) {
                logo = null;
              }
            }
            return Row(
              children: [
                if (logo != null) ...[logo, const SizedBox(width: 8)] else ...[ClipRRect(borderRadius: BorderRadius.circular(8), child: SvgPicture.asset('assets/icon/billit_logo.svg', width: 34, height: 34)), const SizedBox(width: 8)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(appName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(labels[_index], maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    isAdmin: isAdmin,
                    onHelp: () {
                      Navigator.of(context).pop();
                      _showHelpFaqDialog();
                    },
                    onLogout: () {
                      Navigator.of(context).pop();
                      context.read<AuthService>().logout();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= ResponsiveBreakpoints.desktop) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationRailDestination(
                        icon: Icon(icons[i]),
                        label: Text(labels[i]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ResponsivePage(
                    maxWidth: 1600,
                    child: tabs[_index],
                  ),
                ),
              ],
            );
          }
          return tabs[_index];
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < ResponsiveBreakpoints.desktop
          ? ValueListenableBuilder<Box<dynamic>>(
              valueListenable: Hive.box<dynamic>('app_settings').listenable(),
              builder: (context, settings, _) => _buildBottomNavigation(
                labels: labels,
                icons: _applyCustomNavigationIcons(
                  _navigationIcons(
                    isAdmin: isAdmin,
                    style: settings.get('navigation_icon_style', defaultValue: 'outlined').toString(),
                  ),
                  isAdmin
                      ? ['overview', 'billing', 'inventory', 'reports', 'archive']
                      : ['overview', 'billing', 'inventory', 'reports'],
                  settings.get('navigation_icon_overrides', defaultValue: <String, String>{}) is Map
                      ? settings.get('navigation_icon_overrides', defaultValue: <String, String>{}) as Map
                      : <String, String>{},
                ),
                selectedIndex: _index,
                style: settings.get('navigation_style', defaultValue: 'classic').toString(),
                onSelect: (i) => setState(() => _index = i),
              ),
            )
          : null,
    );
  }
}
