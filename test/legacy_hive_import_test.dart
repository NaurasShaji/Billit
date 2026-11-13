import 'dart:io';
import 'dart:typed_data';
import 'package:billit/data/database.dart';
import 'package:billit/data/legacy_hive_import.dart';
import 'package:billit/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_database.dart';
void main(){
 late Directory hiveDir;
 setUpAll(generateLegacyHiveFixtures);
 setUp(() {hiveDir=Directory.systemTemp.createTempSync('billit_legacy_hive');openInMemoryDatabase();});
 tearDown(() {Db.close();hiveDir.deleteSync(recursive:true);});
 void copyFixtures({Set<String>? only}){for(final file in Directory('test/fixtures/legacy_hive').listSync().whereType<File>()){final name=file.uri.pathSegments.last;if(only!=null&&!only.contains(name))continue;file.copySync('${hiveDir.path}/$name');}}
 test('imports all legacy boxes and preserves typed values',()async{
  copyFixtures();final copied=await importLegacyHiveData(directory:hiveDir.path);
  expect(Db.users.keys,['u-admin','u-worker']);expect(Db.users.get('u-admin')!.password,User.hash('s3cret'));expect(Db.users.get('u-admin')!.userType,UserType.admin);expect(Db.users.get('u-worker')!.securityAnswer,'Buddy');
  expect(Db.products.keys,['p-rose','p-soil','p-turf']);expect(Db.products.get('p-rose')!.name,'Rose bunch');expect(Db.products.get('p-turf')!.unit,UnitType.sqft);expect(Db.products.get('p-soil')!.unit,UnitType.kg);
  expect(Db.sales.keys,['INV-0001','INV-0002']);final sale=Db.sales.get('INV-0001')!;expect(sale.date,DateTime(2025,3,14,10,30,15,250));expect(sale.totalAmount,796.63);expect(sale.payment,PaymentMethod.upi);expect(sale.items,hasLength(2));expect(sale.items[0].gstRate,5.0);expect(Db.sales.get('INV-0002')!.payment,PaymentMethod.card);
  expect(Db.expenses.get('e-1')!.amount,15000.0);expect(Db.employees.get('m-1')!.wage,750.5);expect(Db.employees.get('m-2')!.salaryPaid,isTrue);
  expect(Db.session.get('user_id'),'u-admin');expect(Db.session.get('last_backup_at'),DateTime(2025,3,10,9));expect(Db.settings.get('app_name'),'Asha Flowers');expect(Db.settings.get('gst_rate'),5.0);expect(Db.settings.get('logo_bytes'),[0,1,2,250,255]);expect(Db.deviceSettings.get('printer_mac_address'),'00:11:22:33:44:55');expect(copied,25);expect(Db.meta.get(legacyImportKey)['copied'],25);
 });
 test('import runs only once',()async{copyFixtures();await importLegacyHiveData(directory:hiveDir.path);await Db.products.delete('p-rose');await Db.settings.put('next_invoice_number',42);expect(await importLegacyHiveData(directory:hiveDir.path),0);expect(Db.products.containsKey('p-rose'),isFalse);expect(Db.settings.get('next_invoice_number'),42);});
 test('leaves original Hive files unchanged',()async{copyFixtures();Map<String,List<int>> contents()=>{for(final f in hiveDir.listSync().whereType<File>())if(f.path.endsWith('.hive'))f.path:f.readAsBytesSync()};final before=contents();await importLegacyHiveData(directory:hiveDir.path);expect(contents(),before);});
 test('fresh install imports nothing and creates no Hive files',()async{expect(await importLegacyHiveData(directory:hiveDir.path),0);expect(Db.meta.containsKey(legacyImportKey),isTrue);expect(Db.users.isEmpty,isTrue);expect(hiveDir.listSync(),isEmpty);});
 test('imports only boxes that exist',()async{copyFixtures(only:{'products.hive','app_settings.hive'});await importLegacyHiveData(directory:hiveDir.path);expect(Db.products.length,3);expect(Db.settings.get('app_name'),'Asha Flowers');expect(Db.sales.isEmpty,isTrue);expect(Db.users.isEmpty,isTrue);});
 test('failed box import rolls back and retries',()async{copyFixtures();final good=File('${hiveDir.path}/sales.hive').readAsBytesSync();File('${hiveDir.path}/sales.hive').writeAsBytesSync(_frameWithUnknownType());await expectLater(importLegacyHiveData(directory:hiveDir.path),throwsA(anything));expect(Db.meta.containsKey(legacyImportKey),isFalse);expect(Db.users.isEmpty,isTrue);expect(Db.products.isEmpty,isTrue);expect(Db.settings.isEmpty,isTrue);File('${hiveDir.path}/sales.hive').writeAsBytesSync(good);expect(await importLegacyHiveData(directory:hiveDir.path),25);expect(Db.sales.length,2);});
}
List<int> _frameWithUnknownType(){final body=<int>[1,1,0x6B,99+32,0];final length=4+body.length+4;final frame=BytesBuilder()..add((ByteData(4)..setUint32(0,length,Endian.little)).buffer.asUint8List())..add(body);final crc=_crc32(frame.toBytes());frame.add((ByteData(4)..setUint32(0,crc,Endian.little)).buffer.asUint8List());return frame.toBytes();}
int _crc32(List<int> bytes){var crc=0xFFFFFFFF;for(final byte in bytes){crc^=byte;for(var i=0;i<8;i++){crc=(crc&1)!=0?(crc>>1)^0xEDB88320:crc>>1;}}return crc^0xFFFFFFFF;}
