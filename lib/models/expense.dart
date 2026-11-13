import '../data/database.dart';


class Expense {
  /// Writes this record to the database.
  Future<void> save() => Db.expenses.put(id, this);

  /// Removes this record from the database.
  Future<void> delete() => Db.expenses.delete(id);

  String id;
  DateTime date;
  String category;
  double amount;
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
