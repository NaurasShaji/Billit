import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/customer_service.dart';
import '../../services/loyalty_service.dart';
import 'customer_detail_screen.dart';

enum _CustomerSort { recent, spend, visits, name }

class CustomerLookupScreen extends StatefulWidget {
  const CustomerLookupScreen({super.key});

  @override
  State<CustomerLookupScreen> createState() => _CustomerLookupScreenState();
}

class _CustomerLookupScreenState extends State<CustomerLookupScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CustomerSummary> _all = [];
  String _query = '';
  _CustomerSort _sort = _CustomerSort.recent;
  bool _onlyRewards = false;
  bool _onlyRepeat = false;
  bool _loyaltyOn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _loyaltyOn = LoyaltyService.enabled;
      _all = CustomerService.loadAll();
      if (!_loyaltyOn) _onlyRewards = false;
    });
  }

  List<CustomerSummary> get _visible {
    final list = _all.where((c) {
      if (_onlyRewards && !c.hasReward) return false;
      if (_onlyRepeat && c.visits < 2) return false;
      return c.matches(_query);
    }).toList();
    switch (_sort) {
      case _CustomerSort.recent:
        list.sort((a, b) => b.lastPurchase.compareTo(a.lastPurchase));
        break;
      case _CustomerSort.spend:
        list.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
        break;
      case _CustomerSort.visits:
        list.sort((a, b) => b.visits.compareTo(a.visits));
        break;
      case _CustomerSort.name:
        list.sort((a, b) => a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase()));
        break;
    }
    return list;
  }

  Future<void> _open(CustomerSummary customer) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customer: customer),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final customers = _visible;
    final rewardsReady = _all.where((c) => c.hasReward).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Lookup',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, phone or invoice number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (_loyaltyOn) ...[
                  FilterChip(
                    avatar: const Icon(Icons.card_giftcard, size: 16),
                    label: Text('Reward ready ($rewardsReady)'),
                    selected: _onlyRewards,
                    onSelected: (v) => setState(() => _onlyRewards = v),
                  ),
                  const SizedBox(width: 8),
                ],
                FilterChip(
                  label: const Text('Repeat customers'),
                  selected: _onlyRepeat,
                  onSelected: (v) => setState(() => _onlyRepeat = v),
                ),
                const SizedBox(width: 16),
                for (final entry in const {
                  _CustomerSort.recent: 'Recent',
                  _CustomerSort.spend: 'Top spenders',
                  _CustomerSort.visits: 'Most visits',
                  _CustomerSort.name: 'A-Z',
                }.entries) ...[
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _sort == entry.key,
                    onSelected: (_) => setState(() => _sort = entry.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${customers.length} of ${_all.length} customers',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? _buildEmpty(theme)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: customers.length,
                    itemBuilder: (context, i) => _CustomerTile(
                      customer: customers[i],
                      onTap: () => _open(customers[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    final scheme = theme.colorScheme;
    final filtering = _query.isNotEmpty || _onlyRewards || _onlyRepeat;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              filtering ? 'No customers found' : 'No customers yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              filtering
                  ? 'Try a different name or phone number, or clear the filters.'
                  : 'Customers appear here once a bill is saved with their name or phone number.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.onTap});

  final CustomerSummary customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final money =
        NumberFormat.simpleCurrency(locale: 'en_IN', decimalDigits: 0);
    final date = DateFormat('d MMM yyyy');
    final loyalty = customer.loyalty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: customer.hasReward ? scheme.primary : scheme.outlineVariant,
          width: customer.hasReward ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Text(
                  customer.initial,
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone.isNotEmpty
                          ? customer.phone
                          : 'No phone number',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${customer.visits} ${customer.visits == 1 ? 'visit' : 'visits'}'
                      ' \u2022 ${money.format(customer.totalSpent)}'
                      ' \u2022 last ${date.format(customer.lastPurchase)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (customer.hasReward)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard,
                          size: 14, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        'Reward',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                )
              else if (loyalty != null)
                Text(
                  '${loyalty.progress}/${loyalty.target}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
