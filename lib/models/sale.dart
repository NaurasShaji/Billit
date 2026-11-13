import '../data/database.dart';

enum PaymentMethod {
  cash,
  card,
  upi,
}

class SaleItem {
  SaleItem(); // Unnamed constructor
  late String productId;
  double qty = 1;
  double sellingPrice = 0;
  double costPrice = 0;
  double subtotal = 0;
  String unitLabel = 'pcs';
  String hsnCode = '';
  double? gstRate;
  double taxableAmount = 0.0;
  double cgstAmount = 0.0;
  double sgstAmount = 0.0;
  double igstAmount = 0.0;

  // Getters for reports
  String get productName =>
      Db.products.get(productId)?.name ?? 'Unknown Product';
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
    hsnCode = other.hsnCode;
    gstRate = other.gstRate;
    taxableAmount = other.taxableAmount;
    cgstAmount = other.cgstAmount;
    sgstAmount = other.sgstAmount;
    igstAmount = other.igstAmount;
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'qty': qty,
        'sellingPrice': sellingPrice,
        'costPrice': costPrice,
        'subtotal': subtotal,
        'unitLabel': unitLabel,
        'hsnCode': hsnCode,
        'gstRate': gstRate,
        'taxableAmount': taxableAmount,
        'cgstAmount': cgstAmount,
        'sgstAmount': sgstAmount,
        'igstAmount': igstAmount,
      };

  static SaleItem fromJson(Map<String, dynamic> json) {
    return SaleItem()
      ..productId = json['productId'] as String
      ..qty = (json['qty'] as num).toDouble()
      ..sellingPrice = (json['sellingPrice'] as num).toDouble()
      ..costPrice = (json['costPrice'] as num).toDouble()
      ..subtotal = (json['subtotal'] as num).toDouble()
      ..unitLabel = json['unitLabel'] as String
      ..hsnCode = json['hsnCode'] as String? ?? ''
      ..gstRate = (json['gstRate'] as num?)?.toDouble()
      ..taxableAmount = (json['taxableAmount'] as num?)?.toDouble() ?? 0.0
      ..cgstAmount = (json['cgstAmount'] as num?)?.toDouble() ?? 0.0
      ..sgstAmount = (json['sgstAmount'] as num?)?.toDouble() ?? 0.0
      ..igstAmount = (json['igstAmount'] as num?)?.toDouble() ?? 0.0;
  }
}

class Sale {
  /// Writes this record to the database.
  Future<void> save() => Db.sales.put(id, this);

  /// Removes this record from the database.
  Future<void> delete() => Db.sales.delete(id);

  late String id;
  late DateTime date;
  late List<SaleItem> items;
  double totalAmount = 0;
  double totalCost = 0;
  double profit = 0;
  PaymentMethod payment = PaymentMethod.cash;
  String customerName = '';
  String customerPhone = '';
  String userId = '';
  double discount = 0.0;
  bool gstEnabled = false;
  double gstRate = 0.0;
  double taxableAmount = 0.0;
  double cgstAmount = 0.0;
  double sgstAmount = 0.0;
  double igstAmount = 0.0;
  String customerGstin = '';
  bool interstateSale = false;
  bool gstInclusive = false;

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
        'gstEnabled': gstEnabled,
        'gstRate': gstRate,
        'taxableAmount': taxableAmount,
        'cgstAmount': cgstAmount,
        'sgstAmount': sgstAmount,
        'igstAmount': igstAmount,
        'customerGstin': customerGstin,
        'interstateSale': interstateSale,
        'gstInclusive': gstInclusive,
      };

  static Sale fromJson(Map<String, dynamic> json) {
    return Sale()
      ..id = json['id'] as String
      ..date = DateTime.parse(json['date'] as String)
      ..items = (json['items'] as List)
          .map((item) => SaleItem.fromJson(item as Map<String, dynamic>))
          .toList()
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
      ..discount = (json['discount'] as num?)?.toDouble() ?? 0.0
      ..gstEnabled = json['gstEnabled'] as bool? ?? false
      ..gstRate = (json['gstRate'] as num?)?.toDouble() ?? 0.0
      ..taxableAmount = (json['taxableAmount'] as num?)?.toDouble() ?? 0.0
      ..cgstAmount = (json['cgstAmount'] as num?)?.toDouble() ?? 0.0
      ..sgstAmount = (json['sgstAmount'] as num?)?.toDouble() ?? 0.0
      ..igstAmount = (json['igstAmount'] as num?)?.toDouble() ?? 0.0
      ..customerGstin = json['customerGstin'] as String? ?? ''
      ..interstateSale = json['interstateSale'] as bool? ?? false
      ..gstInclusive = json['gstInclusive'] as bool? ?? false;
  }
}
