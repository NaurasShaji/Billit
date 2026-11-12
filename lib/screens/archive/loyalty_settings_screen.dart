import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/models.dart';
import '../../services/boxes.dart';
import '../../services/loyalty_service.dart';

/// Owner-facing setup for the loyalty card scheme.
class LoyaltySettingsScreen extends StatefulWidget {
  const LoyaltySettingsScreen({super.key});

  @override
  State<LoyaltySettingsScreen> createState() => _LoyaltySettingsScreenState();
}

class _LoyaltySettingsScreenState extends State<LoyaltySettingsScreen> {
  late bool _enabled;
  late LoyaltyRewardType _type;
  late bool _countHistory;
  late String _productId;
  late String _productName;
  late final TextEditingController _target;
  late final TextEditingController _value;
  late final TextEditingController _productQty;
  late final TextEditingController _customText;
  late final TextEditingController _minBill;
  String? _error;

  static const _typeLabels = <LoyaltyRewardType, String>{
    LoyaltyRewardType.percent: 'Percent off',
    LoyaltyRewardType.amount: 'Flat \u20B9 off',
    LoyaltyRewardType.freeProduct: 'Free product',
    LoyaltyRewardType.custom: 'Custom gift',
  };

  @override
  void initState() {
    super.initState();
    final c = LoyaltyService.config;
    _enabled = c.enabled;
    _type = c.rewardType;
    _countHistory = c.countHistory;
    _productId = c.productId;
    _productName = c.productName;
    _target = TextEditingController(text: c.target.toString());
    _value = TextEditingController(text: _plain(c.rewardValue));
    _productQty = TextEditingController(text: _plain(c.productQty));
    _customText = TextEditingController(text: c.customText);
    _minBill = TextEditingController(text: _plain(c.minBill));
  }

  @override
  void dispose() {
    _target.dispose();
    _value.dispose();
    _productQty.dispose();
    _customText.dispose();
    _minBill.dispose();
    super.dispose();
  }

  String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  bool get _isDiscount =>
      _type == LoyaltyRewardType.percent || _type == LoyaltyRewardType.amount;

  /// The scheme as currently typed, or null (and [_error] set) if invalid.
  LoyaltyConfig? _read() {
    final target = int.tryParse(_target.text.trim());
    final value = double.tryParse(_value.text.trim());
    final qty = double.tryParse(_productQty.text.trim());
    final minBill = _minBill.text.trim().isEmpty
        ? 0.0
        : double.tryParse(_minBill.text.trim());

    String? error;
    if (target == null || target < 2 || target > 100) {
      error = 'Purchases needed must be between 2 and 100.';
    } else if (_isDiscount && (value == null || value <= 0)) {
      error = 'Enter a reward greater than 0.';
    } else if (_type == LoyaltyRewardType.percent && (value ?? 0) > 100) {
      error = 'A percentage reward cannot be more than 100%.';
    } else if (_type == LoyaltyRewardType.freeProduct && _productId.isEmpty) {
      error = 'Choose the product to give for free.';
    } else if (_type == LoyaltyRewardType.freeProduct &&
        (qty == null || qty <= 0)) {
      error = 'Enter how many units of the product to give.';
    } else if (_type == LoyaltyRewardType.custom &&
        _customText.text.trim().isEmpty) {
      error = 'Describe the gift, e.g. "Free gift wrap".';
    } else if (minBill == null || minBill < 0) {
      error = 'Minimum bill must be 0 or more.';
    }
    if (error != null) {
      _error = error;
      return null;
    }
    _error = null;
    return LoyaltyService.config.copyWith(
      enabled: _enabled,
      target: target,
      rewardType: _type,
      rewardValue: _isDiscount ? value : null,
      productId: _productId,
      productName: _productName,
      productQty: qty,
      customText: _customText.text.trim(),
      minBill: minBill,
      countHistory: _countHistory,
    );
  }

  Future<void> _save() async {
    final config = _read();
    setState(() {});
    if (config == null) return;
    await LoyaltyService.saveConfig(config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(config.enabled
            ? 'Loyalty program saved'
            : 'Loyalty program saved (switched off)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _pickProduct() async {
    final products = Hive.box<Product>(Boxes.products)
        .values
        .where((p) => p.active)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductPickerSheet(products: products),
    );
    if (picked != null) {
      setState(() {
        _productId = picked.id;
        _productName = picked.name;
      });
    }
  }

  String get _summary {
    final target = int.tryParse(_target.text.trim());
    if (target == null || target < 1) return '';
    final value = double.tryParse(_value.text.trim()) ?? 0;
    final qty = double.tryParse(_productQty.text.trim()) ?? 1;
    final label = LoyaltyConfig(
      rewardType: _type,
      rewardValue: value,
      productId: _productId,
      productName: _productName,
      productQty: qty,
      customText: _customText.text,
    ).rewardLabel;
    if (_isDiscount && value <= 0) return '';
    if (_type == LoyaltyRewardType.freeProduct && _productId.isEmpty) return '';
    if (_type == LoyaltyRewardType.custom && _customText.text.trim().isEmpty) {
      return '';
    }
    final min = double.tryParse(_minBill.text.trim()) ?? 0;
    final minText = min > 0 ? ' of at least \u20B9${_plain(min)} each' : '';
    return 'After $target purchases$minText, the customer earns: $label.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty Program')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable loyalty program',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text(
                'Customers are tracked by phone number. A reward is earned '
                'after a set number of purchases.'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const Divider(height: 32),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Purchases needed for a reward',
              helperText: 'Each saved bill counts as one purchase',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('What does the customer get?',
              style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _typeLabels.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _type == entry.key,
                  onSelected: (_) => setState(() => _type = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isDiscount)
            TextField(
              controller: _value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _type == LoyaltyRewardType.percent
                    ? 'Discount percentage'
                    : 'Discount amount (\u20B9)',
                helperText: 'Taken off the next bill',
                border: const OutlineInputBorder(),
              ),
            ),
          if (_type == LoyaltyRewardType.freeProduct) ...[
            OutlinedButton.icon(
              onPressed: _pickProduct,
              icon: const Icon(Icons.inventory_2_outlined),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _productId.isEmpty
                      ? 'Choose product'
                      : (_productName.isEmpty ? 'Selected product' : _productName),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _productQty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Quantity given free',
                helperText:
                    'Added to the bill at \u20B90 and deducted from stock',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_type == LoyaltyRewardType.custom)
            TextField(
              controller: _customText,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Gift description',
                hintText: 'e.g. Free gift wrap, free delivery, mystery gift',
                helperText:
                    'Shown to the cashier to hand over; the bill is not changed',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _minBill,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Minimum bill to count (\u20B9)',
              helperText: 'Leave 0 to count every bill',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Count past purchases'),
            subtitle: const Text(
                'Off: only bills made after the program was switched on count. '
                'On: existing customers get credit for their earlier bills, so '
                'some may have rewards right away.'),
            value: _countHistory,
            onChanged: (v) => setState(() => _countHistory = v),
          ),
          if (_summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.card_giftcard, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_summary,
                        style: TextStyle(color: scheme.onPrimaryContainer)),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
          const SizedBox(height: 12),
          Text(
            'When a customer earns a reward you will see a message after the '
            'sale, and a banner with an Apply button appears on their next '
            'bill. Deleting an invoice automatically corrects their progress.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Searchable list of active products for choosing the free-product reward.
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.products});

  final List<Product> products;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = widget.products
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    final height = MediaQuery.of(context).size.height * 0.7;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(child: Text('No products found'))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final p = shown[i];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text('Stock: ${p.stock}'),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}