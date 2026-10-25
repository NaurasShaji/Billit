import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../screens/product_selection_screen.dart';

const _primaryColor = Color(0xFF1565C0); // Blue 800
const _errorColor = Color(0xFFD32F2F); // Red 700

// Assuming these are defined in your models/ folder
// import '../models/product.dart';
// import '../models/sale.dart';

class ShoppingCartSection extends StatelessWidget {
  final List<SaleItem> items;
  final List<Product> products;
  final VoidCallback onClearAll;
  final Function(Product) onAddProduct;
  final Function(SaleItem, Product, int) onUpdateCartItem;
  final Function(SaleItem, Product, int) onRemoveCartItem;

  const ShoppingCartSection({
    Key? key,
    required this.items,
    required this.products,
    required this.onClearAll,
    required this.onAddProduct,
    required this.onUpdateCartItem,
    required this.onRemoveCartItem,
  }) : super(key: key);

  int get itemCount => items.fold(0, (sum, item) => sum + item.qty.toInt());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _CartContent(
              items: items,
              products: products,
              onAddProduct: onAddProduct,
              onUpdateCartItem: onUpdateCartItem,
              onRemoveCartItem: onRemoveCartItem,
              onClearAll: onClearAll,
              itemCount: itemCount,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _handleAddProduct(context, onAddProduct),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text(
                  'Add Product',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleAddProduct(BuildContext context, Function(Product) onAddProduct) async {
    try {
      final selectedProduct = await Navigator.of(context).push<Product>(
        MaterialPageRoute(
          builder: (context) => ProductSelectionScreen(),
        ),
      );

      if (selectedProduct != null) {
        onAddProduct(selectedProduct);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error selecting product. Please try again.'),
        ),
      );
    }
  }
}

class _CartContent extends StatelessWidget {
  final List<SaleItem> items;
  final List<Product> products;
  final Function(Product) onAddProduct;
  final Function(SaleItem, Product, int) onUpdateCartItem;
  final Function(SaleItem, Product, int) onRemoveCartItem;
  final VoidCallback onClearAll;
  final int itemCount;

  const _CartContent({
    required this.items,
    required this.products,
    required this.onAddProduct,
    required this.onUpdateCartItem,
    required this.onRemoveCartItem,
    required this.onClearAll,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Items ($itemCount)',
          icon: Icons.shopping_cart_outlined,
          action: items.isNotEmpty ? _buildClearAllButton(context) : null,
        ),
        const SizedBox(height: 16),
        items.isEmpty ? _buildEmptyCart(context) : _buildCartItems(),
      ],
    );
  }

  Widget _buildClearAllButton(BuildContext context) {
    return TextButton.icon(
      onPressed: onClearAll,
      icon: const Icon(Icons.clear, size: 18),
      label: const Text('Clear All'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No items added yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding products to your cart',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        try {
          final product = products.firstWhere(
            (e) => e.id == item.productId,
            orElse: () => throw StateError('Product not found'),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CartItemWidget(
              item: item,
              product: product,
              index: index,
              onUpdate: onUpdateCartItem,
              onRemove: onRemoveCartItem,
            ),
          );
        } catch (e) {
          // Handle case where product is not found
          return const SizedBox.shrink();
        }
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _CartItemWidget extends StatelessWidget {
  final SaleItem item;
  final Product product;
  final int index;
  final Function(SaleItem, Product, int) onUpdate;
  final Function(SaleItem, Product, int) onRemove;

  const _CartItemWidget({
    required this.item,
    required this.product,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final availableStock = product.stock; // simplified for this widget, actual check in parent
    // final increment = product.unit == UnitType.kg ? 0.5 : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${product.category}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Stock: ${availableStock == availableStock.toInt() ? availableStock.toInt().toString() : availableStock.toString()} ${product.unit.name}',
                      style: TextStyle(
                        color: availableStock <= 0 ? _errorColor : Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: _errorColor),
                onPressed: () => onRemove(item, product, index),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Unit Price
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit Price',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 100,
                    height: 40,
                    child: TextFormField(
                      initialValue: item.sellingPrice.toStringAsFixed(2),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '₹',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _primaryColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      ),
                      onChanged: (value) {
                        final newPrice = double.tryParse(value) ?? 0.0;
                        onUpdate(item..sellingPrice = newPrice ..subtotal = item.qty * newPrice, product, index);
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              ),
              const SizedBox(width: 8),
              // Quantity Controls
              SizedBox(
                width: 150,
                child: _QuantityControls(
                  quantity: item.qty,
                  unit: product.unit,
                  onQuantityChanged: (newQty) {
                    if (newQty > item.qty && availableStock - (newQty - item.qty) < 0) {
                      return;
                    }
                    onUpdate(item..qty = newQty ..subtotal = newQty * item.sellingPrice, product, index);
                  },
                ),
              ),

            ],
          ),
          const SizedBox(height: 16),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.simpleCurrency(locale: 'en_IN').format(item.subtotal),
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityControls extends StatefulWidget {
  final double quantity;
  final UnitType unit;
  final Function(double) onQuantityChanged;

  const _QuantityControls({
    Key? key,
    required this.quantity,
    required this.unit,
    required this.onQuantityChanged,
  }) : super(key: key);

  @override
  State<_QuantityControls> createState() => _QuantityControlsState();
}

class _QuantityControlsState extends State<_QuantityControls> {
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: _formatQuantity(widget.quantity));
  }

  @override
  void didUpdateWidget(covariant _QuantityControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if the controller is empty or the quantity changed significantly
    // This prevents overriding user input while typing
    if (widget.quantity != oldWidget.quantity && 
        (_quantityController.text.isEmpty || 
         double.tryParse(_quantityController.text) != widget.quantity)) {
      _quantityController.text = _formatQuantity(widget.quantity);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  String _formatQuantity(double qty) {
    // Let user control the format - don't force decimal places
    if (qty == qty.toInt()) {
      return qty.toInt().toString();
    } else {
      return qty.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final increment = (widget.unit == UnitType.kg || widget.unit == UnitType.sqft) ? 0.5 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: widget.quantity > 0
                    ? () => widget.onQuantityChanged((widget.quantity - increment).clamp(0, double.infinity))
                    : null,
                icon: const Icon(Icons.remove),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    // Don't update while user is actively typing
                    if (value.isEmpty) {
                      widget.onQuantityChanged(0);
                      return;
                    }
                    
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed != null && parsed >= 0) {
                      widget.onQuantityChanged(parsed);
                    }
                    // If parsing fails, don't update - let user continue typing
                  },
                ),
              ),
              IconButton(
                onPressed: () => widget.onQuantityChanged(widget.quantity + increment),
                icon: const Icon(Icons.add),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: onPressed != null
          ? theme.primaryColor
          : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null ? Colors.white : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
