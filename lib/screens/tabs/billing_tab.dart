import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/boxes.dart';
import '../../utils/platform_support.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/pdf_service.dart'; // Import the new PDF service
import '../../services/invoice_service.dart'; // Import for generateInvoice function
import '../../services/whatsapp_cloud_api_service.dart';
import '../edit_invoice_screen.dart'; // Added import for EditInvoiceScreen
import '../../widgets/shopping_cart_section.dart';
import '../../widgets/print_option_dialog.dart';
import '../barcode_scanner_screen.dart';

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
  final TextEditingController _barcodeInputController = TextEditingController();
  final TextEditingController _customerGstin = TextEditingController();
  bool _applyGst = false;
  bool _interstateSale = false;
  bool _gstInclusive = false;
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
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _errorColor => Theme.of(context).colorScheme.error;
  Color get _successColor => Colors.green.shade700;
  Color get _warningColor => Colors.orange.shade700;
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _cardColor => Theme.of(context).colorScheme.surface;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  bool get _gstAvailable {
    final settings = Hive.box<dynamic>('app_settings');
    final registration = settings
        .get('gst_registration_type', defaultValue: 'regular')
        .toString();
    return (settings.get('gst_enabled', defaultValue: false) as bool) &&
        registration == 'regular';
  }

  double get _gstRate =>
      (Hive.box<dynamic>('app_settings').get('gst_rate', defaultValue: 0.0)
              as num)
          .toDouble();
  double _money(double value) => (value * 100).roundToDouble() / 100;
  double get _subtotal =>
      _money(items.fold(0.0, (sum, item) => sum + item.subtotal));
  double _lineGrossAfterDiscount(SaleItem item) {
    if (_subtotal <= 0) return 0.0;
    final allocatedDiscount = _discount * item.subtotal / _subtotal;
    return _money((item.subtotal - allocatedDiscount)
        .clamp(0.0, double.infinity)
        .toDouble());
  }

  double _lineTaxableAmount(SaleItem item) {
    final gross = _lineGrossAfterDiscount(item);
    if (!_applyGst || !_gstInclusive) return gross;
    final rate = _lineGstRate(item);
    return rate <= 0 ? gross : _money(gross / (1 + rate / 100.0));
  }

  double get _taxableAmount => _applyGst
      ? _money(items.fold<double>(
          0.0, (sum, item) => sum + _lineTaxableAmount(item)))
      : _money((_subtotal - _discount).clamp(0.0, double.infinity).toDouble());
  double _lineTaxAmount(SaleItem item) {
    if (!_applyGst) return 0.0;
    final rate = _lineGstRate(item);
    final taxable = _lineTaxableAmount(item);
    return _gstInclusive
        ? _lineGrossAfterDiscount(item) - taxable
        : _money(taxable * rate / 100.0);
  }

  double _lineGstRate(SaleItem item) {
    final productRate =
        Hive.box<Product>(Boxes.products).get(item.productId)?.gstRate;
    return productRate ?? _gstRate;
  }

  double get _gstAmount => !_applyGst
      ? 0.0
      : _money(items.fold<double>(
          0.0,
          (sum, item) => sum + _lineTaxAmount(item),
        ));
  double _lineCgst(SaleItem item) =>
      _applyGst && !_interstateSale ? _money(_lineTaxAmount(item) / 2) : 0.0;
  double _lineSgst(SaleItem item) => _applyGst && !_interstateSale
      ? _money(_lineTaxAmount(item) - _lineCgst(item))
      : 0.0;
  double _lineIgst(SaleItem item) =>
      _applyGst && _interstateSale ? _lineTaxAmount(item) : 0.0;
  double get _cgstAmount =>
      _money(items.fold<double>(0.0, (sum, item) => sum + _lineCgst(item)));
  double get _sgstAmount =>
      _money(items.fold<double>(0.0, (sum, item) => sum + _lineSgst(item)));
  double get _igstAmount =>
      _money(items.fold<double>(0.0, (sum, item) => sum + _lineIgst(item)));
  double get _grandTotal => _money(_applyGst && _gstInclusive
      ? _subtotal - _discount
      : _taxableAmount + _gstAmount);
  double get _estimatedProfit => _taxableAmount - cost;

  @override
  void initState() {
    super.initState();
    _cartService = CartService();
    final gstSettings = Hive.box<dynamic>('app_settings');
    _gstInclusive =
        gstSettings.get('gst_price_inclusive', defaultValue: false) as bool;
    _interstateSale = gstSettings.get('gst_default_interstate_sale',
        defaultValue: false) as bool;
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
    _barcodeInputController.dispose();
    _customerGstin.dispose();
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
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor),
      ),
      fillColor: _cardColor,
      filled: true,
      labelStyle: TextStyle(color: _textSecondary, fontSize: 14),
      hintStyle:
          TextStyle(color: _textSecondary.withValues(alpha: 0.6), fontSize: 12),
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
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
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

  Widget _buildPaymentMethodTile(
      PaymentMethod method, String label, IconData icon) {
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
          color: isSelected ? _primaryColor.withValues(alpha: 0.1) : _cardColor,
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryColor : _textSecondary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
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

  Future<void> _handleScannedBarcode(String rawValue) async {
    final barcode = rawValue.trim();
    if (barcode.isEmpty) return;
    final products =
        Hive.box<Product>(Boxes.products).values.where((p) => p.active);
    Product? match;
    for (final product in products) {
      if (product.barcode?.trim() == barcode) {
        match = product;
        break;
      }
    }
    _barcodeInputController.clear();
    if (match == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'No product is assigned to barcode "$barcode". Add it in Product Management first.'),
        backgroundColor: _warningColor,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final product = match;
    final increment =
        (product.unit == UnitType.kg || product.unit == UnitType.sqft)
            ? 0.5
            : 1.0;
    if (!_canAddToCart(product, increment)) {
      _showStockLimitMessage(product.name, _getAvailableStock(product));
      return;
    }
    final item = SaleItem()
      ..productId = product.id
      ..qty = increment
      ..sellingPrice = product.sellingPrice
      ..costPrice = product.costPrice
      ..subtotal = product.sellingPrice * increment
      ..unitLabel = product.unit.name;
    _cartService.addItem(item);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added ${product.name} to the bill'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _openCameraBarcodeScanner() async {
    if (!isCameraScannerSupported) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Camera scanning is not available on this platform. Use a USB barcode scanner or type the barcode.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (value != null && mounted) await _handleScannedBarcode(value);
  }

  @override
  Widget build(BuildContext context) {
    final products = Hive.box<Product>(Boxes.products)
        .values
        .where((p) => p.active)
        .toList();
    final cur = NumberFormat.simpleCurrency(locale: 'en_IN');
    final invoiceSettings = Hive.box<dynamic>('app_settings');
    final savedPrefix = invoiceSettings
        .get('invoice_prefix', defaultValue: 'INV')
        .toString()
        .trim()
        .toUpperCase();
    final invoicePrefix = savedPrefix.isEmpty ? 'INV' : savedPrefix;
    final nextInvoiceNumber =
        (invoiceSettings.get('next_invoice_number', defaultValue: 1) as num)
            .toInt();
    final invoiceDatePart = DateFormat('yyyyMM').format(DateTime.now());
    final invoiceIdPreview =
        '$invoicePrefix-$invoiceDatePart-${nextInvoiceNumber.toString().padLeft(5, "0")}';

    // Get last 5 invoices, sorted by date and time (newest first)
    final salesBox = Hive.box<Sale>(Boxes.sales);
    final allSales = salesBox.values.toList();
    allSales.sort((a, b) {
      // Compare milliseconds since epoch to get precise date-time ordering
      return b.date.millisecondsSinceEpoch
          .compareTo(a.date.millisecondsSinceEpoch);
    });
    final recentSales = allSales.take(5).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                            _buildSectionHeader(
                                'Customer Information', Icons.person_outline),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _customerName,
                              decoration: _getInputDecoration(
                                label: 'Customer Name',
                                icon: Icons.person_outline,
                                hint: 'Optional',
                              ),
                              onChanged: (value) {
                                _cartService.updateCustomerInfo(
                                    value, _customerPhone.text);
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
                                _cartService.updateCustomerInfo(
                                    _customerName.text, value);
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildSectionHeader(
                                'Payment Method', Icons.payment_outlined),
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

                    // Barcode input: camera or external scanner in keyboard-wedge mode.
                    Card(
                      elevation: 0,
                      color: _cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                                'Barcode Scanner', Icons.qr_code_scanner),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _barcodeInputController,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: _handleScannedBarcode,
                                    decoration: _getInputDecoration(
                                      label: 'Scan or enter barcode',
                                      icon: Icons.qr_code_2,
                                      hint:
                                          'External scanner works like a keyboard',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  tooltip: 'Scan with camera',
                                  onPressed: _openCameraBarcodeScanner,
                                  icon: const Icon(Icons.camera_alt),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'For USB/Bluetooth scanners, focus this field and scan. Most scanners submit the code with Enter.',
                              style: TextStyle(
                                  fontSize: 12, color: _textSecondary),
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
                        _customerGstin.clear();
                        _applyGst = false;
                        _interstateSale = false;
                      },
                      onAddProduct: (product) {
                        // Logic to add product using CartService
                        final increment = (product.unit == UnitType.kg ||
                                product.unit == UnitType.sqft)
                            ? 0.5
                            : 1.0;

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
                          _showStockLimitMessage(
                              product.name, _getAvailableStock(product));
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
                              _buildSectionHeader(
                                  'Order Summary', Icons.receipt_long_outlined),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _discountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: _getInputDecoration(
                                  label: 'Discount Amount',
                                  icon: Icons.discount_outlined,
                                  hint: 'Enter discount amount (optional)',
                                ),
                                onChanged: (value) {
                                  final discount =
                                      double.tryParse(value) ?? 0.0;
                                  final clampedDiscount =
                                      discount.clamp(0.0, _subtotal);
                                  _cartService.updateDiscount(clampedDiscount);
                                },
                              ),
                              const SizedBox(height: 12),
                              if (_gstAvailable) ...[
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Apply GST'),
                                  subtitle: const Text(
                                      'Tax is calculated after discount.'),
                                  value: _applyGst,
                                  onChanged: (value) => setState(() {
                                    _applyGst = value;
                                    if (value) {
                                      _gstInclusive =
                                          Hive.box<dynamic>('app_settings').get(
                                              'gst_price_inclusive',
                                              defaultValue: false) as bool;
                                    }
                                  }),
                                ),
                                if (_applyGst) ...[
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Interstate sale (IGST)'),
                                    subtitle: const Text(
                                        'Leave unchecked for CGST + SGST.'),
                                    value: _interstateSale,
                                    onChanged: (value) => setState(
                                        () => _interstateSale = value ?? false),
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                        'Prices already include GST'),
                                    subtitle: const Text(
                                        'If enabled, GST is extracted from the listed price instead of added on top.'),
                                    value: _gstInclusive,
                                    onChanged: (value) => setState(
                                        () => _gstInclusive = value ?? false),
                                  ),
                                  TextField(
                                    controller: _customerGstin,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: _getInputDecoration(
                                      label: 'Customer GSTIN (optional)',
                                      icon: Icons.verified_outlined,
                                      hint: 'For B2B invoices',
                                    ),
                                  ),
                                ],
                              ] else
                                Text(
                                  'GST is disabled. An admin can configure it in Invoice & GST Settings.',
                                  style: TextStyle(
                                      fontSize: 12, color: _textSecondary),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Invoice ID',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: _textSecondary),
                                        ),
                                        Text(
                                          invoiceIdPreview,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Subtotal',
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          cur.format(_subtotal),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Estimated Profit',
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          cur.format(_estimatedProfit),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: _successColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_discount > 0)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Discount'),
                                          Text('-${cur.format(_discount)}'),
                                        ],
                                      ),
                                    if (_applyGst) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Taxable value'),
                                            Text(cur.format(_taxableAmount))
                                          ]),
                                      if (!_interstateSale) ...[
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('CGST'),
                                              Text(cur.format(_cgstAmount))
                                            ]),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('SGST'),
                                              Text(cur.format(_sgstAmount))
                                            ]),
                                      ] else
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('IGST'),
                                              Text(cur.format(_igstAmount))
                                            ]),
                                    ],
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total Amount',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          cur.format(_grandTotal),
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: _primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Balance',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          cur.format(_grandTotal),
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: _primaryColor),
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
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
                            _buildSectionHeader(
                                'Invoice History', Icons.history),
                            const SizedBox(height: 16),
                            if (recentSales.isEmpty)
                              const Center(child: Text('No recent invoices.'))
                            else
                              ...recentSales.map((sale) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 0,
                                  color: _surfaceColor,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Invoice ID: ${sale.id}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(
                                            DateFormat('MMM dd, yyyy - hh:mm a')
                                                .format(sale.date),
                                            style: TextStyle(
                                                color: _textSecondary)),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              cur.format(sale.totalAmount),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: _primaryColor),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.print,
                                                      color: _primaryColor),
                                                  onPressed: () async {
                                                    final printOption =
                                                        await showPrintOptionDialog(
                                                            context, sale);
                                                    if (printOption != null) {
                                                      await _handlePrintInvoice(
                                                          sale, printOption);
                                                    }
                                                  },
                                                  tooltip: 'Print Invoice',
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.edit,
                                                      color: _primaryColor),
                                                  onPressed: () async {
                                                    final result =
                                                        await Navigator.of(
                                                                context)
                                                            .push(
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            EditInvoiceScreen(
                                                                sale: sale),
                                                      ),
                                                    );
                                                    if (result == true) {
                                                      setState(() {});
                                                    }
                                                  },
                                                  tooltip: 'Edit Invoice',
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.delete,
                                                      color: _errorColor),
                                                  onPressed: () async {
                                                    final confirm =
                                                        await showDialog<bool>(
                                                              context: context,
                                                              builder: (ctx) =>
                                                                  AlertDialog(
                                                                title: const Text(
                                                                    'Delete Invoice?'),
                                                                content: Text(
                                                                    'Are you sure you want to delete invoice ${sale.id}?'),
                                                                actions: [
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              ctx,
                                                                              false),
                                                                      child: const Text(
                                                                          'Cancel')),
                                                                  ElevatedButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              ctx,
                                                                              true),
                                                                      child: const Text(
                                                                          'Delete')),
                                                                ],
                                                              ),
                                                            ) ??
                                                            false;
                                                    if (confirm) {
                                                      await _deleteInvoice(
                                                          sale);
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
                              }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
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
      final productsBox = Hive.box<Product>(Boxes.products);
      for (final item in items) {
        final product = productsBox.get(item.productId);
        final taxable = _lineTaxableAmount(item);
        final rate = _applyGst ? _lineGstRate(item) : 0.0;
        item
          ..hsnCode = product?.hsnCode ?? ''
          ..gstRate = rate
          ..taxableAmount = taxable
          ..cgstAmount = _lineCgst(item)
          ..sgstAmount = _lineSgst(item)
          ..igstAmount = _lineIgst(item);
      }
      final salesBox = Hive.box<Sale>(Boxes.sales);
      final invoiceSettings = Hive.box<dynamic>('app_settings');
      final prefix = invoiceSettings
          .get('invoice_prefix', defaultValue: 'INV')
          .toString()
          .trim()
          .toUpperCase();
      final safePrefix = prefix.isEmpty ? 'INV' : prefix;
      final nextNumber =
          (invoiceSettings.get('next_invoice_number', defaultValue: 1) as num)
              .toInt();
      final datePart = DateFormat('yyyyMM').format(DateTime.now());
      final id =
          '$safePrefix-$datePart-${nextNumber.toString().padLeft(5, "0")}';
      await invoiceSettings.put('next_invoice_number', nextNumber + 1);

      final sale = Sale()
        ..id = id
        ..date = DateTime.now()
        ..items = items.map((e) => e).toList()
        ..totalAmount = _grandTotal
        ..totalCost = cost
        ..profit = _estimatedProfit
        ..payment = _method
        ..customerName = _customerName.text.trim()
        ..customerPhone = _customerPhone.text.trim()
        ..discount = _discount
        ..gstEnabled = _applyGst
        ..gstRate = _applyGst ? _gstRate : 0.0
        ..taxableAmount = _taxableAmount
        ..cgstAmount = _cgstAmount
        ..sgstAmount = _sgstAmount
        ..igstAmount = _igstAmount
        ..customerGstin = _customerGstin.text.trim().toUpperCase()
        ..interstateSale = _interstateSale
        ..gstInclusive = _applyGst && _gstInclusive
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

        final sendOnWhatsApp = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Send invoice on WhatsApp?'),
            content: Text('Send invoice ${sale.id} as a PDF to ${sale.customerPhone}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.send),
                label: const Text('Send PDF'),
              ),
            ],
          ),
        );
        if (sendOnWhatsApp == true && mounted) {
          await _sendInvoiceOnWhatsApp(sale);
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
                      Text('Invoice ID: $id',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: _successColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Future<void> _sendInvoiceOnWhatsApp(Sale sale) async {
    final settings = Hive.box<dynamic>('app_settings');
    try {
      final pdfBytes = await PdfService.generateInvoice(
        sale,
        includeGST: sale.gstEnabled,
      );
      final messageId = await WhatsappCloudApiService().sendInvoice(
        backendUrl: settings.get('whatsapp_backend_url', defaultValue: '').toString(),
        apiKey: settings.get('whatsapp_api_key', defaultValue: '').toString(),
        phone: sale.customerPhone,
        invoiceId: sale.id,
        pdfBytes: pdfBytes,
        filename: 'invoice_${sale.id}.pdf',
        caption: 'Thank you ${sale.customerName.isEmpty ? "for your purchase" : sale.customerName}. Your Billit invoice ${sale.id} is attached.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice accepted by WhatsApp. Message ID: $messageId')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp invoice failed: $e'), backgroundColor: _errorColor),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else {
        // Non-GST sales should go straight to a normal invoice PDF.
        // Only GST-enabled sales need a choice between normal and tax invoice.
        var includeGst = false;
        if (sale.gstEnabled) {
          final selectedType = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Choose PDF type'),
              content: const Text(
                  'Choose whether to generate a normal invoice or a GST tax invoice.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Normal PDF'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('GST Tax Invoice'),
                ),
              ],
            ),
          );
          if (selectedType == null) return;
          includeGst = selectedType;
        }

        final sharePdf = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Invoice PDF'),
            content: const Text('How would you like to send the invoice?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Save PDF'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share PDF'),
              ),
            ],
          ),
        );
        if (sharePdf == null) return;
        await PdfService.generateInvoice(
          sale,
          includeGST: includeGst,
          share: sharePdf,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(sharePdf
                      ? 'Invoice PDF ready to share!'
                      : 'Invoice PDF saved!'),
                ],
              ),
              backgroundColor: _successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
