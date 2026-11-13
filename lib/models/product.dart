import '../data/database.dart';

enum UnitType {
  pcs,
  kg,
  sqft,
}

class Product {
  /// Writes this record to the database.
  Future<void> save() => Db.products.put(id, this);

  /// Removes this record from the database.
  Future<void> delete() => Db.products.delete(id);

  late String id;
  late String name;
  double sellingPrice = 0; // customer price
  double costPrice = 0; // purchase price
  double stock = 0;
  UnitType unit = UnitType.pcs;
  String category = 'General';
  String subCategory = '';
  bool active = true;
  String? barcode;
  String hsnCode = '';
  double? gstRate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sellingPrice': sellingPrice,
        'costPrice': costPrice,
        'stock': stock,
        'unit': unit.name,
        'category': category,
        'subCategory': subCategory,
        'active': active,
        'barcode': barcode,
        'hsnCode': hsnCode,
        'gstRate': gstRate,
      };

  static Product fromJson(Map<String, dynamic> json) {
    return Product()
      ..id = json['id'] as String
      ..name = json['name'] as String
      ..sellingPrice = (json['sellingPrice'] as num).toDouble()
      ..costPrice = (json['costPrice'] as num).toDouble()
      ..stock = (json['stock'] as num).toDouble()
      ..unit = UnitType.values.firstWhere(
        (e) => e.name == json['unit'],
        orElse: () => UnitType.pcs,
      )
      ..category = json['category'] as String
      ..subCategory = json['subCategory'] as String
      ..active = json['active'] as bool? ?? true
      ..barcode = json['barcode'] as String?
      ..hsnCode = json['hsnCode'] as String? ?? ''
      ..gstRate = (json['gstRate'] as num?)?.toDouble();
  }
}
