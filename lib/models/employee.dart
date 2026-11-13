import '../data/database.dart';


class Employee {
  /// Writes this record to the database.
  Future<void> save() => Db.employees.put(id, this);

  /// Removes this record from the database.
  Future<void> delete() => Db.employees.delete(id);

  String id;
  String name;
  String type; // 'daily' or 'monthly'
  double wage;
  int attendance; // For daily wages
  bool salaryPaid; // For monthly salary

  Employee({
    required this.id,
    required this.name,
    required this.type,
    required this.wage,
    this.attendance = 0,
    this.salaryPaid = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'wage': wage,
        'attendance': attendance,
        'salaryPaid': salaryPaid,
      };

  static Employee fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      wage: (json['wage'] as num).toDouble(),
      attendance: json['attendance'] as int,
      salaryPaid: json['salaryPaid'] as bool,
    );
  }
}
