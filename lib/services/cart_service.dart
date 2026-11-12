import 'package:flutter/foundation.dart';
import '../models/models.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<SaleItem> _items = [];
  // Loyalty "free product" lines. Tracked by identity so they never merge with
  // a paid line of the same product.
  final Set<SaleItem> _freeItems = Set<SaleItem>.identity();
  String _customerName = '';
  String _customerPhone = '';
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  double _discount = 0.0;

  // Getters
  List<SaleItem> get items => List.unmodifiable(_items);
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  PaymentMethod get paymentMethod => _paymentMethod;
  double get discount => _discount;

  // Cart calculations
  double get total => _items.fold(0.0, (a, it) => a + it.subtotal) - _discount;
  double get cost => _items.fold(0.0, (a, it) => a + (it.costPrice * it.qty));
  double get profit => total - cost;
  int get itemCount => _items.fold(0, (a, it) => a + it.qty.ceil());

  // Cart operations
  void addItem(SaleItem item) {
    final existingIndex = _items.indexWhere(
        (i) => i.productId == item.productId && !_freeItems.contains(i));
    if (existingIndex != -1) {
      _items[existingIndex].qty += item.qty;
      _items[existingIndex].subtotal =
          _items[existingIndex].qty * _items[existingIndex].sellingPrice;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void updateItem(int index, SaleItem updatedItem) {
    if (index >= 0 && index < _items.length) {
      _items[index] = updatedItem;
      notifyListeners();
    }
  }

  /// Adds [item] at zero price as a loyalty reward line.
  void addFreeItem(SaleItem item) {
    item
      ..sellingPrice = 0
      ..subtotal = 0;
    _freeItems.add(item);
    _items.add(item);
    notifyListeners();
  }

  bool get hasFreeItem => _freeItems.isNotEmpty;

  /// Removes any loyalty reward lines from the cart.
  void removeFreeItems() {
    if (_freeItems.isEmpty) return;
    _items.removeWhere(_freeItems.contains);
    _freeItems.clear();
    notifyListeners();
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _freeItems.remove(_items[index]);
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _freeItems.clear();
    _customerName = '';
    _customerPhone = '';
    _paymentMethod = PaymentMethod.cash;
    _discount = 0.0;
    notifyListeners();
  }

  // Customer and payment info
  void updateCustomerInfo(String name, String phone) {
    _customerName = name;
    _customerPhone = phone;
    notifyListeners();
  }

  void updatePaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void updateDiscount(double discount) {
    _discount = discount;
    notifyListeners();
  }

  // Check if product can be added to cart
  bool canAddToCart(Product product, double quantityToAdd) {
    final cartQuantity = getCartQuantity(product.id);
    return (product.stock - cartQuantity) >= quantityToAdd;
  }

  // Get current cart quantity for a product
  double getCartQuantity(String productId) {
    // Sum every line of the product (a free reward line counts against stock).
    return _items
        .where((item) => item.productId == productId)
        .fold<double>(0, (sum, item) => sum + item.qty);
  }

  // Get available stock for a product (stock - cart quantity)
  double getAvailableStock(Product product) {
    return product.stock - getCartQuantity(product.id);
  }
}
