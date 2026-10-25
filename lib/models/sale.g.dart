// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleItemAdapter extends TypeAdapter<SaleItem> {
  @override
  final int typeId = 6;

  @override
  SaleItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleItem()
      ..productId = fields[0] as String
      ..qty = fields[1] as double
      ..sellingPrice = fields[2] as double
      ..costPrice = fields[3] as double
      ..subtotal = fields[4] as double
      ..unitLabel = fields[5] as String;
  }

  @override
  void write(BinaryWriter writer, SaleItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.qty)
      ..writeByte(2)
      ..write(obj.sellingPrice)
      ..writeByte(3)
      ..write(obj.costPrice)
      ..writeByte(4)
      ..write(obj.subtotal)
      ..writeByte(5)
      ..write(obj.unitLabel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 7;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sale()
      ..id = fields[0] as String
      ..date = fields[1] as DateTime
      ..items = (fields[2] as List).cast<SaleItem>()
      ..totalAmount = fields[3] as double
      ..totalCost = fields[4] as double
      ..profit = fields[5] as double
      ..payment = fields[6] as PaymentMethod
      ..customerName = fields[7] as String
      ..customerPhone = fields[8] as String
      ..userId = fields[9] as String
      ..discount = fields[10] as double;
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.totalAmount)
      ..writeByte(4)
      ..write(obj.totalCost)
      ..writeByte(5)
      ..write(obj.profit)
      ..writeByte(6)
      ..write(obj.payment)
      ..writeByte(7)
      ..write(obj.customerName)
      ..writeByte(8)
      ..write(obj.customerPhone)
      ..writeByte(9)
      ..write(obj.userId)
      ..writeByte(10)
      ..write(obj.discount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaymentMethodAdapter extends TypeAdapter<PaymentMethod> {
  @override
  final int typeId = 5;

  @override
  PaymentMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PaymentMethod.cash;
      case 1:
        return PaymentMethod.card;
      case 2:
        return PaymentMethod.upi;
      default:
        return PaymentMethod.cash;
    }
  }

  @override
  void write(BinaryWriter writer, PaymentMethod obj) {
    switch (obj) {
      case PaymentMethod.cash:
        writer.writeByte(0);
        break;
      case PaymentMethod.card:
        writer.writeByte(1);
        break;
      case PaymentMethod.upi:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
