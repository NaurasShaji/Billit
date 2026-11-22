import 'package:billit/services/backup_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _payload() => {
      'meta': {'app': 'billit', 'version': '0.2.1'},
      'users': [
        {'id': 'admin', 'username': 'owner'},
      ],
      'products': [
        {'id': 'p1', 'name': 'Item'},
      ],
      'sales': <Map<String, dynamic>>[],
      'expenses': <Map<String, dynamic>>[],
      'employees': <Map<String, dynamic>>[],
      'appSettings': <String, dynamic>{'business_name': 'Shop'},
    };

void main() {
  test('seals a backup with version, record counts and SHA-256 checksum', () {
    final backup = BackupIntegrity.seal(_payload());

    expect(backup['integrity'], isA<Map>());
    expect((backup['integrity'] as Map)['algorithm'], 'SHA-256');
    expect((backup['meta'] as Map)['backupFormatVersion'],
        BackupIntegrity.currentFormatVersion);
    expect(() => BackupIntegrity.validate(backup), returnsNormally);
  });

  test('rejects a backup whose contents were changed after sealing', () {
    final backup = BackupIntegrity.seal(_payload());
    (backup['products'] as List).add({'id': 'p2', 'name': 'Tampered'});

    expect(() => BackupIntegrity.validate(backup), throwsFormatException);
  });

  test('rejects a backup with missing required sections', () {
    final backup = _payload()..remove('sales');

    expect(() => BackupIntegrity.validate(backup), throwsFormatException);
  });

  test('rejects duplicate record IDs', () {
    final backup = _payload();
    (backup['products'] as List).add({'id': 'p1', 'name': 'Duplicate'});

    expect(() => BackupIntegrity.validate(backup), throwsFormatException);
  });

  test('rejects mismatched record counts even with a recomputed checksum',
      () {
    final backup = BackupIntegrity.seal(_payload());
    (backup['meta'] as Map)['recordCounts']['products'] = 99;

    expect(() => BackupIntegrity.validate(backup), throwsFormatException);
  });

  test('accepts structurally valid legacy backups without integrity metadata',
      () {
    expect(() => BackupIntegrity.validate(_payload()), returnsNormally);
  });

  test('rejects backups created by a newer unsupported format', () {
    final backup = _payload();
    (backup['meta'] as Map)['backupFormatVersion'] =
        BackupIntegrity.currentFormatVersion + 1;

    expect(() => BackupIntegrity.validate(backup), throwsFormatException);
  });
}
