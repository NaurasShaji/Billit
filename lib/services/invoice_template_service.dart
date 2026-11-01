import 'package:hive_flutter/hive_flutter.dart';

class InvoiceTemplateService {
  static const storageKey = 'invoice_templates_v1';
  static const selectedPaperKey = 'invoice_default_paper_size';
  static const paperSizes = ['58mm', '80mm', 'A5', 'A4'];
  static const columns = <Map<String, String>>[
    {'id':'serial','label':'Sl. No.'}, {'id':'product','label':'Product'},
    {'id':'hsn','label':'HSN/SAC'}, {'id':'quantity','label':'Qty'},
    {'id':'unit','label':'Unit'}, {'id':'rate','label':'Rate'},
    {'id':'discount','label':'Discount'}, {'id':'gst_rate','label':'GST %'},
    {'id':'tax','label':'Tax'}, {'id':'amount','label':'Amount'},
  ];

  static Map<String, dynamic> defaults(String size) {
    final compact = size == '58mm' || size == '80mm';
    return {
      'name':'Default $size', 'paperSize':size, 'headerTitle':'TAX INVOICE',
      'footerText':'Thank you for your business.', 'termsText':'',
      'showLogo':!compact, 'showBusinessName':true, 'showAddress':true,
      'showPhone':true, 'showEmail':!compact, 'showBusinessGstin':true,
      'showCustomerPhone':true, 'showCustomerGstin':true,
      'showPaymentMethod':true, 'showQr':true, 'showAmountInWords':!compact,
      'showTableBorders':!compact, 'headerAlignment':'center',
      'footerAlignment':'center', 'fontSize':size == '58mm' ? 7.0 : compact ? 8.0 : 9.0,
      'marginMm':compact ? 2.0 : 10.0, 'accent':'blue',
      'columns':size == '58mm' ? ['product','quantity','amount']
        : size == '80mm' ? ['product','quantity','rate','amount']
        : size == 'A5' ? ['serial','product','quantity','rate','gst_rate','amount']
        : ['serial','product','hsn','quantity','rate','gst_rate','tax','amount'],
      'columnLabels':<String,String>{},
    };
  }

  static Map<String, dynamic> loadAll() {
    final raw = Hive.box<dynamic>('app_settings').get(storageKey);
    final saved = raw is Map ? Map<String,dynamic>.from(raw) : <String,dynamic>{};
    return {for (final size in paperSizes) size:
      saved[size] is Map ? {...defaults(size), ...Map<String,dynamic>.from(saved[size]), 'paperSize':size} : defaults(size)};
  }

  static Map<String,dynamic> load(String size) => Map<String,dynamic>.from(loadAll()[size] as Map);
  static String get selected => paperSizes.contains(Hive.box<dynamic>('app_settings').get(selectedPaperKey))
      ? Hive.box<dynamic>('app_settings').get(selectedPaperKey).toString() : '80mm';

  static Future<void> save(String size, Map<String,dynamic> template) async {
    final all = loadAll();
    all[size] = {...defaults(size), ...template, 'paperSize':size};
    await Hive.box<dynamic>('app_settings').put(storageKey, all);
  }

  static Future<void> select(String size) async {
    if (paperSizes.contains(size)) await Hive.box<dynamic>('app_settings').put(selectedPaperKey, size);
  }

  static Future<void> restore(String size) async {
    final all = loadAll();
    all[size] = defaults(size);
    await Hive.box<dynamic>('app_settings').put(storageKey, all);
  }

  static List<String> validate(Map<String,dynamic> value) {
    final size = value['paperSize'].toString();
    final compact = size == '58mm' || size == '80mm';
    final selected = (value['columns'] as List?)?.cast<String>() ?? <String>[];
    const widths = {'serial':4,'product':22,'hsn':10,'quantity':8,'unit':6,'rate':12,'discount':10,'gst_rate':8,'tax':12,'amount':13};
    final used = selected.fold<int>(0,(sum,id)=>sum+(widths[id]??8));
    final limit = size == '58mm' ? 32 : size == '80mm' ? 48 : 999;
    final warnings = <String>[];
    if (selected.isEmpty) warnings.add('Add at least one table column.');
    if (selected.toSet().length != selected.length) warnings.add('Remove duplicate table columns.');
    if (compact && used > limit) warnings.add('Selected columns may exceed printable width. Hide optional columns or choose a wider paper size.');
    final font = (value['fontSize'] as num).toDouble();
    if (font < (size == '58mm' ? 6 : 7)) warnings.add('Font size is below the recommended readable minimum.');
    if (font > (compact ? 12 : 18)) warnings.add('Font size may cause wrapping or page overflow.');
    final margin = (value['marginMm'] as num).toDouble();
    if (compact && margin > 5) warnings.add('Large margins reduce usable thermal paper width.');
    if (compact && value['footerText'].toString().length > 80) warnings.add('Long footer may wrap across several receipt lines.');
    return warnings;
  }
}
