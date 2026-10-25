import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 8)
class Expense extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  DateTime date;
  @HiveField(2)
  String category;
  @HiveField(3)
  double amount;
  @HiveField(4)
  String description;

  Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'category': category,
    'amount': amount,
    'description': description,
  };

  static Expense fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
    );
  }
}
