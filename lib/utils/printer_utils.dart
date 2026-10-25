import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

// Re-export the BluetoothInfo class to avoid importing print_bluetooth_thermal everywhere
class BluetoothDevice {
  final String? name;
  final String? address;
  final BluetoothInfo _device;

  BluetoothDevice(this._device)
      : name = _device.name,
        address = _device.macAdress;

  BluetoothInfo get device => _device;
}

// Printer connection status
enum PrinterStatus {
  connected,
  disconnected,
  error
}

// Printer type for invoice generation
enum PrinterType {
  thermal,
  pdf
}

class PrinterUtils {
  static const int PAPER_WIDTH_58 = 384; // 48 chars per line
  static const int MAX_CHARS_PER_LINE = 32; // For 58mm printer

  // Format text to fit printer width
  static String formatText(String text, {int maxWidth = MAX_CHARS_PER_LINE}) {
    if (text.length <= maxWidth) return text;

    final lines = <String>[];
    for (var i = 0; i < text.length; i += maxWidth) {
      final end = i + maxWidth > text.length ? text.length : i + maxWidth;
      lines.add(text.substring(i, end));
    }
    return lines.join('\n');
  }

  // Center text within printer width
  static String centerText(String text, {int width = MAX_CHARS_PER_LINE}) {
    if (text.length >= width) return text;
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }

  // Create separator line
  static String separator({String char = '-', int width = MAX_CHARS_PER_LINE}) {
    return char * width;
  }
}
