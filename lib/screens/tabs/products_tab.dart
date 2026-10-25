import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/models.dart';
import '../../services/boxes.dart';
import '../manage_product_screen.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});
  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String query = '';
  UnitType? unitFilter;
  String category = 'All';
  String subCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Product>(Boxes.products);
    final all = box.values.where((p) => p.active).toList();
    final filtered = all.where((p) {
      final q = p.name.toLowerCase().contains(query.toLowerCase());
      final uf = unitFilter == null || p.unit == unitFilter;
      final cf = category == 'All' || p.category == category;
      final sf = subCategory == 'All' || p.subCategory == subCategory;
      return q && uf && cf && sf;
    }).toList();

    final categories = ['All', ...{for (final p in all) p.category}];
    final subcats = ['All', ...{for (final p in all) p.subCategory}];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      hintText: 'Search products...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Stack filters on narrow screens to avoid dropdown overflow.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 600;
                    final categoryFilter = _buildFilterDropdown(
                      value: category,
                      items: categories,
                      label: 'Category',
                      onChanged: (v) => setState(() => category = v ?? 'All'),
                    );
                    final subCategoryFilter = _buildFilterDropdown(
                      value: subCategory,
                      items: subcats,
                      label: 'Sub-Category',
                      onChanged: (v) => setState(() => subCategory = v ?? 'All'),
                    );
                    final unitDropdown = _buildFilterDropdown<UnitType?>(
                      value: unitFilter,
                      items: [null, ...UnitType.values],
                      label: 'Unit',
                      onChanged: (v) => setState(() => unitFilter = v),
                      itemBuilder: (item) => Text(item == null ? 'All Units' : item.name.toUpperCase()),
                    );
                    if (narrow) {
                      return Column(
                        children: [
                          categoryFilter,
                          const SizedBox(height: 8),
                          subCategoryFilter,
                          const SizedBox(height: 8),
                          unitDropdown,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: categoryFilter),
                        const SizedBox(width: 12),
                        Expanded(child: subCategoryFilter),
                        const SizedBox(width: 12),
                        Expanded(child: unitDropdown),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Results Count
                Text(
                  '${filtered.length} products found',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Products List
          Expanded(
            child: ValueListenableBuilder<Box<dynamic>>(
              valueListenable: Hive.box<dynamic>('app_settings').listenable(),
              builder: (context, settings, _) {
                if (filtered.isEmpty) return _buildEmptyState();
                final view = settings.get('product_view', defaultValue: 'list').toString();
                return view == 'grid' ? _buildGridView(filtered) : _buildListView(filtered);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    required Function(T?) onChanged,
    Widget Function(T)? itemBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: itemBuilder != null 
                ? itemBuilder(item)
                : Text(
                    item?.toString() ?? 'All',
                    style: const TextStyle(fontSize: 14),
                  ),
          )).toList(),
          onChanged: onChanged,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildGridView(List<Product> products) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 230,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final threshold = (Hive.box<dynamic>('app_settings').get('low_stock_threshold', defaultValue: 10) as num).toDouble();
        final lowStock = product.stock <= threshold;
        final theme = Theme.of(context);
        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: InkWell(
            onTap: () => _showProductDetails(product),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      if (product.barcode?.isNotEmpty == true)
                        const Tooltip(message: 'Barcode assigned', child: Icon(Icons.qr_code_2, size: 18)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('₹${product.sellingPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: lowStock ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${product.stock.toStringAsFixed(product.stock == product.stock.roundToDouble() ? 0 : 1)} ${product.unit.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: lowStock ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit product',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openEditor(product: product),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(List<Product> products) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        final threshold = (Hive.box<dynamic>('app_settings').get('low_stock_threshold', defaultValue: 10) as num).toDouble();
        final isLowStock = product.stock <= threshold;
        return _buildListCard(product, isLowStock);
      },
    );
  }





  Widget _buildListCard(Product product, bool isLowStock) {
    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
          children: [
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.category,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '₹${product.sellingPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLowStock ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${product.stock} ${product.unit.name}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isLowStock ? Theme.of(context).colorScheme.onErrorContainer : Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Action Buttons
            Column(
              children: [
                IconButton(
                  onPressed: () => _openEditor(product: product),
                  icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                ),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Product?'),
                        content: Text('Are you sure you want to delete "${product.name}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                        ],
                      ),
                    ) ?? false;
                    if (confirm) {
                      await product.delete();
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showProductDetails(Product product) {
    final isLowStock = product.stock < 10;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category
              _buildDetailRow('Category', product.category, Icons.category_outlined),
              const SizedBox(height: 16),
              
              // Sub-Category (if exists)
              if (product.subCategory.isNotEmpty)
                Column(
                  children: [
                    _buildDetailRow('Sub-Category', product.subCategory, Icons.subdirectory_arrow_right),
                    const SizedBox(height: 16),
                  ],
                ),
              
              // Selling Price
              _buildDetailRow('Selling Price', '₹${product.sellingPrice.toStringAsFixed(2)}', Icons.sell_outlined, Colors.green),
              const SizedBox(height: 16),
              
              // Cost Price
              _buildDetailRow('Cost Price', '₹${product.costPrice.toStringAsFixed(2)}', Icons.shopping_cart_outlined, Colors.blue),
              const SizedBox(height: 16),
              
              // Stock
              _buildDetailRow(
                'Stock', 
                '${product.stock.toStringAsFixed(product.unit == UnitType.kg ? 1 : 0)} ${product.unit.name}',
                Icons.inventory_2_outlined,
                isLowStock ? Colors.orange : Colors.green,
              ),
              const SizedBox(height: 16),
              
              // Profit Margin
              if (product.costPrice > 0)
                Column(
                  children: [
                    _buildDetailRow(
                      'Profit Margin', 
                      '₹${(product.sellingPrice - product.costPrice).toStringAsFixed(2)}',
                      Icons.trending_up_outlined,
                      Colors.green,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _adjustStock(product),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Restock / Adjust quantity'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _showStockHistory(product),
                  icon: const Icon(Icons.history),
                  label: const Text('View stock adjustment history'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openEditor(product: product);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustStock(Product product) async {
    final controller = TextEditingController();
    final delta = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Adjust stock · ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current stock: ${product.stock} ${product.unit.name}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Quantity change',
                hintText: 'e.g. 12 to restock, -2 to remove',
                helperText: 'Use a positive number to add stock or a negative number to remove it.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a non-zero quantity change.')),
                );
                return;
              }
              if (product.stock + value < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stock cannot become negative.')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Update stock'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (delta == null || !mounted) return;
    final previousStock = product.stock;
    product.stock += delta;
    await product.save();

    final settings = Hive.box<dynamic>('app_settings');
    final history = (settings.get('inventory_adjustments', defaultValue: <dynamic>[]) as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    history.add({
      'productId': product.id,
      'productName': product.name,
      'date': DateTime.now().toIso8601String(),
      'delta': delta,
      'previousStock': previousStock,
      'newStock': product.stock,
      'unit': product.unit.name,
    });
    if (history.length > 500) {
      history.removeRange(0, history.length - 500);
    }
    await settings.put('inventory_adjustments', history);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stock updated for ${product.name}. New stock: ${product.stock} ${product.unit.name}.')),
    );
  }

  Future<void> _showStockHistory(Product product) async {
    final settings = Hive.box<dynamic>('app_settings');
    final history = (settings.get('inventory_adjustments', defaultValue: <dynamic>[]) as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .where((entry) => entry['productId'] == product.id)
        .toList()
      ..sort((a, b) => DateTime.parse(b['date'] as String).compareTo(DateTime.parse(a['date'] as String)));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Stock history · ${product.name}'),
        content: SizedBox(
          width: 460,
          height: 360,
          child: history.isEmpty
              ? const Center(child: Text('No manual stock adjustments have been recorded yet.'))
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    final delta = (entry['delta'] as num).toDouble();
                    final date = DateTime.parse(entry['date'] as String).toLocal();
                    final quantity = delta.abs().toStringAsFixed(delta.abs() == delta.abs().roundToDouble() ? 0 : 2);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: delta >= 0
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        child: Icon(delta >= 0 ? Icons.add : Icons.remove),
                      ),
                      title: Text('${delta >= 0 ? '+' : '-'}$quantity ${entry['unit']}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${DateFormat('d MMM yyyy, h:mm a').format(date)}\n${(entry['previousStock'] as num).toString()} → ${(entry['newStock'] as num).toString()} ${entry['unit']}'),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, [Color? valueColor]) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor({Product? product}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ManageProductScreen(product: product),
      ),
    );
    setState(() {}); // Refresh the list after returning from the edit screen
  }
}
