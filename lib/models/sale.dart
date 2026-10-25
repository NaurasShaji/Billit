import 'package:hive/hive.dart';
import './product.dart'; // Import Product model
import '../services/boxes.dart'; // Import Boxes
part 'sale.g.dart';

@HiveType(typeId: 5)
enum PaymentMethod {
  @HiveField(0) cash,
  @HiveField(1) card,
  @HiveField(2) upi,
}

@HiveType(typeId: 6)
class SaleItem extends HiveObject {
  SaleItem(); // Unnamed constructor
  @HiveField(0) late String productId;
  @HiveField(1) double qty = 1;
  @HiveField(2) double sellingPrice = 0;
  @HiveField(3) double costPrice = 0;
  @HiveField(4) double subtotal = 0;
  @HiveField(5) String unitLabel = 'pcs';

  // Getters for reports
  String get productName => Hive.box<Product>(Boxes.products).get(productId)?.name ?? 'Unknown Product';
  double get quantity => qty;
  double get totalAmount => subtotal;
  double get profit => (sellingPrice - costPrice) * qty;

  SaleItem.fromSaleItem(SaleItem other) {
    productId = other.productId;
    qty = other.qty;
    sellingPrice = other.sellingPrice;
    costPrice = other.costPrice;
    subtotal = other.subtotal;
    unitLabel = other.unitLabel;
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'qty': qty,
    'sellingPrice': sellingPrice,
    'costPrice': costPrice,
    'subtotal': subtotal,
    'unitLabel': unitLabel,
  };

  static SaleItem fromJson(Map<String, dynamic> json) {
    return SaleItem()
      ..productId = json['productId'] as String
      ..qty = (json['qty'] as num).toDouble()
      ..sellingPrice = (json['sellingPrice'] as num).toDouble()
      ..costPrice = (json['costPrice'] as num).toDouble()
      ..subtotal = (json['subtotal'] as num).toDouble()
      ..unitLabel = json['unitLabel'] as String;
  }
}

@HiveType(typeId: 7)
class Sale extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late DateTime date;
  @HiveField(2) late List<SaleItem> items;
  @HiveField(3) double totalAmount = 0;
  @HiveField(4) double totalCost = 0;
  @HiveField(5) double profit = 0;
  @HiveField(6) PaymentMethod payment = PaymentMethod.cash;
  @HiveField(7) String customerName = '';
  @HiveField(8) String customerPhone = '';
  @HiveField(9) String userId = '';
  @HiveField(10) double discount = 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
    'totalAmount': totalAmount,
    'totalCost': totalCost,
    'profit': profit,
    'payment': payment.name,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'userId': userId,
    'discount': discount,
  };

  static Sale fromJson(Map<String, dynamic> json) {
    return Sale()
      ..id = json['id'] as String
      ..date = DateTime.parse(json['date'] as String)
      ..items = (json['items'] as List).map((item) => SaleItem.fromJson(item as Map<String, dynamic>)).toList()
      ..totalAmount = (json['totalAmount'] as num).toDouble()
      ..totalCost = (json['totalCost'] as num).toDouble()
      ..profit = (json['profit'] as num).toDouble()
      ..payment = PaymentMethod.values.firstWhere(
        (e) => e.name == json['payment'],
        orElse: () => PaymentMethod.cash,
      )
      ..customerName = json['customerName'] as String
      ..customerPhone = json['customerPhone'] as String
      ..userId = json['userId'] as String
      ..discount = (json['discount'] as num).toDouble();
  }
}
