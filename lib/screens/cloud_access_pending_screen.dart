import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'cloud_management_screen.dart';
import 'archive/change_password_screen.dart';

class CloudAccessPendingScreen extends StatelessWidget {
  const CloudAccessPendingScreen({super.key});

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
                        'Cloud data synchronization is not enabled yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Billit has authenticated your account and loaded its shop permissions, but business records are still stored in local SQLite. The app is blocking the POS screens so one shop cannot accidentally see another shop’s local data.',
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
