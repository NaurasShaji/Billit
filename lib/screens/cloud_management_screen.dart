import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_account_service.dart';

class CloudManagementScreen extends StatefulWidget {
  const CloudManagementScreen({super.key});

  @override
  State<CloudManagementScreen> createState() => _CloudManagementScreenState();
}

class _CloudManagementScreenState extends State<CloudManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  bool _showPassword = false;
  late Future<List<Map<String, dynamic>>> _membersFuture;
  final Map<String, bool> _permissions = {
    'billing': true,
    'inventory': true,
    'reports': false,
    'expenses': false,
    'payroll': false,
  };

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    final shopId = auth.currentShopId;
    _membersFuture = shopId == null
        ? Future.value([])
        : CloudAccountService.listMembers(shopId);
  }

  @override
  void dispose() {
    _shopName.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthService auth) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (auth.isPlatformOwner) {
        final result = await CloudAccountService.createShop(
          shopName: _shopName.text.trim(),
          adminEmail: _email.text.trim(),
          adminPassword: _password.text,
          adminName: _name.text.trim(),
        );
        final shop = result['shop'];
        if (shop is Map && shop['id'] != null) {
          await auth.switchShop(shop['id'].toString());
          _membersFuture = CloudAccountService.listMembers(shop['id'].toString());
        }
      } else {
        final shopId = auth.currentShopId;
        if (shopId == null) throw Exception('No active shop is selected.');
        await CloudAccountService.createWorker(
          shopId: shopId,
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
          permissions: Map<String, bool>.from(_permissions),
        );
        _membersFuture = CloudAccountService.listMembers(shopId);
      }
      if (!mounted) return;
      _name.clear();
      _email.clear();
      _password.clear();
      _shopName.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.isPlatformOwner
              ? 'Shop and administrator account created.'
              : 'Worker account created.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isCloudAuth || !auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Management')),
        body: const Center(child: Text('Cloud administrator access required.')),
      );
    }

    final owner = auth.isPlatformOwner;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Account Management')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(owner ? Icons.business_rounded : Icons.group_add_rounded,
                        size: 30, color: scheme.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            owner ? 'Create a shop' : 'Add a worker',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(owner
                              ? 'Create a shop and its first administrator.'
                              : 'Create a staff login for ${auth.currentShopName ?? 'this shop'}.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (owner) ...[
                      TextFormField(
                        controller: _shopName,
                        decoration: const InputDecoration(
                          labelText: 'Shop name',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter a shop name'
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: owner ? 'Administrator name' : 'Worker name',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(email)
                            ? null
                            : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Temporary password (minimum 8 characters)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                          icon: Icon(_showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? 'Use at least 8 characters'
                          : null,
                    ),
                    if (!owner) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Worker permissions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Access is enforced by Supabase Row Level Security, not just hidden in the app.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 10),
                      for (final entry in _permissions.entries)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_permissionLabel(entry.key)),
                          value: entry.value,
                          onChanged: (value) =>
                              setState(() => _permissions[entry.key] = value),
                        ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _submit(auth),
                        icon: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(owner ? 'Create shop and admin' : 'Create worker account'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The account is created centrally. Give the temporary password to the user securely and ask them to change it after their first sign-in.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (auth.currentShopId != null) ...[
                const SizedBox(height: 28),
                Text(
                  'Shop members',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _membersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text('Could not load members: ${snapshot.error}');
                    }
                    final members = snapshot.data ?? [];
                    if (members.isEmpty) return const Text('No members found.');
                    return Column(
                      children: [
                        for (final member in members)
                          _buildMemberCard(context, auth, member),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    AuthService auth,
    Map<String, dynamic> member,
  ) {
    final isWorker = member['role'] == 'worker';
    final active = member['is_active'] == true;
    final permissionsRaw = member['permissions'];
    final permissions = permissionsRaw is Map
        ? Map<String, dynamic>.from(permissionsRaw)
        : <String, dynamic>{};
    final displayName = member['display_name']?.toString().trim() ?? '';
    final email = member['email']?.toString() ?? '';
    final userId = member['user_id']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(isWorker ? Icons.person_outline : Icons.admin_panel_settings_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.isEmpty ? email : displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (displayName.isNotEmpty)
                        Text(email, style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        isWorker ? 'Worker' : 'Shop administrator',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                if (!active)
                  const Chip(label: Text('Disabled'))
                else if (isWorker)
                  IconButton(
                    tooltip: 'Disable worker',
                    onPressed: () => _disableMember(auth, userId),
                    icon: const Icon(Icons.person_off_outlined),
                  ),
              ],
            ),
            if (isWorker && active) ...[
              const Divider(height: 22),
              for (final key in _permissions.keys)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_permissionLabel(key)),
                  value: permissions[key] == true,
                  onChanged: (value) => _updatePermission(
                    auth,
                    userId,
                    {..._permissionsFrom(permissions), key: value},
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, bool> _permissionsFrom(Map<String, dynamic> source) => {
        for (final key in _permissions.keys) key: source[key] == true,
      };

  Future<void> _updatePermission(
    AuthService auth,
    String userId,
    Map<String, bool> permissions,
  ) async {
    final shopId = auth.currentShopId;
    if (shopId == null) return;
    try {
      await CloudAccountService.updateWorkerPermissions(
        shopId: shopId,
        userId: userId,
        permissions: permissions,
      );
      if (!mounted) return;
      setState(() {
        _membersFuture = CloudAccountService.listMembers(shopId);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update permissions: $error')),
      );
    }
  }

  Future<void> _disableMember(AuthService auth, String userId) async {
    final shopId = auth.currentShopId;
    if (shopId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable worker?'),
        content: const Text('This worker will no longer be able to sign in to this shop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await CloudAccountService.disableWorker(shopId: shopId, userId: userId);
      if (!mounted) return;
      setState(() {
        _membersFuture = CloudAccountService.listMembers(shopId);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not disable worker: $error')),
      );
    }
  }

  String _permissionLabel(String key) {
    switch (key) {
      case 'billing':
        return 'Billing';
      case 'inventory':
        return 'Inventory';
      case 'reports':
        return 'Reports';
      case 'expenses':
        return 'Expenses';
      case 'payroll':
        return 'Payroll';
      default:
        return key;
    }
  }
}
