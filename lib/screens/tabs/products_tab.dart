import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
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
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      hintText: 'Search products...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Filters Row
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        value: category,
                        items: categories,
                        label: 'Category',
                        onChanged: (v) => setState(() => category = v ?? 'All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        value: subCategory,
                        items: subcats,
                        label: 'Sub-Category',
                        onChanged: (v) => setState(() => subCategory = v ?? 'All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        value: unitFilter,
                        items: [null, ...UnitType.values],
                        label: 'Unit',
                        onChanged: (v) => setState(() => unitFilter = v),
                        itemBuilder: (item) => Text(item == null ? 'All Units' : item.name.toUpperCase()),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Results Count
                Text(
                  '${filtered.length} products found',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Products List
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : _buildListView(filtered),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
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
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildListView(List<Product> products) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        final isLowStock = product.stock < 10;
        return _buildListCard(product, isLowStock);
      },
    );
  }





  Widget _buildListCard(Product product, bool isLowStock) {
    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
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
                          color: Colors.green,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLowStock ? Colors.orange[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${product.stock} ${product.unit.name}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isLowStock ? Colors.orange[800] : Colors.green[800],
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
                  icon: const Icon(Icons.edit, color: Colors.blue),
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
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.black87,
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
