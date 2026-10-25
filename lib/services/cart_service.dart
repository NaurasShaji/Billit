import 'package:flutter/foundation.dart';
import '../models/models.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<SaleItem> _items = [];
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
    final existingIndex = _items.indexWhere((i) => i.productId == item.productId);
    if (existingIndex != -1) {
      _items[existingIndex].qty += item.qty;
      _items[existingIndex].subtotal = _items[existingIndex].qty * _items[existingIndex].sellingPrice;
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

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
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
    final cartItem = _items.where((item) => item.productId == productId);
    return cartItem.isEmpty ? 0 : cartItem.first.qty;
  }

  // Get available stock for a product (stock - cart quantity)
  double getAvailableStock(Product product) {
    return product.stock - getCartQuantity(product.id);
  }
}
