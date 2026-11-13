import '../data/database.dart';

enum UserType {
  admin,
  worker,
}

class User {
  /// Writes this record to the database.
  Future<void> save() => Db.users.put(id, this);

  /// Removes this record from the database.
  Future<void> delete() => Db.users.delete(id);

  late String id;
  late String username;
  late String password; // hashed simple
  late UserType userType;
  String securityAnswer = 'Buddy'; // Default security answer
  String securityQuestion = 'What is the name of your favourite pet?';

  static String hash(String input) {
    return input.codeUnits
        .fold<int>(0, (a, b) => (a * 31 + b) & 0xFFFFFFFF)
        .toRadixString(16);
  }
}
