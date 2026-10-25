import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/models.dart';
import '../../services/boxes.dart';

class ProductSelectionScreen extends StatefulWidget {
  ProductSelectionScreen({super.key});

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  UnitType? _selectedUnitType;
  bool _showOnlyInStock = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    _slideController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = null;
      _selectedUnitType = null;
      _showOnlyInStock = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Ensures resizing when keyboard appears
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Select Products',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear filters',
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap outside
          child: CustomScrollView(
            slivers: [
              // Fixed filters and search area
              SliverToBoxAdapter(
                child: Material(
                  color: theme.primaryColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSearchSection(theme, isTablet),
                      _buildFilterSection(theme, isTablet),
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Scrollable products list that adjusts to keyboard
              SliverFillRemaining(
                child: _buildProductsList(theme, isTablet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products by name...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(Icons.search, color: theme.primaryColor, size: 24),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme, bool isTablet) {
    final productsBox = Hive.box<Product>(Boxes.products);
    final categories = productsBox.values.map((p) => p.category).toSet().toList()..sort();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.0 : 16.0,
        vertical: 8.0,
      ),
      child: Column(
        children: [
          // Filter chips row
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  'Category',
                  _selectedCategory ?? 'All Categories',
                  Icons.category,
                  () => _showCategoryPicker(categories),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterChip(
                  'Unit',
                  _selectedUnitType?.name ?? 'All Units',
                  Icons.straighten,
                  () => _showUnitPicker(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stock filter
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: CheckboxListTile(
              title: const Text(
                'Show only in-stock items',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              value: _showOnlyInStock,
              onChanged: (value) {
                setState(() {
                  _showOnlyInStock = value ?? false;
                });
              },
              checkColor: theme.primaryColor,
              activeColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(List<String> categories) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Category',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ...['All Categories', ...categories].map((category) {
                final isSelected = category == 'All Categories'
                    ? _selectedCategory == null
                    : _selectedCategory == category;
                return ListTile(
                  title: Text(category),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: Theme.of(context).primaryColor,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category == 'All Categories' ? null : category;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showUnitPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Unit Type',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ...[null, ...UnitType.values].map((unitType) {
                final label = unitType?.name ?? 'All Units';
                final isSelected = _selectedUnitType == unitType;
                return ListTile(
                  title: Text(label),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: Theme.of(context).primaryColor,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedUnitType = unitType;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsList(ThemeData theme, bool isTablet) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Product>(Boxes.products).listenable(),
      builder: (context, Box<Product> box, _) {
        final products = box.values.where((p) => p.active).toList();
        final filteredProducts = products.where((p) {
          final matchesSearchQuery = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesCategory = _selectedCategory == null || p.category == _selectedCategory;
          final matchesUnitType = _selectedUnitType == null || p.unit == _selectedUnitType;
          final matchesStock = !_showOnlyInStock || p.stock > 0;
          return matchesSearchQuery && matchesCategory && matchesUnitType && matchesStock;
        }).toList();

        if (filteredProducts.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: [
            // Results header
            Container(
              padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
              child: Row(
                children: [
                  Text(
                    '${filteredProducts.length} product${filteredProducts.length == 1 ? '' : 's'} found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters())
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                ],
              ),
            ),

            // Products grid/list - now scrollable within available space
            Flexible(
              child: isTablet
                  ? _buildProductsGrid(filteredProducts, theme)
                  : _buildProductsListView(filteredProducts, theme),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductsGrid(List<Product> products, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product, theme, isGrid: true);
      },
    );
  }

  Widget _buildProductsListView(List<Product> products, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 100 + (index * 50)),
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildProductCard(product, theme, isGrid: false),
        );
      },
    );
  }

  Widget _buildProductCard(Product product, ThemeData theme, {required bool isGrid}) {
    final isOutOfStock = product.stock <= 0;
    final isLowStock = product.stock > 0 && product.stock <= 5;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isOutOfStock ? null : () {
          Navigator.of(context).pop(product);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isOutOfStock ? Colors.grey.shade100 : Colors.white,
          ),
          child: isGrid ? _buildGridContent(product, theme, isOutOfStock, isLowStock)
              : _buildListContent(product, theme, isOutOfStock, isLowStock),
        ),
      ),
    );
  }

  Widget _buildGridContent(Product product, ThemeData theme, bool isOutOfStock, bool isLowStock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isOutOfStock ? Colors.grey : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildStockBadge(product, isOutOfStock, isLowStock),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          product.category,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${product.sellingPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isOutOfStock ? Colors.grey : theme.primaryColor,
                  ),
                ),
                Text(
                  'per ${product.unit.name}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: isOutOfStock ? Colors.grey.shade300 : theme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  isOutOfStock ? Icons.block : Icons.add_shopping_cart,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: isOutOfStock ? null : () {
                  Navigator.of(context).pop(product);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListContent(Product product, ThemeData theme, bool isOutOfStock, bool isLowStock) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.inventory_2,
            color: theme.primaryColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isOutOfStock ? Colors.grey : Colors.black87,
                      ),
                    ),
                  ),
                  _buildStockBadge(product, isOutOfStock, isLowStock),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                product.category,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '₹${product.sellingPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isOutOfStock ? Colors.grey : theme.primaryColor,
                    ),
                  ),
                  Text(
                    ' per ${product.unit.name}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isOutOfStock ? Colors.grey.shade300 : theme.primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              isOutOfStock ? Icons.block : Icons.add_shopping_cart,
              color: Colors.white,
            ),
            onPressed: isOutOfStock ? null : () {
              Navigator.of(context).pop(product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStockBadge(Product product, bool isOutOfStock, bool isLowStock) {
    if (isOutOfStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Out of Stock',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (isLowStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Low: ${product.stock.toInt()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${product.stock.toInt()} in stock',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
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
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _selectedCategory != null ||
        _selectedUnitType != null ||
        _showOnlyInStock;
  }
}
