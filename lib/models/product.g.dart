// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 4;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..sellingPrice = fields[2] as double
      ..costPrice = fields[3] as double
      ..stock = fields[4] as double
      ..unit = fields[5] as UnitType
      ..category = fields[6] as String
      ..subCategory = fields[7] as String
      ..active = fields[8] as bool;
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sellingPrice)
      ..writeByte(3)
      ..write(obj.costPrice)
      ..writeByte(4)
      ..write(obj.stock)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.subCategory)
      ..writeByte(8)
      ..write(obj.active);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UnitTypeAdapter extends TypeAdapter<UnitType> {
  @override
  final int typeId = 3;

  @override
  UnitType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UnitType.pcs;
      case 1:
        return UnitType.kg;
      case 2:
        return UnitType.sqft;
      default:
        return UnitType.pcs;
    }
  }

  @override
  void write(BinaryWriter writer, UnitType obj) {
    switch (obj) {
      case UnitType.pcs:
        writer.writeByte(0);
        break;
      case UnitType.kg:
        writer.writeByte(1);
        break;
      case UnitType.sqft:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
