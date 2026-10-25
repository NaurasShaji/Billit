import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/boxes.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/pdf_service.dart'; // Import the new PDF service
import '../../services/invoice_service.dart'; // Import for generateInvoice function
import '../edit_invoice_screen.dart'; // Added import for EditInvoiceScreen
import '../../widgets/shopping_cart_section.dart';
import '../../widgets/print_option_dialog.dart';

const _primaryColor = Color(0xFF1565C0); // Blue 800
const _errorColor = Color(0xFFD32F2F); // Red 700
const _successColor = Color(0xFF388E3C); // Green 700
const _warningColor = Color(0xFFF57C00); // Orange 700
const _surfaceColor = Color(0xFFFAFAFA); // Grey 50
const _cardColor = Colors.white;
const _textPrimary = Color(0xFF212121); // Grey 900
const _textSecondary = Color(0xFF757575); // Grey 600

class BillingTab extends StatefulWidget {
  const BillingTab({super.key});
  @override
  State<BillingTab> createState() => _BillingTabState();
}

class _BillingTabState extends State<BillingTab> with TickerProviderStateMixin {
  late CartService _cartService;
  final TextEditingController _customerName = TextEditingController();
  final TextEditingController _customerPhone = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  // Add these getters that delegate to CartService
  List<SaleItem> get items => _cartService.items;
  PaymentMethod get _method => _cartService.paymentMethod;
  double get _discount => _cartService.discount;
  double get total => _cartService.total;
  double get cost => _cartService.cost;
  double get profit => _cartService.profit;
  int get itemCount => _cartService.itemCount;

  @override
  void initState() {
    super.initState();
    _cartService = CartService();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
    _animationController?.forward();
    
    // Initialize controllers with cart service data
    _customerName.text = _cartService.customerName;
    _customerPhone.text = _cartService.customerPhone;
    _discountController.text = _cartService.discount.toString();
    
    // Listen to cart changes
    _cartService.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    _animationController?.dispose();
    _customerName.dispose();
    _customerPhone.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // Get current cart quantity for a product
  double _getCartQuantity(String productId) {
    return _cartService.getCartQuantity(productId);
  }

  // Get available stock for a product (stock - cart quantity)
  double _getAvailableStock(Product product) {
    return _cartService.getAvailableStock(product);
  }

  // Check if we can add more quantity to cart
  bool _canAddToCart(Product product, double quantityToAdd) {
    return _cartService.canAddToCart(product, quantityToAdd);
  }

  InputDecoration _getInputDecoration({
    required String label, 
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primaryColor, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _errorColor),
      ),
      fillColor: _cardColor,
      filled: true,
      labelStyle: TextStyle(color: _textSecondary, fontSize: 14),
      hintStyle: TextStyle(color: _textSecondary.withOpacity(0.6), fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Widget? action}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethod method, String label, IconData icon) {
    final isSelected = _method == method;
    return InkWell(
      onTap: () {
        _cartService.updatePaymentMethod(method);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.1) : _cardColor,
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
              color: isSelected ? _primaryColor : _textSecondary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(label,
              style: TextStyle(
                color: isSelected ? _primaryColor : _textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showStockLimitMessage(String productName, double availableStock) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cannot add $productName. Only ${availableStock.toStringAsFixed(1)} units available.',
              ),
            ),
          ],
        ),
        backgroundColor: _warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = Hive.box<Product>(Boxes.products).values.where((p) => p.active).toList();
    final cur = NumberFormat.simpleCurrency(locale: 'en_IN');

      // Get last 5 invoices, sorted by date and time (newest first)
      final salesBox = Hive.box<Sale>(Boxes.sales);
      final allSales = salesBox.values.toList();
      allSales.sort((a, b) {
        // Compare milliseconds since epoch to get precise date-time ordering
        return b.date.millisecondsSinceEpoch.compareTo(a.date.millisecondsSinceEpoch);
      });
      final recentSales = allSales.take(5).toList();

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: null,
      body: _fadeAnimation != null 
        ? FadeTransition(
            opacity: _fadeAnimation!,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Details Section
                  Card(
                    elevation: 0,
                    color: _cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Customer Information', Icons.person_outline),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _customerName,
                            decoration: _getInputDecoration(
                              label: 'Customer Name',
                              icon: Icons.person_outline,
                              hint: 'Optional',
                            ),
                            onChanged: (value) {
                              _cartService.updateCustomerInfo(value, _customerPhone.text);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _customerPhone,
                            keyboardType: TextInputType.phone,
                            decoration: _getInputDecoration(
                              label: 'Phone Number',
                              icon: Icons.phone_outlined,
                              hint: 'Optional',
                            ),
                            onChanged: (value) {
                              _cartService.updateCustomerInfo(_customerName.text, value);
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildSectionHeader('Payment Method', Icons.payment_outlined),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaymentMethodTile(
                                  PaymentMethod.cash,
                                  'Cash',
                                  Icons.payments_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPaymentMethodTile(
                                  PaymentMethod.card,
                                  'Card',
                                  Icons.credit_card_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPaymentMethodTile(
                                  PaymentMethod.upi,
                                  'UPI',
                                  Icons.qr_code_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Add Product and Shopping Cart Section
                  ShoppingCartSection(
                    items: items,
                    products: products,
                    onClearAll: () {
                      _cartService.clearCart();
                      _customerName.clear();
                      _customerPhone.clear();
                      _discountController.clear();
                    },
                    onAddProduct: (product) {
                      // Logic to add product using CartService
                      final increment = (product.unit == UnitType.kg || product.unit == UnitType.sqft) ? 0.5 : 1.0;
                      
                      if (_canAddToCart(product, increment)) {
                        final item = SaleItem()
                          ..productId = product.id
                          ..qty = increment
                          ..sellingPrice = product.sellingPrice
                          ..costPrice = product.costPrice
                          ..subtotal = product.sellingPrice * increment
                          ..unitLabel = product.unit.name;
                        _cartService.addItem(item);
                      } else {
                        _showStockLimitMessage(product.name, _getAvailableStock(product));
                      }
                    },
                    onUpdateCartItem: (item, product, index) {
                      // Update item through CartService
                      item.subtotal = item.qty * item.sellingPrice;
                      _cartService.updateItem(index, item);
                    },
                    onRemoveCartItem: (item, product, index) {
                      _cartService.removeItem(index);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Checkout Section
                  if (items.isNotEmpty)
                    Card(
                      elevation: 0,
                      color: _cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Order Summary', Icons.receipt_long_outlined),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _discountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: _getInputDecoration(
                                label: 'Discount Amount',
                                icon: Icons.discount_outlined,
                                hint: 'Enter discount amount (optional)',
                              ),
                              onChanged: (value) {
                                final discount = double.tryParse(value) ?? 0.0;
                                final clampedDiscount = discount.clamp(0.0, total);
                                _cartService.updateDiscount(clampedDiscount);
                              },
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Invoice ID',
                                        style: TextStyle(fontSize: 14, color: _textSecondary),
                                      ),
                                      Text(
                                        DateFormat('yyMMdd-HHmm').format(DateTime.now()),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Subtotal',
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        cur.format(total),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Estimated Profit',
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        cur.format(profit),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _successColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total Amount',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        cur.format(total),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: _primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Balance',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        cur.format(total - _discount),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _primaryColor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _handleCheckout,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text(
                                  'Complete Sale',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Invoice Management Section
                  Card(
                    elevation: 0,
                    color: _cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Invoice History', Icons.history),
                          const SizedBox(height: 16),
                          if (recentSales.isEmpty)
                            const Center(child: Text('No recent invoices.'))
                          else
                            ...recentSales.map((sale) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                color: _surfaceColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Invoice ID: ${sale.id}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(DateFormat('MMM dd, yyyy - hh:mm a').format(sale.date), style: TextStyle(color: _textSecondary)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            cur.format(sale.totalAmount),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryColor),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.print, color: _primaryColor),
                                                onPressed: () async {
                                                  final printOption = await showPrintOptionDialog(context, sale);
                                                  if (printOption != null) {
                                                    await _handlePrintInvoice(sale, printOption);
                                                  }
                                                },
                                                tooltip: 'Print Invoice',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: _primaryColor),
                                                onPressed: () async {
                                                  final result = await Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) => EditInvoiceScreen(sale: sale),
                                                    ),
                                                  );
                                                  if (result == true) {
                                                    setState(() {});
                                                  }
                                                },
                                                tooltip: 'Edit Invoice',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: _errorColor),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Delete Invoice?'),
                                                      content: Text('Are you sure you want to delete invoice ${sale.id}?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                                      ],
                                                    ),
                                                  ) ?? false;
                                                  if (confirm) {
                                                    await _deleteInvoice(sale);
                                                  }
                                                },
                                                tooltip: 'Delete Invoice',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ) : const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _handleCheckout() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing sale...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final salesBox = Hive.box<Sale>(Boxes.sales);
      final productsBox = Hive.box<Product>(Boxes.products);
      final id = const Uuid().v4().substring(0, 8).toUpperCase();

      final sale = Sale()
        ..id = id
        ..date = DateTime.now()
        ..items = items.map((e) => e).toList()
        ..totalAmount = total
        ..totalCost = cost
        ..profit = profit
        ..payment = _method
        ..customerName = _customerName.text.trim()
        ..customerPhone = _customerPhone.text.trim()
        ..discount = _discount
        ..userId = context.read<AuthService>().currentUser?.id ?? '';

      await salesBox.put(sale.id, sale);

      // Update product stock
      for (final item in items) {
        final product = productsBox.get(item.productId);
        if (product != null) {
          product.stock = (product.stock - item.qty).clamp(0, double.infinity);
          await product.save();
        }
      }
      
      // Show print option selection dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        final printOption = await showPrintOptionDialog(context, sale);

        if (printOption != null) {
          await _handlePrintInvoice(sale, printOption);
        }
        
        _cartService.clearCart();
        _customerName.clear();
        _customerPhone.clear();
        _discountController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sale completed successfully!'),
                      Text('Invoice ID: $id', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: _successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing sale: $e'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Handle printing invoice based on selected option
  Future<void> _handlePrintInvoice(Sale sale, PrintOption printOption) async {
    try {
      final invoiceService = InvoiceService();
      
      if (printOption == PrintOption.thermal) {
        // Generate thermal printer format
        await invoiceService.generateInvoice(sale, useThermalPrinter: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Thermal format generated successfully!'),
                ],
              ),
              backgroundColor: _successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else {
        // Generate PDF
        await invoiceService.generateInvoice(sale, useThermalPrinter: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('PDF invoice generated successfully!'),
                ],
              ),
              backgroundColor: _successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating invoice: $e'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  // New method to delete an invoice
  Future<void> _deleteInvoice(Sale sale) async {
    final salesBox = Hive.box<Sale>(Boxes.sales);
    final productsBox = Hive.box<Product>(Boxes.products);

    // Remove sale from Hive
    await salesBox.delete(sale.id);

    // Update product stocks
    for (final item in sale.items) {
      final product = productsBox.get(item.productId);
      if (product != null) {
        product.stock = (product.stock + item.qty).clamp(0, double.infinity);
        await product.save();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Invoice ${sale.id} deleted successfully.',
              ),
            ),
          ],
        ),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    setState(() {}); // Refresh the UI
  }
}
