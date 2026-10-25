import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:floralbill/models/sale.dart';
import 'package:floralbill/models/product.dart';
import 'package:floralbill/services/boxes.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'payment_qr_service.dart';

import 'package:permission_handler/permission_handler.dart';

class ThermalPrinterService {
  static String _formatRupees(double value) {
    return 'Rs.${value.truncate()}';
  }

  static List<int> _totalLineBytes(String totalAmount) {
    const lineWidth = 48;
    const totalLabel = 'TOTAL:';
    final enlargedAmountFits =
        totalLabel.length + (totalAmount.length * 2) <= lineWidth;
    final amountWidth =
        enlargedAmountFits ? totalAmount.length * 2 : totalAmount.length;
    final padding =
        (lineWidth - totalLabel.length - amountWidth).clamp(0, lineWidth);

    final bytes = <int>[
      0x1B, 0x45, 0x01, // Bold on.
      0x1D, 0x21, 0x00, // Normal size for TOTAL:.
      ...('$totalLabel${' ' * padding}').codeUnits,
    ];

    if (enlargedAmountFits) {
      bytes.addAll([0x1D, 0x21, 0x11]); // Double width and height.
    }
    bytes.addAll(totalAmount.codeUnits);
    bytes.addAll([
      0x0A,
      0x1D, 0x21, 0x00, // Restore normal size.
      0x1B, 0x45, 0x00, // Bold off.
    ]);
    return bytes;
  }

  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      await _requestPermissions();
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices;
    } catch (e) {
      print('Error getting bonded devices: $e');
      return [];
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    print("Permission statuses: $statuses");
  }

  Future<void> connect(BluetoothInfo device) async {
    try {
      await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
    } catch (e) {
      print('Connection error: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (e) {
      print('Error disconnecting printer: $e');
    }
  }

  Future<bool> get isConnected async {
    try {
      final result = await PrintBluetoothThermal.connectionStatus;
      return result;
    } catch (e) {
      print('Error checking printer connection: $e');
      return false;
    }
  }

  Future<bool> printInvoice(Sale sale) async {
    try {
      // Try to print to any available paired device
      return await _attemptPrintToPairedDevice(sale);
    } catch (e) {
      print('Printing error: $e');
      return false;
    }
  }

  // Settings box key
  static const String _settingsBoxName = 'settings';
  static const String _printerMacKey = 'printer_mac_address';

  Future<void> savePrinter(String macAddress) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_printerMacKey, macAddress);
    print('Saved printer MAC: $macAddress');
  }

  Future<String?> getSavedPrinter() async {
    final box = await Hive.openBox(_settingsBoxName);
    return box.get(_printerMacKey);
  }

  Future<bool> _attemptPrintToPairedDevice(Sale sale) async {
    try {
      // Get paired devices
      final devices = await getBondedDevices();

      if (devices.isEmpty) {
        print('No paired thermal printers found');
        return false;
      }

      print('Found ${devices.length} paired devices:');
      for (var d in devices) {
        print('- ${d.name} (${d.macAdress})');
      }

      // Check for saved printer
      final savedMac = await getSavedPrinter();
      print('Saved printer MAC: $savedMac');

      bool connected = await isConnected;

      // 1. Try saved printer first
      if (!connected && savedMac != null) {
        try {
          final savedDevice = devices.firstWhere((d) => d.macAdress == savedMac,
              orElse: () => devices
                  .first // Fallback (shouldn't happen if logic is correct, but safe)
              );

          if (savedDevice.macAdress == savedMac) {
            print(
                'Attempting to connect to SAVED printer: ${savedDevice.name}...');
            await connect(savedDevice);
            connected = await isConnected;
            print('Connection result for saved printer: $connected');
          }
        } catch (e) {
          print('Failed to connect to saved printer: $e');
        }
      }

      // 2. If not connected, try all devices one by one
      if (!connected && devices.isNotEmpty) {
        print('Not connected to saved printer, trying all devices...');
        for (var device in devices) {
          try {
            print(
                'Attempting to connect to: ${device.name} (${device.macAdress})...');
            await connect(device);
            connected = await isConnected;

            if (connected) {
              print('Successfully connected to ${device.name}');
              // Optionally auto-save this if it works? For now, let user choose explicitly.
              break;
            } else {
              print('Failed to connect to ${device.name}, trying next...');
            }
          } catch (e) {
            print('Error connecting to ${device.name}: $e');
          }
        }
      }

      if (!connected) {
        print('Could not establish connection to thermal printer');
        return false;
      }

      // Print using ESC/POS commands with logo
      print('Generating ticket for 80mm printer...');
      List<int> ticket = await _generateTicketWithLogo(sale);
      print('Sending ${ticket.length} bytes to printer...');
      final result = await PrintBluetoothThermal.writeBytes(ticket);
      print("Print result (data sent): $result");
      return result;
    } catch (e) {
      print('Error during printing: $e');
      rethrow;
    }
  }

  Future<List<int>> _generateTicketWithLogo(Sale sale) async {
    List<int> bytes = [];

    // Using default profile for 80mm paper
    // ATPOS HL300 is compatible with standard ESC/POS commands
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    bytes += generator.reset();

    // Currency symbol - fallback to Rs. if printer doesn't support ₹
    const String currencySymbol =
        'Rs.'; // Changed to Rs. to avoid encoding errors

    // Replace logo with bold, bigger "Royal Garden" heading
    bytes += generator.text(
      'Royal Garden',
      styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2),
      linesAfter: 1,
    );

    // Business contact info - centered
    bytes += generator.text('FourLane Byepass,Mangattukavala',
        styles: PosStyles(align: PosAlign.center));
    bytes += generator.text('Thodupuzha, 685585',
        styles: PosStyles(align: PosAlign.center));
    bytes += generator.text('ph: 8078101212',
        styles: PosStyles(align: PosAlign.center));
    bytes += generator.text('INVOICE',
        styles: PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('');

    // Invoice details
    bytes += generator.text('ID: ${sale.id}');
    bytes += generator.text(
        'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.date.toLocal())}');

    if (sale.customerName.isNotEmpty) {
      bytes += generator.text('Customer: ${sale.customerName}');
    }
    if (sale.customerPhone.isNotEmpty) {
      bytes += generator.text('Phone: ${sale.customerPhone}');
    }
    bytes += generator.text('Payment: ${sale.payment.name.toUpperCase()}');
    bytes += generator.text('');

    // Items header - adjusted for 80mm paper (48 characters width)
    bytes += generator.text('================================================');
    bytes += generator.text(
      'ITEM'.padRight(20) +
          'PRICE'.padLeft(9) +
          'QTY'.padLeft(8) +
          'AMT'.padLeft(11),
    );
    bytes += generator.text('================================================');

    // Print items with better formatting for 80mm paper
    for (var itemIndex = 0; itemIndex < sale.items.length; itemIndex++) {
      final item = sale.items[itemIndex];
      final product = Hive.box<Product>(Boxes.products).get(item.productId);
      final productName = product?.name ?? 'Unknown Product';
      final numberedName = '${itemIndex + 1}. $productName';
      final qty =
          item.qty.toStringAsFixed(product?.unit == UnitType.kg ? 1 : 0);
      final unitLabel = item.unitLabel.isNotEmpty
          ? item.unitLabel
          : (product?.unit.name ?? '');

      String priceStr = _formatRupees(item.sellingPrice);
      String qtyStr = '$qty ${unitLabel.isNotEmpty ? unitLabel : ''}'.trim();
      String amtStr = _formatRupees(item.subtotal);

      // For 80mm paper, we have about 48 characters width
      // Product name: 20 chars (wrapped at 15), Price: 9 chars, Qty: 8 chars, Amount: 11 chars
      if (numberedName.length <= 20) {
        // Short name - fits on one line
        String itemLine = numberedName.padRight(20) +
            priceStr.padLeft(9) +
            qtyStr.padLeft(8) +
            amtStr.padLeft(11);
        bytes += generator.text(itemLine);
      } else {
        // Long name - split intelligently at word boundaries
        List<String> words = productName.split(' ');
        String firstLine = '${itemIndex + 1}. ';
        String secondLine = '';

        // Build first line with as many words as possible (20-character item column)
        for (String word in words) {
          String candidate = firstLine == '${itemIndex + 1}. '
              ? '$firstLine$word'
              : '$firstLine $word';
          if (candidate.length <= 20) {
            firstLine = candidate;
          } else {
            // Add remaining words to second line
            secondLine += (secondLine.isEmpty ? '' : ' ') + word;
          }
        }

        // If the first word is longer than the available item column, split it.
        if (firstLine == '${itemIndex + 1}. ') {
          firstLine = '${itemIndex + 1}. ${productName.substring(0, 17)}';
          secondLine = productName.substring(17);
        }

        // Print first line
        bytes += generator.text(firstLine);

        // Print second line with price, qty and amount
        // If second line is still too long, truncate to 20 to fit column
        if (secondLine.length > 20) {
          secondLine = secondLine.substring(0, 20);
        }

        String qtyAmtLine = secondLine.padRight(20) +
            priceStr.padLeft(9) +
            qtyStr.padLeft(8) +
            amtStr.padLeft(11);
        bytes += generator.text(qtyAmtLine);
      }

      // Add separator line between items (but not after the last one)
      if (itemIndex < sale.items.length - 1) {
        bytes +=
            generator.text('------------------------------------------------');
      }
    }

    // Totals - better alignment for 80mm paper
    bytes += generator.text('================================================');

    final subtotalValue = sale.items.fold(0.0, (a, b) => a + b.subtotal);
    String subtotalAmount = _formatRupees(subtotalValue);
    // 48 chars total. "Subtotal:" is 9 chars. 48 - 9 = 39.
    String subtotalLine = 'Subtotal:' + subtotalAmount.padLeft(39);
    bytes += generator.text(subtotalLine);

    if (sale.discount > 0) {
      String discountAmount = '-${_formatRupees(sale.discount)}';
      String discountLine = 'Discount:' + discountAmount.padLeft(39);
      bytes += generator.text(discountLine);
    }

    if (sale.gstEnabled) {
      bytes += generator.text('Taxable value:'.padRight(24) + _formatRupees(sale.taxableAmount).padLeft(24));
      if (sale.interstateSale) {
        bytes += generator.text('IGST:'.padRight(24) + _formatRupees(sale.igstAmount).padLeft(24));
      } else {
        bytes += generator.text('CGST:'.padRight(24) + _formatRupees(sale.cgstAmount).padLeft(24));
        bytes += generator.text('SGST:'.padRight(24) + _formatRupees(sale.sgstAmount).padLeft(24));
      }
    }

    bytes += generator.text('================================================');

    final totalAmount = _formatRupees(sale.totalAmount);
    bytes += _totalLineBytes(totalAmount);
    bytes += generator.text('');

    // Generate a bill-specific UPI QR when a UPI ID is configured;
    // otherwise use the optional static QR fallback.
    try {
      final qrBytes = await PaymentQrService.generateForSale(sale) ??
          await PaymentQrService.loadStaticQrFallback();
      if (qrBytes != null) {
        final img.Image? qrImage = img.decodeImage(qrBytes);
        if (qrImage != null) {
          bytes += generator.text(
            'SCAN & PAY',
            styles: PosStyles(align: PosAlign.center, bold: true),
          );
          bytes += generator.image(qrImage);
        }
      }
    } catch (e) {
      print('Error generating/printing payment QR: $e');
    }

    // Footer
    bytes +=
        generator.text('THANK YOU!', styles: PosStyles(align: PosAlign.center));
    bytes += generator.text('');
    // bytes += generator.text('      Royal Garden',
    //     styles: PosStyles(align: PosAlign.center));

    // Feed the completed receipt before cutting so the final lines are printed.
    bytes += generator.feed(3);
    bytes += <int>[0x1D, 0x56, 0x00]; // GS V 0

    return bytes;
  }
}
