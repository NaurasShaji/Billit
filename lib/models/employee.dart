import 'package:hive/hive.dart';

part 'employee.g.dart';

@HiveType(typeId: 9)
class Employee extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String type; // 'daily' or 'monthly'
  @HiveField(3)
  double wage;
  @HiveField(4)
  int attendance; // For daily wages
  @HiveField(5)
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
