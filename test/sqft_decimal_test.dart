import 'package:flutter_test/flutter_test.dart';
import '../lib/models/product.dart';
import '../lib/models/sale.dart';
import '../lib/services/cart_service.dart';

void main() {
  group('SQFT Decimal Quantity Tests', () {
    late CartService cartService;
    late Product sqftProduct;

    setUp(() {
      cartService = CartService();
      sqftProduct = Product()
        ..id = 'test-sqft-1'
        ..name = 'Test Tiles'
        ..sellingPrice = 50.0
        ..costPrice = 30.0
        ..stock = 100.5
        ..unit = UnitType.sqft
        ..category = 'Flooring'
        ..active = true;
    });

    tearDown(() {
      cartService.clearCart();
    });

    test('Should allow decimal quantities for sqft products', () {
      // Create a sale item with decimal quantity
      final item = SaleItem()
        ..productId = sqftProduct.id
        ..qty = 2.5 // 2.5 sqft
        ..sellingPrice = sqftProduct.sellingPrice
        ..costPrice = sqftProduct.costPrice
        ..subtotal = 2.5 * sqftProduct.sellingPrice
        ..unitLabel = sqftProduct.unit.name;

      cartService.addItem(item);

      expect(cartService.items.length, 1);
      expect(cartService.items.first.qty, 2.5);
      expect(cartService.items.first.subtotal, 125.0); // 2.5 * 50.0
    });

    test('Should calculate available stock correctly with decimal quantities', () {
      final item = SaleItem()
        ..productId = sqftProduct.id
        ..qty = 10.5
        ..sellingPrice = sqftProduct.sellingPrice
        ..costPrice = sqftProduct.costPrice
        ..subtotal = 10.5 * sqftProduct.sellingPrice
        ..unitLabel = sqftProduct.unit.name;

      cartService.addItem(item);

      final availableStock = cartService.getAvailableStock(sqftProduct);
      expect(availableStock, 90.0); // 100.5 - 10.5
    });

    test('Should prevent adding more than available stock', () {
      sqftProduct.stock = 5.0; // Limited stock

      final canAdd = cartService.canAddToCart(sqftProduct, 5.5);
      expect(canAdd, false);

      final canAddValid = cartService.canAddToCart(sqftProduct, 4.5);
      expect(canAddValid, true);
    });

    test('Should handle multiple decimal additions correctly', () {
      final item1 = SaleItem()
        ..productId = sqftProduct.id
        ..qty = 1.5
        ..sellingPrice = sqftProduct.sellingPrice
        ..costPrice = sqftProduct.costPrice
        ..subtotal = 1.5 * sqftProduct.sellingPrice
        ..unitLabel = sqftProduct.unit.name;

      cartService.addItem(item1);

      final item2 = SaleItem()
        ..productId = sqftProduct.id
        ..qty = 2.5
        ..sellingPrice = sqftProduct.sellingPrice
        ..costPrice = sqftProduct.costPrice
        ..subtotal = 2.5 * sqftProduct.sellingPrice
        ..unitLabel = sqftProduct.unit.name;

      cartService.addItem(item2);

      // Should combine quantities
      expect(cartService.items.length, 1);
      expect(cartService.items.first.qty, 4.0); // 1.5 + 2.5
      expect(cartService.items.first.subtotal, 200.0); // 4.0 * 50.0
    });

    test('Should calculate totals correctly with decimal quantities', () {
      final item = SaleItem()
        ..productId = sqftProduct.id
        ..qty = 3.5
        ..sellingPrice = 45.0 // Different selling price
        ..costPrice = sqftProduct.costPrice
        ..subtotal = 3.5 * 45.0
        ..unitLabel = sqftProduct.unit.name;

      cartService.addItem(item);

      expect(cartService.total, 157.5); // 3.5 * 45.0
      expect(cartService.cost, 105.0); // 3.5 * 30.0
      expect(cartService.profit, 52.5); // 157.5 - 105.0
    });
  });
}
