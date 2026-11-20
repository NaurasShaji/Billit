import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/local_shop_data_import_service.dart';
import 'cloud_management_screen.dart';
import 'archive/change_password_screen.dart';

class CloudAccessPendingScreen extends StatefulWidget {
  const CloudAccessPendingScreen({super.key});

  @override
  State<CloudAccessPendingScreen> createState() => _CloudAccessPendingScreenState();
}

class _CloudAccessPendingScreenState extends State<CloudAccessPendingScreen> {
  bool _syncing = false;
  String? _syncMessage;
  bool _importing = false;
  String? _importMessage;

  Future<void> _sync(AuthService auth) async {
    final shopId = auth.currentShopId;
    if (shopId == null || _syncing) return;
    setState(() { _syncing = true; _syncMessage = null; });
    try {
      final result = await CloudSyncService.syncShop(
        shopId: shopId,
        permissions: auth.cloudPermissions,
        isAdmin: auth.isAdmin,
      );
      if (!mounted) return;
      setState(() => _syncMessage =
          'Sync completed: ${result.pushed} local changes uploaded, ${result.pulled} cloud records downloaded.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _syncMessage = 'Sync failed: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _importLocalData(AuthService auth) async {
    final shopId = auth.currentShopId;
    if (shopId == null || _importing || !auth.isAdmin) return;
    setState(() { _importing = true; _importMessage = null; });
    try {
      final preview = await LocalShopDataImportService.preview(shopId: shopId);
      if (!mounted) return;
      if (preview.total == 0) {
        setState(() => _importMessage =
            'No existing local business records were found on this device.');
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import existing Billit data?'),
          content: Text(
            'Copy the current device database into ${auth.currentShopName ?? 'this shop'}?\n\n'
            'Products: ${preview.products}\n'
            'Sales: ${preview.sales}\n'
            'Expenses: ${preview.expenses}\n'
            'Employees: ${preview.employees}\n\n'
            'The original local database will remain untouched. This import is one-time and will be blocked if this shop already has cloud or local records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import data'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final result = await LocalShopDataImportService.importIntoShop(
        shopId: shopId,
        isAdmin: auth.isAdmin,
      );
      auth.refreshDatabaseBindings();
      if (!mounted) return;
      setState(() => _importMessage =
          'Imported ${result.products} products, ${result.sales} sales, ${result.expenses} expenses and ${result.employees} employees into this shop. The original device database was not changed. Cloud upload is pending.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _importMessage = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billit Cloud'),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<AuthService>().logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_sync_outlined, size: 62, color: colors.primary),
                const SizedBox(height: 20),
                Text(
                  'Cloud account connected',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  auth.currentShopName == null
                      ? 'Platform owner account'
                      : 'Workspace: ${auth.currentShopName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (auth.isPlatformOwner && auth.availableShops.length > 1) ...[
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: auth.currentShopId,
                    hint: const Text('Select shop'),
                    items: [
                      for (final shop in auth.availableShops)
                        DropdownMenuItem(
                          value: shop['id'],
                          child: Text(shop['name'] ?? 'Shop'),
                        ),
                    ],
                    onChanged: (shopId) async {
                      if (shopId == null || shopId == auth.currentShopId) return;
                      try {
                        await context.read<AuthService>().switchShop(shopId);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not switch shop: $error')),
                          );
                        }
                      }
                    },
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.error.withValues(alpha: 0.35)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Cloud POS access is still locked.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Billit has authenticated your account, opened an isolated local database for this shop and added manual cloud synchronization. POS access remains blocked until the Supabase migrations are applied and synchronization is verified against your actual project.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Do not enter production sales or inventory until synchronization and tenant-specific local storage are completed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (auth.isAdmin && auth.currentShopId != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _importing ? null : () => _importLocalData(auth),
                      icon: _importing
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.move_to_inbox_outlined),
                      label: Text(_importing
                          ? 'Importing device data…'
                          : 'Import existing device data'),
                    ),
                  ),
                  if (_importMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_importMessage!, textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
                if (auth.currentShopId != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _syncing ? null : () => _sync(auth),
                      icon: _syncing
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync_rounded),
                      label: Text(_syncing ? 'Syncing shop data…' : 'Sync shop data'),
                    ),
                  ),
                  if (_syncMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_syncMessage!, textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
                if (auth.isAdmin) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CloudManagementScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: Text(auth.isPlatformOwner
                          ? 'Manage shops and administrators'
                          : 'Create worker accounts'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Change password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
